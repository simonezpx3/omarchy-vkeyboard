#!/usr/bin/env python3
"""
Virtual Keyboard & Layout Controller for Omarchy / Hyprland.
Provides CLI actions for layout detection, switching (CS/EN), and keystroke injection.
"""

import sys
import subprocess
import json

def get_system_keyboard_config():
    opts = []
    layouts = []
    try:
        r = subprocess.run(["hyprctl", "-j", "getoption", "input:kb_options"], capture_output=True, text=True, timeout=2)
        d = json.loads(r.stdout)
        val = d.get("str", "")
        if val:
            opts = [o.strip() for o in val.split(",") if o.strip()]
    except Exception:
        pass
    try:
        r = subprocess.run(["hyprctl", "-j", "getoption", "input:kb_layout"], capture_output=True, text=True, timeout=2)
        d = json.loads(r.stdout)
        val = d.get("str", "")
        if val:
            layouts = [l.strip() for l in val.split(",") if l.strip()]
    except Exception:
        pass

    if not opts or not layouts:
        try:
            r = subprocess.run(["localectl", "status"], capture_output=True, text=True, timeout=2)
            for line in r.stdout.splitlines():
                if "X11 Options:" in line and not opts:
                    opts = [o.strip() for o in line.split(":", 1)[1].split(",") if o.strip()]
                elif "X11 Layout:" in line and not layouts:
                    layouts = [l.strip() for l in line.split(":", 1)[1].split(",") if l.strip()]
        except Exception:
            pass

    has_altgr = False
    for l in layouts:
        if l.lower() in ("cz", "czech", "sk", "slovak", "de", "pl", "fr", "es", "it", "hu", "hr", "si", "at", "ch"):
            has_altgr = True
            break
    if any(o.startswith("lv3:") for o in opts):
        has_altgr = True

    swap_lalt_lctl = "ctrl:swap_lalt_lctl" in opts
    swap_alt_win = "altwin:swap_alt_win" in opts or "altwin:swap_lalt_lwin" in opts
    rctrl_is_compose = "compose:rctrl" in opts
    alt_shift_toggle = "grp:alt_shift_toggle" in opts
    ctrl_shift_toggle = "grp:ctrl_shift_toggle" in opts
    shifts_toggle = "grp:shifts_toggle" in opts

    return {
        "options": opts,
        "layouts": layouts,
        "has_altgr": has_altgr,
        "swap_lalt_lctl": swap_lalt_lctl,
        "swap_alt_win": swap_alt_win,
        "rctrl_is_compose": rctrl_is_compose,
        "alt_shift_toggle": alt_shift_toggle,
        "ctrl_shift_toggle": ctrl_shift_toggle,
        "shifts_toggle": shifts_toggle,
    }

def get_layout_info():
    sys_cfg = get_system_keyboard_config()
    try:
        res = subprocess.run(["hyprctl", "-j", "devices"], capture_output=True, text=True, timeout=2)
        data = json.loads(res.stdout)
        keyboards = data.get("keyboards", [])
        
        # Look for the primary or typed keyboard
        for kb in keyboards:
            name = kb.get("name", "")
            if "hl-virtual-keyboard" in name or "power-button" in name or "video-bus" in name:
                continue
            keymap = kb.get("active_keymap", "")
            idx = kb.get("active_layout_index", 0)
            if "czech" in keymap.lower() or "cz" in keymap.lower():
                return {"code": "CS", "index": idx, "name": keymap, "sys_cfg": sys_cfg}
            elif "english" in keymap.lower() or "us" in keymap.lower():
                return {"code": "EN", "index": idx, "name": keymap, "sys_cfg": sys_cfg}
        
        # Fallback to first keyboard
        if keyboards:
            km = keyboards[0].get("active_keymap", "English (US)")
            idx = keyboards[0].get("active_layout_index", 0)
            code = "CS" if "czech" in km.lower() else "EN"
            return {"code": code, "index": idx, "name": km, "sys_cfg": sys_cfg}
            
    except Exception as e:
        return {"code": "EN", "index": 0, "name": "English (US)", "error": str(e), "sys_cfg": sys_cfg}
    
    return {"code": "EN", "index": 0, "name": "English (US)", "sys_cfg": sys_cfg}

def set_layout(target):
    target = target.lower()
    if target in ("cs", "cz", "czech", "1"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "1"], capture_output=True, timeout=2)
    elif target in ("en", "eng", "us", "english", "0"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "0"], capture_output=True, timeout=2)
    elif target in ("next", "toggle", "cycle"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "next"], capture_output=True, timeout=2)

def type_key(key_name, modifiers=None):
    cmd = ["wtype"]
    if modifiers:
        for mod in modifiers:
            cmd.extend(["-M", mod])
    cmd.extend(["-k", key_name])
    if modifiers:
        for mod in reversed(modifiers):
            cmd.extend(["-m", mod])
    subprocess.run(cmd, timeout=2)

def type_text(text, modifiers=None):
    if not text:
        return
    cmd = ["wtype"]
    if modifiers:
        for mod in modifiers:
            cmd.extend(["-M", mod])
    cmd.extend(["--", text])
    if modifiers:
        for mod in reversed(modifiers):
            cmd.extend(["-m", mod])
    subprocess.run(cmd, timeout=2)

def main():
    if len(sys.argv) < 2:
        info = get_layout_info()
        print(json.dumps(info))
        return

    action = sys.argv[1]
    if action in ("status", "get", "info"):
        print(json.dumps(get_layout_info()))
    elif action in ("set", "switch"):
        target = sys.argv[2] if len(sys.argv) > 2 else "toggle"
        set_layout(target)
        print(json.dumps(get_layout_info()))
    elif action == "toggle":
        set_layout("toggle")
        print(json.dumps(get_layout_info()))
    elif action == "key":
        key_name = sys.argv[2]
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        type_key(key_name, mods)
    elif action == "text":
        text = sys.argv[2]
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        type_text(text, mods)

if __name__ == "__main__":
    main()
