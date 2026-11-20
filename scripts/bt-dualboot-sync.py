#!/usr/bin/env python3
"""Share Bluetooth LE pairings made in Windows with BlueZ on a dual-boot machine.

Devices like Logitech mice switch to a new address and new keys on every
pairing and keep only the latest bond, so pairing in one OS breaks the other.
The fix is to pair once in Windows and give BlueZ the same keys: this reads
Windows' SYSTEM hive (read-only) and writes the newest pairing per device into
/var/lib/bluetooth, replacing stale BlueZ entries of the same device name.

Runs as root at boot before bluetooth.service. A Windows pairing is imported
only if it is newer than what was recorded on the previous run, so a device
later paired in Linux is never overwritten by an old Windows key.

  bt-dualboot-sync.py --install   copy to /usr/local/sbin, enable the boot unit,
                                  record existing Windows pairings as seen
  bt-dualboot-sync.py --dry-run   show what would be imported
  bt-dualboot-sync.py --now       import now (restarts bluetooth.service)
  bt-dualboot-sync.py             boot mode (used by the unit)
"""
import configparser
import datetime
import glob
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile

BLUEZ = "/var/lib/bluetooth"
STATE = "/var/lib/bt-dualboot-sync/state.json"
HIVE_REL = "Windows/System32/config/SYSTEM"
INSTALL_BIN = "/usr/local/sbin/bt-dualboot-sync"
UNIT_PATH = "/etc/systemd/system/bt-dualboot-sync.service"
UNIT = f"""[Unit]
Description=Import Windows Bluetooth LE pairings into BlueZ
Before=bluetooth.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart={INSTALL_BIN}

[Install]
WantedBy=bluetooth.service
"""


class Hive:
    """Minimal read-only Windows registry (regf) reader: keys, values, timestamps."""

    def __init__(self, data):
        if data[:4] != b"regf":
            raise ValueError("not a registry hive")
        self.d = data
        self.root = struct.unpack_from("<I", data, 0x24)[0]

    def _cell(self, off):
        return 0x1000 + off + 4

    def _name(self, p, n, compressed):
        raw = self.d[p:p + n]
        return raw.decode("latin-1") if compressed else raw.decode("utf-16-le")

    def key_name(self, k):
        p = self._cell(k)
        flags, = struct.unpack_from("<H", self.d, p + 2)
        n, = struct.unpack_from("<H", self.d, p + 0x48)
        return self._name(p + 0x4C, n, flags & 0x20)

    def timestamp(self, k):
        ft, = struct.unpack_from("<Q", self.d, self._cell(k) + 4)
        return datetime.datetime(1601, 1, 1) + datetime.timedelta(microseconds=ft // 10)

    def subkeys(self, k):
        p = self._cell(k)
        count, lst = struct.unpack_from("<I", self.d, p + 0x14)[0], struct.unpack_from("<I", self.d, p + 0x1C)[0]
        return list(self._list(lst)) if count else []

    def _list(self, off):
        p = self._cell(off)
        sig, n = self.d[p:p + 2], struct.unpack_from("<H", self.d, p + 2)[0]
        if sig in (b"lf", b"lh"):
            for i in range(n):
                yield struct.unpack_from("<I", self.d, p + 4 + i * 8)[0]
        elif sig == b"li":
            for i in range(n):
                yield struct.unpack_from("<I", self.d, p + 4 + i * 4)[0]
        elif sig == b"ri":
            for i in range(n):
                yield from self._list(struct.unpack_from("<I", self.d, p + 4 + i * 4)[0])

    def child(self, k, name):
        for s in self.subkeys(k):
            if self.key_name(s).lower() == name.lower():
                return s
        return None

    def open(self, path):
        k = self.root
        for part in path.split("\\"):
            k = self.child(k, part)
            if k is None:
                return None
        return k

    def values(self, k):
        p = self._cell(k)
        n, lst = struct.unpack_from("<II", self.d, p + 0x24)
        out = {}
        if not n:
            return out
        lp = self._cell(lst)
        for i in range(n):
            vp = self._cell(struct.unpack_from("<I", self.d, lp + i * 4)[0])
            nlen, size, doff, vtype, flags = struct.unpack_from("<HIIIH", self.d, vp + 2)
            name = self._name(vp + 0x14, nlen, flags & 1)
            if size & 0x80000000:
                raw = struct.pack("<I", doff)[:size & 0x7FFFFFFF]
            else:
                raw = self.d[self._cell(doff):self._cell(doff) + size]
            if vtype == 4:
                out[name] = struct.unpack("<I", raw)[0]
            elif vtype == 11:
                out[name] = struct.unpack("<Q", raw)[0]
            else:
                out[name] = raw
        return out


def colon_mac(regname):
    return ":".join(regname[i:i + 2] for i in range(0, 12, 2)).upper()


def windows_pairings(hive):
    """{adapter_mac: {device_name: newest pairing}} for LE devices."""
    sel = hive.values(hive.open("Select"))["Current"]
    params = f"ControlSet{sel:03d}\\Services\\BTHPORT\\Parameters"
    keys, devs = hive.open(params + "\\Keys"), hive.open(params + "\\Devices")
    names = {}
    for d in hive.subkeys(devs) if devs else []:
        raw = hive.values(d).get("Name", b"")
        names[hive.key_name(d).lower()] = raw.split(b"\0")[0].decode("utf-8", "replace") if raw else ""
    out = {}
    for ad in hive.subkeys(keys) if keys else []:
        newest = {}
        classic = {n.lower() for n in hive.values(ad)}
        for d in hive.subkeys(ad):
            v = hive.values(d)
            reg = hive.key_name(d).lower()
            # Dual-mode devices also hold a classic link key; LE-only import would break them.
            if "LTK" not in v or reg in classic:
                continue
            p = {
                "address": colon_mac(reg),
                "name": names.get(reg) or colon_mac(reg),
                "time": hive.timestamp(d).isoformat(),
                "ltk": v["LTK"].hex().upper(),
                "enc_size": v.get("KeyLength", 16),
                "ediv": v.get("EDIV", 0),
                "rand": v.get("ERand", 0),
                "irk": v["IRK"][::-1].hex().upper() if "IRK" in v else None,
                "csrk": v["CSRK"].hex().upper() if "CSRK" in v else None,
                "addr_type": "static" if v.get("AddressType", 0) else "public",
            }
            if p["name"] not in newest or p["time"] > newest[p["name"]]["time"]:
                newest[p["name"]] = p
        out[colon_mac(hive.key_name(ad).lower())] = newest
    return out


def find_hive():
    """Copy of the Windows SYSTEM hive, mounting NTFS partitions read-only as needed."""
    lsblk = subprocess.run(["lsblk", "-rno", "PATH,FSTYPE,MOUNTPOINT"], capture_output=True, text=True).stdout
    for line in lsblk.splitlines():
        parts = line.split(" ", 2)
        if len(parts) < 2 or parts[1] != "ntfs":
            continue
        mnt = parts[2].replace("\\x20", " ") if len(parts) > 2 and parts[2] else None
        tmp = None
        if not mnt:
            tmp = tempfile.mkdtemp(prefix="bt-dualboot-")
            if subprocess.run(["mount", "-o", "ro", parts[0], tmp], capture_output=True).returncode:
                os.rmdir(tmp)
                continue
            mnt = tmp
        try:
            path = os.path.join(mnt, HIVE_REL)
            if os.path.isfile(path):
                with open(path, "rb") as f:
                    return parts[0], f.read()
        finally:
            if tmp:
                subprocess.run(["umount", tmp])
                os.rmdir(tmp)
    return None, None


def read_info(path):
    c = configparser.ConfigParser(interpolation=None, strict=False)
    c.optionxform = str
    c.read(path)
    return c


def write_pairing(adapter, p, dry):
    """Write p into BlueZ, using the newest same-name entry as a template, and drop stale ones."""
    adir = os.path.join(BLUEZ, adapter)
    same = []
    for info in glob.glob(os.path.join(adir, "??:??:??:??:??:??", "info")):
        if read_info(info).get("General", "Name", fallback=None) == p["name"]:
            same.append(os.path.dirname(info))
    # Only devices already paired in Linux once: never add unknown phones etc.,
    # and never touch dual-mode devices whose BlueZ entry carries a classic key.
    if not same or any(read_info(os.path.join(d, "info")).has_section("LinkKey") for d in same):
        return False
    target = os.path.join(adir, p["address"])
    template = target if target in same else max(same, key=os.path.getmtime, default=None)
    stale = [d for d in same if d != target]

    print(f"  {p['name']}: Windows pairing {p['address']} ({p['time']})"
          + (f", replacing {', '.join(os.path.basename(d) for d in stale)}" if stale else ""))
    if dry:
        return True

    c = read_info(os.path.join(template, "info")) if template else configparser.ConfigParser(interpolation=None)
    c.optionxform = str
    for s in ("LongTermKey", "PeripheralLongTermKey", "SlaveLongTermKey", "IdentityResolvingKey",
              "LocalSignatureKey", "RemoteSignatureKey", "LinkKey"):
        c.remove_section(s)
    if not c.has_section("General"):
        c.add_section("General")
    g = c["General"]
    g["Name"] = p["name"]
    g["AddressType"] = p["addr_type"]
    g.setdefault("SupportedTechnologies", "LE;")
    g["Trusted"] = "true"
    g.setdefault("Blocked", "false")
    c["LongTermKey"] = {"Key": p["ltk"], "Authenticated": "0", "EncSize": str(p["enc_size"]),
                        "EDiv": str(p["ediv"]), "Rand": str(p["rand"])}
    if p["irk"]:
        c["IdentityResolvingKey"] = {"Key": p["irk"]}
    if p["csrk"]:
        c["RemoteSignatureKey"] = {"Key": p["csrk"], "Counter": "0", "Authenticated": "false"}

    os.makedirs(target, mode=0o700, exist_ok=True)
    with open(os.path.join(target, "info"), "w") as f:
        c.write(f, space_around_delimiters=False)
    os.chmod(os.path.join(target, "info"), 0o600)
    cache = os.path.join(adir, "cache")
    if template and template != target and os.path.isfile(os.path.join(cache, os.path.basename(template))):
        shutil.copy2(os.path.join(cache, os.path.basename(template)), os.path.join(cache, p["address"]))
    for d in stale:
        shutil.rmtree(d)
        cached = os.path.join(cache, os.path.basename(d))
        if os.path.isfile(cached):
            os.remove(cached)
    return True


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_state(state):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)


def sync(dry=False, baseline=False):
    part, data = find_hive()
    if not data:
        print("bt-dualboot-sync: no Windows SYSTEM hive found")
        return False
    pairings = windows_pairings(Hive(data))
    state = load_state()
    changed = False
    print(f"bt-dualboot-sync: reading {part}")
    for adapter, devices in pairings.items():
        if not os.path.isdir(os.path.join(BLUEZ, adapter)):
            continue
        for name, p in sorted(devices.items()):
            key = f"{adapter}/{name}"
            if baseline:
                state[key] = p["time"]
                continue
            if state.get(key, "") >= p["time"]:
                continue
            if write_pairing(adapter, p, dry) and not dry:
                state[key] = p["time"]
                changed = True
    if baseline:
        print(f"  recorded {len(state)} existing Windows pairing(s) as already seen")
    if not dry:
        save_state(state)
    return changed


def install():
    shutil.copy2(os.path.abspath(__file__), INSTALL_BIN)
    os.chmod(INSTALL_BIN, 0o755)
    with open(UNIT_PATH, "w") as f:
        f.write(UNIT)
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "enable", "bt-dualboot-sync.service"], check=True)
    if not os.path.exists(STATE):
        sync(baseline=True)
    print(f"installed {INSTALL_BIN} and {UNIT_PATH}")


def main():
    args = set(sys.argv[1:])
    if args - {"--install", "--dry-run", "--now"}:
        print(__doc__)
        return 2
    if os.geteuid() != 0:
        print("bt-dualboot-sync: run as root")
        return 1
    if "--install" in args:
        install()
    elif "--dry-run" in args:
        sync(dry=True)
    elif "--now" in args:
        subprocess.run(["systemctl", "stop", "bluetooth.service"])
        try:
            sync()
        finally:
            subprocess.run(["systemctl", "start", "bluetooth.service"])
    else:
        sync()
    return 0


if __name__ == "__main__":
    sys.exit(main())
