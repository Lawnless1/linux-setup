#!/usr/bin/env python3
"""Hide the Noctalia bar on a monitor while its focused window is maximized
to the screen edges (Mod+Up, maximize-window-to-edges), show it otherwise.

niri does not report "maximized to edges" in its IPC, so a window counts as
maximized when its tile spans the full output width (normal and
maximize-column tiles keep the 10px gaps) and nearly the full height (the
tolerance covers the bar's reserved zone while the bar is still shown).
Fullscreen windows match too, which is harmless: they cover the bar anyway.

Started by niri (spawn-at-startup); follows `niri msg event-stream`.
"""
import json
import subprocess

BAR = "default"
HEIGHT_TOLERANCE = 64  # px; > bar reserved zone (thickness + margin_edge)


def niri_json(what):
    out = subprocess.run(["niri", "msg", "--json", what],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def wanted_hidden():
    outputs = niri_json("outputs")
    windows = {w["id"]: w for w in niri_json("windows")}
    hidden = {}
    for ws in niri_json("workspaces"):
        out = outputs.get(ws["output"] or "")
        if not ws["is_active"] or not out or not out.get("logical"):
            continue
        win = windows.get(ws["active_window_id"])
        logical = out["logical"]
        maxed = False
        if win:
            w, h = win["layout"]["tile_size"]
            maxed = (w >= logical["width"]
                     and h >= logical["height"] - HEIGHT_TOLERANCE)
        hidden[ws["output"]] = maxed
    return hidden


def main():
    state = {}  # output -> bar hidden?
    stream = subprocess.Popen(["niri", "msg", "--json", "event-stream"],
                              stdout=subprocess.PIPE, text=True)
    for _ in stream.stdout:
        try:
            target = wanted_hidden()
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            continue
        for output, hide in target.items():
            if state.get(output) == hide:
                continue
            cmd = "bar-hide" if hide else "bar-show"
            # Noctalia may not be up yet at login: leave state unset so the
            # next event retries.
            r = subprocess.run(["noctalia", "msg", cmd, BAR, output],
                               capture_output=True)
            if r.returncode == 0:
                state[output] = hide


if __name__ == "__main__":
    main()
