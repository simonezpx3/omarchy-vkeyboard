#!/usr/bin/env python3
"""
Virtual Keyboard & Layout Controller for Omarchy / Hyprland.
Provides CLI actions for layout detection, switching (CS/EN), and keystroke injection.
"""

import json
import subprocess
import sys


def get_system_keyboard_config():
    opts = []
    layouts = []
    try:
        r = subprocess.run(["hyprctl", "-j", "getoption", "input:kb_options"], capture_output=True, text=True, timeout=2, check=False)
        d = json.loads(r.stdout)
        val = d.get("str", "")
        if val:
            opts = [o.strip() for o in val.split(",") if o.strip()]
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        pass
    try:
        r = subprocess.run(["hyprctl", "-j", "getoption", "input:kb_layout"], capture_output=True, text=True, timeout=2, check=False)
        d = json.loads(r.stdout)
        val = d.get("str", "")
        if val:
            layouts = [l.strip() for l in val.split(",") if l.strip()]
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        pass

    if not opts or not layouts:
        try:
            r = subprocess.run(["localectl", "status"], capture_output=True, text=True, timeout=2, check=False)
            for line in r.stdout.splitlines():
                if "X11 Options:" in line and not opts:
                    opts = [o.strip() for o in line.split(":", 1)[1].split(",") if o.strip()]
                elif "X11 Layout:" in line and not layouts:
                    layouts = [l.strip() for l in line.split(":", 1)[1].split(",") if l.strip()]
        except (subprocess.SubprocessError, OSError):
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

LAYOUT_NAMES = {
    "CS": "Czech (QWERTY)",
    "SK": "Slovak",
    "EN": "English (US)",
    "DE": "German (QWERTZ)",
    "FR": "French (AZERTY)",
    "ES": "Spanish",
    "IT": "Italian",
    "PL": "Polish (Programmers)",
    "UA": "Ukrainian",
    "RU": "Russian",
    "PT": "Portuguese",
    "NL": "Dutch",
    "SE": "Swedish",
    "NO": "Norwegian",
    "DK": "Danish",
    "FI": "Finnish",
    "JP": "Japanese",
    "KR": "Korean",
    "CN": "Chinese",
}

def parse_layout_code(keymap_name, layout_tag=""):
    km = (keymap_name or "").lower()
    lt = (layout_tag or "").lower().strip()
    if "czech" in km or lt in ("cz", "cs"):
        return "CS"
    if "slovak" in km or lt == "sk":
        return "SK"
    if "german" in km or lt in ("de", "at", "ch"):
        return "DE"
    if "french" in km or lt in ("fr", "be"):
        return "FR"
    if "spanish" in km or lt == "es":
        return "ES"
    if "italian" in km or lt == "it":
        return "IT"
    if "polish" in km or lt == "pl":
        return "PL"
    if "ukrainian" in km or lt == "ua":
        return "UA"
    if "russian" in km or lt == "ru":
        return "RU"
    if "portuguese" in km or lt in ("pt", "br"):
        return "PT"
    if "dutch" in km or lt == "nl":
        return "NL"
    if "swedish" in km or lt == "se":
        return "SE"
    if "norwegian" in km or lt == "no":
        return "NO"
    if "danish" in km or lt == "dk":
        return "DK"
    if "finnish" in km or lt == "fi":
        return "FI"
    if "japanese" in km or lt == "jp":
        return "JP"
    if "korean" in km or lt == "kr":
        return "KR"
    if "chinese" in km or lt == "cn":
        return "CN"
    if "english" in km or lt in ("us", "gb", "en"):
        return "EN"
    if lt:
        return lt[:2].upper()
    return km[:2].upper() if len(km) >= 2 else "EN"

def get_layout_info():
    sys_cfg = get_system_keyboard_config()
    configured = []
    raw_layouts = sys_cfg.get("layouts", [])
    
    try:
        res = subprocess.run(["hyprctl", "-j", "devices"], capture_output=True, text=True, timeout=2, check=False)
        data = json.loads(res.stdout)
        keyboards = data.get("keyboards", [])
        
        if not raw_layouts and keyboards:
            raw_layouts = [l.strip() for l in keyboards[0].get("layout", "").split(",") if l.strip()]

        for idx, ltag in enumerate(raw_layouts):
            code = parse_layout_code("", ltag)
            name = LAYOUT_NAMES.get(code, f"{code} ({ltag.upper()})")
            configured.append({"code": code, "index": idx, "tag": ltag, "name": name})

        # Fallback if no layouts configured in XKB: ensure at least EN and CS
        if not configured:
            configured = [
                {"code": "EN", "index": 0, "tag": "us", "name": "English (US)"},
                {"code": "CS", "index": 1, "tag": "cz", "name": "Czech (QWERTY)"}
            ]

        # Look for active primary keyboard
        for kb in keyboards:
            name = kb.get("name", "")
            if "hl-virtual-keyboard" in name or "power-button" in name or "video-bus" in name:
                continue
            keymap = kb.get("active_keymap", "")
            idx = kb.get("active_layout_index", 0)
            ltag = raw_layouts[idx] if idx < len(raw_layouts) else ""
            code = parse_layout_code(keymap, ltag)
            return {
                "code": code,
                "index": idx,
                "name": keymap or LAYOUT_NAMES.get(code, code),
                "configured": configured,
                "sys_cfg": sys_cfg
            }
        
        # Fallback to first keyboard
        if keyboards:
            km = keyboards[0].get("active_keymap", "English (US)")
            idx = keyboards[0].get("active_layout_index", 0)
            ltag = raw_layouts[idx] if idx < len(raw_layouts) else ""
            code = parse_layout_code(km, ltag)
            return {
                "code": code,
                "index": idx,
                "name": km or LAYOUT_NAMES.get(code, code),
                "configured": configured,
                "sys_cfg": sys_cfg
            }
            
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError) as e:
        return {
            "code": "EN",
            "index": 0,
            "name": "English (US)",
            "configured": configured or [{"code": "EN", "index": 0, "tag": "us", "name": "English (US)"}],
            "error": str(e),
            "sys_cfg": sys_cfg
        }
    
    return {
        "code": "EN",
        "index": 0,
        "name": "English (US)",
        "configured": configured or [{"code": "EN", "index": 0, "tag": "us", "name": "English (US)"}],
        "sys_cfg": sys_cfg
    }

def set_layout(target):
    target_str = str(target).strip().lower()
    if target_str in ("next", "toggle", "cycle"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "next"], capture_output=True, timeout=2, check=False)
        return
    if target_str.isdigit():
        subprocess.run(["hyprctl", "switchxkblayout", "all", target_str], capture_output=True, timeout=2, check=False)
        return
    
    sys_cfg = get_system_keyboard_config()
    raw_layouts = [l.lower() for l in sys_cfg.get("layouts", [])]
    for idx, l in enumerate(raw_layouts):
        if target_str in (l, parse_layout_code("", l).lower()):
            subprocess.run(["hyprctl", "switchxkblayout", "all", str(idx)], capture_output=True, timeout=2, check=False)
            return
            
    if target_str in ("cs", "cz", "czech"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "1"], capture_output=True, timeout=2, check=False)
    elif target_str in ("en", "eng", "us", "english"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "0"], capture_output=True, timeout=2, check=False)

def type_key(key_name, modifiers=None):
    cmd = ["wtype", "-s", "10"]
    if modifiers:
        for mod in modifiers:
            cmd.extend(["-M", mod])
    cmd.extend(["-k", key_name])
    if modifiers:
        for mod in reversed(modifiers):
            cmd.extend(["-m", mod])
    subprocess.run(cmd, timeout=2, check=False)

def type_text(text, modifiers=None):
    if not text:
        return
    cmd = ["wtype", "-s", "10"]
    if modifiers:
        for mod in modifiers:
            cmd.extend(["-M", mod])
    cmd.extend(["--", text])
    if modifiers:
        for mod in reversed(modifiers):
            cmd.extend(["-m", mod])
    subprocess.run(cmd, timeout=2, check=False)

def is_terminal():
    try:
        r = subprocess.run(["hyprctl", "-j", "activewindow"], capture_output=True, text=True, timeout=1, check=False)
        w = json.loads(r.stdout)
        tags = w.get("tags", [])
        cls = w.get("class", "").lower()
        if any("terminal" in t.lower() for t in tags):
            return True
        if any(term in cls for term in ("alacritty", "foot", "kitty", "term")):
            return True
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        pass
    return False

def load_keybindings_map():
    import glob
    import os

    cache_files = glob.glob(os.path.expanduser("~/.cache/omarchy/keybindings-*.records"))
    if not cache_files:
        try:
            subprocess.run(["omarchy", "menu", "keybindings", "--print"], capture_output=True, timeout=2, check=False)
            cache_files = glob.glob(os.path.expanduser("~/.cache/omarchy/keybindings-*.records"))
        except (subprocess.SubprocessError, OSError):
            pass
    if not cache_files:
        return {}

    cache_file = max(cache_files, key=os.path.getmtime)
    mapping = {}
    try:
        with open(cache_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\r\n")
                if not line or "\t" not in line:
                    continue
                parts = line.split("\t")
                left = parts[0]
                disp = parts[1] if len(parts) > 1 else ""
                arg = parts[2] if len(parts) > 2 else ""

                combo_part = left.split("→")[0].strip()
                tokens = combo_part.replace("+", " ").split()
                c_mods = set()
                c_keys = []
                for t in tokens:
                    tu = t.upper()
                    if tu in ("SUPER", "WIN", "LOGO"):
                        c_mods.add("SUPER")
                    elif tu in ("SHIFT",):
                        c_mods.add("SHIFT")
                    elif tu in ("CTRL", "CONTROL"):
                        c_mods.add("CTRL")
                    elif tu in ("ALT",):
                        c_mods.add("ALT")
                    else:
                        c_keys.append(tu)
                c_key = " ".join(c_keys)
                mapping[(frozenset(c_mods), c_key)] = (disp, arg)
    except OSError:
        pass
    return mapping

def dispatch_shortcut(key_name, modifiers=None):
    if not key_name:
        return
    mods_list = [m.lower().strip() for m in modifiers] if modifiers else []
    mod_set = set()
    for m in mods_list:
        if m in ("super", "win", "logo"):
            mod_set.add("SUPER")
        elif m == "shift":
            mod_set.add("SHIFT")
        elif m in ("ctrl", "control"):
            mod_set.add("CTRL")
        elif m == "alt":
            mod_set.add("ALT")

    key_norm = key_name.upper().strip()
    if key_norm in ("RETURN", "ENTER"):
        key_norm = "RETURN"
    elif key_norm in (" ", "SPACE"):
        key_norm = "SPACE"
    elif key_norm == "BACKSPACE":
        key_norm = "BACKSPACE"
    elif key_norm == "ESCAPE":
        key_norm = "ESCAPE"
    elif key_norm in ("DELETE", "DEL"):
        key_norm = "DELETE"
    elif key_norm in ("PAGE_UP", "PRIOR", "PGUP"):
        key_norm = "PAGE_UP"
    elif key_norm in ("PAGE_DOWN", "NEXT", "PGDN"):
        key_norm = "PAGE_DOWN"

    # Special handling for universal clipboard actions
    if mod_set == {"SUPER"}:
        if key_norm == "C":
            if is_terminal():
                type_key("Insert", ["ctrl"])
            else:
                type_key("c", ["ctrl"])
            return
        elif key_norm == "V":
            if is_terminal():
                type_key("Insert", ["shift"])
            else:
                type_key("v", ["ctrl"])
            return
        elif key_norm == "X":
            type_key("x", ["ctrl"])
            return

    mapping = load_keybindings_map()
    entry = mapping.get((frozenset(mod_set), key_norm))
    if not entry and key_norm.isdigit():
        entry = mapping.get((frozenset(mod_set), key_norm))

    if entry:
        disp, arg = entry
        if disp == "exec" and arg:
            safe_arg = arg.replace("\\", "\\\\").replace("'", "\\'")
            res = subprocess.run(["hyprctl", "dispatch", f"hl.dsp.exec_cmd('{safe_arg}')"], capture_output=True, text=True, timeout=2, check=False)
            if res.returncode != 0:
                import shlex
                try:
                    cmd_parts = shlex.split(arg)
                    if cmd_parts:
                        subprocess.Popen(cmd_parts, shell=False, start_new_session=True)
                except (ValueError, OSError):
                    pass
            return
        elif disp == "lua" and arg:
            subprocess.run(["hyprctl", "dispatch", arg], capture_output=True, timeout=2, check=False)
            return
        elif disp and arg:
            subprocess.run(["hyprctl", "dispatch", disp, arg], capture_output=True, timeout=2, check=False)
            return
        elif disp:
            subprocess.run(["hyprctl", "dispatch", disp], capture_output=True, timeout=2, check=False)
            return

    # Fallback to wtype
    type_key(key_name, mods_list)

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
    elif action == "dispatch":
        key_name = sys.argv[2] if len(sys.argv) > 2 else ""
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        dispatch_shortcut(key_name, mods)

if __name__ == "__main__":
    main()
