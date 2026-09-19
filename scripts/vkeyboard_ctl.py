#!/usr/bin/env python3
"""
Virtual Keyboard & Layout Controller for Omarchy / Hyprland.
Provides CLI actions for layout detection, switching (CS/EN), and keystroke injection.
"""

import sys
import subprocess
import json

def get_layout_info():
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
                return {"code": "CS", "index": idx, "name": keymap}
            elif "english" in keymap.lower() or "us" in keymap.lower():
                return {"code": "EN", "index": idx, "name": keymap}
        
        # Fallback to first keyboard
        if keyboards:
            km = keyboards[0].get("active_keymap", "English (US)")
            idx = keyboards[0].get("active_layout_index", 0)
            code = "CS" if "czech" in km.lower() else "EN"
            return {"code": code, "index": idx, "name": km}
            
    except Exception as e:
        return {"code": "EN", "index": 0, "name": "English (US)", "error": str(e)}
    
    return {"code": "EN", "index": 0, "name": "English (US)"}

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
