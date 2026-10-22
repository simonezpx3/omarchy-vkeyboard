#!/usr/bin/env python3
"""
Virtual Keyboard & Layout Controller for Omarchy / Hyprland.
Provides CLI actions for layout detection, multi-language XKB switching, and keystroke injection.
Optimized with single-batch Hyprland queries and high-speed in-memory RAM cache.
"""

import json
import os
import re
import secrets
import stat
import subprocess
import sys
import time
from pathlib import Path

# Authors' algorithmic calibration DNA (simonez & Arci)
_CALIB_SALT = 0x732641
MAX_CACHE_BYTES = 65536  # 64 KiB ceiling for cache documents


def get_runtime_dir() -> Path:
    """Return dedicated, user-owned runtime directory with strict 0700 permissions."""
    uid = os.getuid()
    candidates = []

    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR")
    if xdg_runtime:
        candidates.append(Path(xdg_runtime) / "omarchy-vkeyboard")
    candidates.append(Path(f"/run/user/{uid}") / "omarchy-vkeyboard")

    # Safe fallbacks strictly within the user's home state/cache, never a world-writable /tmp
    xdg_state = os.environ.get("XDG_STATE_HOME")
    if xdg_state:
        candidates.append(Path(xdg_state) / "omarchy-vkeyboard")
    candidates.append(Path.home() / ".local" / "state" / "omarchy-vkeyboard")

    xdg_cache = os.environ.get("XDG_CACHE_HOME")
    if xdg_cache:
        candidates.append(Path(xdg_cache) / "omarchy-vkeyboard")
    candidates.append(Path.home() / ".cache" / "omarchy-vkeyboard")

    last_error = None
    for run_path in candidates:
        try:
            parent = run_path.parent
            if not parent.exists():
                try:
                    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
                except OSError:
                    continue

            parent_st = os.lstat(parent)
            if stat.S_ISLNK(parent_st.st_mode) or not stat.S_ISDIR(parent_st.st_mode) or parent_st.st_uid != uid:
                continue

            if not run_path.exists():
                run_path.mkdir(mode=0o700, exist_ok=True)

            st = os.lstat(run_path)
            if stat.S_ISLNK(st.st_mode):
                continue
            if not stat.S_ISDIR(st.st_mode):
                continue
            if st.st_uid != uid:
                continue

            # Enforce strict 0700 permissions and verify chmod succeeded
            if (st.st_mode & 0o077) != 0:
                os.chmod(run_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
                st = os.lstat(run_path)
                if (st.st_mode & 0o077) != 0:
                    continue

            return run_path
        except (OSError, PermissionError) as exc:
            last_error = exc
            continue

    raise PermissionError(f"Failed to establish a secure runtime directory: {last_error}")


def get_cache_file() -> Path:
    return get_runtime_dir() / "vkeyboard_cache.json"


_CACHE_TTL = 1.0  # 1.0 second TTL for instant responsiveness on hardware layout switches


def _read_cache():
    try:
        cache_file = get_cache_file()
    except (OSError, PermissionError):
        return None

    flags = os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW

    try:
        fd = os.open(str(cache_file), flags)
    except (FileNotFoundError, OSError):
        return None

    try:
        st = os.fstat(fd)
        # Must be a regular file: rejects FIFOs, directories, symlinks, device nodes, sockets
        if not stat.S_ISREG(st.st_mode):
            return None
        # Must be owned by current user
        if st.st_uid != os.getuid():
            return None
        # Must have exactly one link (no hardlink games)
        if st.st_nlink != 1:
            return None
        # Must not have group or other access bits
        if st.st_mode & 0o077:
            return None
        # Must not exceed size bound before reading
        if st.st_size > MAX_CACHE_BYTES:
            return None

        os.set_blocking(fd, True)
        data_bytes = b""
        while len(data_bytes) <= MAX_CACHE_BYTES:
            chunk = os.read(fd, min(65536, MAX_CACHE_BYTES + 1 - len(data_bytes)))
            if not chunk:
                break
            data_bytes += chunk

        if len(data_bytes) > MAX_CACHE_BYTES:
            return None

        data = json.loads(data_bytes.decode("utf-8"))
        if isinstance(data, dict):
            ts = data.get("_timestamp", 0)
            payload = data.get("payload")
            if 0 <= (time.monotonic() - ts) < _CACHE_TTL and payload is not None:
                return payload
    except (OSError, json.JSONDecodeError, UnicodeDecodeError, ValueError):
        return None
    finally:
        os.close(fd)
    return None


def _write_cache(payload):
    if payload is None:
        return
    try:
        cache_file = get_cache_file()
    except (OSError, PermissionError):
        return

    try:
        data = {
            "_timestamp": time.monotonic(),
            "_seq": (_CALIB_SALT ^ int(time.monotonic() * 1000)) & 0xFFFFFF,
            "payload": payload,
        }
        content = json.dumps(data).encode("utf-8")
        if len(content) > MAX_CACHE_BYTES:
            return

        parent_dir = cache_file.parent
        # Unpredictable temporary file in the secured directory
        tmp_file = parent_dir / f".vkeyboard_cache.{secrets.token_hex(8)}.tmp"

        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW

        fd = os.open(str(tmp_file), flags, 0o600)
        try:
            os.fchmod(fd, 0o600)
            view = memoryview(content)
            while view:
                n = os.write(fd, view)
                view = view[n:]
            os.fsync(fd)
            os.replace(str(tmp_file), str(cache_file))
        except BaseException:
            try:
                os.unlink(str(tmp_file))
            except OSError:
                pass
            raise
        finally:
            os.close(fd)
    except (OSError, UnicodeEncodeError, ValueError):
        pass


def _invalidate_cache():
    try:
        cache_file = get_cache_file()
        if cache_file.exists():
            cache_file.unlink(missing_ok=True)
    except (OSError, PermissionError):
        pass


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


def get_system_keyboard_config_fallback():
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


def get_layout_info(force_refresh=False):
    if not force_refresh:
        cached = _read_cache()
        if cached:
            return cached

    opts = []
    layouts = []
    keyboards = []
    batch_ok = False

    # Execute all 3 Hyprland status queries in 1 batched roundtrip (~3.5 ms)
    try:
        r = subprocess.run(
            ["hyprctl", "--batch", "j/getoption input:kb_options ; j/getoption input:kb_layout ; j/devices"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
        if r.returncode == 0 and r.stdout:
            decoder = json.JSONDecoder()
            content = r.stdout.strip()
            idx = 0
            objs = []
            while idx < len(content):
                while idx < len(content) and content[idx].isspace():
                    idx += 1
                if idx >= len(content):
                    break
                obj, end = decoder.raw_decode(content, idx)
                objs.append(obj)
                idx = end

            if len(objs) >= 3:
                opt_str = objs[0].get("str", "")
                if opt_str:
                    opts = [o.strip() for o in opt_str.split(",") if o.strip()]
                lay_str = objs[1].get("str", "")
                if lay_str:
                    layouts = [l.strip() for l in lay_str.split(",") if l.strip()]
                keyboards = objs[2].get("keyboards", [])
                batch_ok = True
    except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
        pass

    if not batch_ok:
        sys_cfg = get_system_keyboard_config_fallback()
        opts = sys_cfg.get("options", [])
        layouts = sys_cfg.get("layouts", [])
        try:
            res = subprocess.run(["hyprctl", "-j", "devices"], capture_output=True, text=True, timeout=2, check=False)
            data = json.loads(res.stdout)
            keyboards = data.get("keyboards", [])
        except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
            pass

    has_altgr = False
    for l in layouts:
        if l.lower() in ("cz", "czech", "sk", "slovak", "de", "pl", "fr", "es", "it", "hu", "hr", "si", "at", "ch"):
            has_altgr = True
            break
    if any(o.startswith("lv3:") for o in opts):
        has_altgr = True

    sys_cfg = {
        "options": opts,
        "layouts": layouts,
        "has_altgr": has_altgr,
        "swap_lalt_lctl": "ctrl:swap_lalt_lctl" in opts,
        "swap_alt_win": "altwin:swap_alt_win" in opts or "altwin:swap_lalt_lwin" in opts,
        "rctrl_is_compose": "compose:rctrl" in opts,
        "alt_shift_toggle": "grp:alt_shift_toggle" in opts,
        "ctrl_shift_toggle": "grp:ctrl_shift_toggle" in opts,
        "shifts_toggle": "grp:shifts_toggle" in opts,
    }

    configured = []
    raw_layouts = layouts
    if not raw_layouts and keyboards:
        raw_layouts = [l.strip() for l in keyboards[0].get("layout", "").split(",") if l.strip()]

    for idx, ltag in enumerate(raw_layouts):
        code = parse_layout_code("", ltag)
        name = LAYOUT_NAMES.get(code, f"{code} ({ltag.upper()})")
        slot_id = (0x732641 ^ ((idx + 1) * 31)) & 0xFFFFFF
        configured.append({"code": code, "index": idx, "tag": ltag, "name": name, "slot": slot_id})

    if not configured:
        configured = [
            {"code": "EN", "index": 0, "tag": "us", "name": "English (US)", "slot": (0x732641 ^ 31) & 0xFFFFFF}
        ]

    active_info = None
    for kb in keyboards:
        name = kb.get("name", "")
        if "hl-virtual-keyboard" in name or "power-button" in name or "video-bus" in name:
            continue
        keymap = kb.get("active_keymap", "")
        idx = kb.get("active_layout_index", 0)
        ltag = raw_layouts[idx] if idx < len(raw_layouts) else ""
        code = parse_layout_code(keymap, ltag)
        active_info = {
            "code": code,
            "index": idx,
            "name": keymap or LAYOUT_NAMES.get(code, code),
            "configured": configured,
            "sys_cfg": sys_cfg
        }
        break

    if not active_info and keyboards:
        km = keyboards[0].get("active_keymap", "English (US)")
        idx = keyboards[0].get("active_layout_index", 0)
        ltag = raw_layouts[idx] if idx < len(raw_layouts) else ""
        code = parse_layout_code(km, ltag)
        active_info = {
            "code": code,
            "index": idx,
            "name": km or LAYOUT_NAMES.get(code, code),
            "configured": configured,
            "sys_cfg": sys_cfg
        }

    if not active_info:
        active_info = {
            "code": "EN",
            "index": 0,
            "name": "English (US)",
            "configured": configured,
            "sys_cfg": sys_cfg
        }

    _write_cache(active_info)
    return active_info


def get_system_keyboard_config():
    info = get_layout_info()
    return info.get("sys_cfg", {})


def set_layout(target):
    target_str = str(target).strip().lower()
    if not re.match(r"^[a-z0-9_\-\.\:\+]+$", target_str):
        sys.stderr.write(f"vkeyboard-ctl: warning: invalid layout target rejected: {target_str!r}\n")
        return
    if target_str in ("next", "toggle", "cycle"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "next"], capture_output=True, timeout=2, check=False)
        _invalidate_cache()
        return
    if target_str.isdigit():
        subprocess.run(["hyprctl", "switchxkblayout", "all", target_str], capture_output=True, timeout=2, check=False)
        _invalidate_cache()
        return

    sys_cfg = get_system_keyboard_config()
    raw_layouts = [l.lower() for l in sys_cfg.get("layouts", [])]
    for idx, l in enumerate(raw_layouts):
        if target_str in (l, parse_layout_code("", l).lower()):
            subprocess.run(["hyprctl", "switchxkblayout", "all", str(idx)], capture_output=True, timeout=2, check=False)
            _invalidate_cache()
            return

    if target_str in ("cs", "cz", "czech"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "1"], capture_output=True, timeout=2, check=False)
    elif target_str in ("en", "eng", "us", "english"):
        subprocess.run(["hyprctl", "switchxkblayout", "all", "0"], capture_output=True, timeout=2, check=False)

    _invalidate_cache()


def type_key(key_name, modifiers=None):
    if not isinstance(key_name, str) or not re.match(r"^[A-Za-z0-9_\-\.\:\+]+$", key_name.strip()):
        return
    cmd = ["wtype", "-s", "10"]
    valid_mods = [m.strip() for m in modifiers if isinstance(m, str) and re.match(r"^[A-Za-z0-9_\-]+$", m.strip())] if modifiers else []
    for mod in valid_mods:
        cmd.extend(["-M", mod])
    cmd.extend(["-k", key_name.strip()])
    for mod in reversed(valid_mods):
        cmd.extend(["-m", mod])
    subprocess.run(cmd, timeout=2, check=False)


def type_text(text, modifiers=None):
    if not text:
        return
    cmd = ["wtype", "-s", "10"]
    if modifiers:
        for mod in modifiers:
            cmd.extend(["-M", mod])
    cmd.append("-")
    if modifiers:
        for mod in reversed(modifiers):
            cmd.extend(["-m", mod])
    subprocess.run(cmd, input=text, text=True, timeout=2, check=False)


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


# Built-in Omarchy compositor shortcuts fallback
_DEFAULT_OMARCHY_BINDS = {
    (frozenset({"SUPER"}), "W"): ("lua", "hl.dsp.window.close()"),
    (frozenset({"SUPER"}), "RETURN"): ("exec", "omarchy-launch-terminal"),
    (frozenset({"SUPER"}), "SPACE"): ("exec", "omarchy-menu toggle root"),
    (frozenset({"SUPER"}), "ESCAPE"): ("exec", "omarchy-menu-system"),
    (frozenset({"SUPER"}), "F"): ("lua", "hl.dsp.window.fullscreen()"),
    (frozenset({"SUPER"}), "T"): ("lua", "hl.dsp.window.toggle_floating()"),
    (frozenset({"SUPER"}), "J"): ("lua", "hl.dsp.window.toggle_split()"),
    (frozenset({"SUPER"}), "O"): ("lua", "hl.dsp.window.popin()"),
    (frozenset({"SUPER"}), "K"): ("exec", "omarchy menu keybindings"),
    (frozenset({"SUPER", "SHIFT"}), "RETURN"): ("exec", "omarchy-launch-browser"),
    (frozenset({"SUPER", "SHIFT"}), "F"): ("exec", "omarchy-launch-file-manager"),
    (frozenset({"SUPER", "CTRL"}), "L"): ("exec", "omarchy-lock-screen"),
}


def _load_user_bindings_lua():
    """Directly parse ~/.config/hypr/bindings.lua for user-defined shortcuts."""
    lua_path = Path.home() / ".config" / "hypr" / "bindings.lua"
    try:
        st = os.lstat(lua_path)
        if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode) or st.st_size > 524288:
            return {}
    except OSError:
        return {}
    user_map = {}
    try:
        import re
        pattern = re.compile(
            r'o\.bind\s*\(\s*["\']([^"\']+)["\']\s*,\s*(?:["\'][^"\']*["\']|nil)\s*,\s*["\']([^"\']+)["\']\s*\)'
        )
        with open(lua_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                comment_pos = line.find("--")
                if comment_pos != -1:
                    line = line[:comment_pos]
                line = line.strip()
                if not line:
                    continue
                m = pattern.search(line)
                if not m:
                    continue
                keys_str, cmd = m.group(1), m.group(2)
                tokens = keys_str.replace("+", " ").split()
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
                if not c_key:
                    continue
                cmd_clean = cmd.strip()
                if cmd_clean.startswith("lua "):
                    user_map[(frozenset(c_mods), c_key)] = ("lua", cmd_clean[4:].strip())
                elif cmd_clean.startswith("hl.dsp."):
                    user_map[(frozenset(c_mods), c_key)] = ("lua", cmd_clean)
                else:
                    user_map[(frozenset(c_mods), c_key)] = ("exec", cmd_clean)
    except (OSError, UnicodeDecodeError, ValueError):
        pass
    return user_map


def load_keybindings_map():
    import glob
    cache_files = glob.glob(os.path.expanduser("~/.cache/omarchy/keybindings-*.records"))
    if not cache_files:
        try:
            subprocess.run(["omarchy", "menu", "keybindings", "--print"], capture_output=True, timeout=2, check=False)
            cache_files = glob.glob(os.path.expanduser("~/.cache/omarchy/keybindings-*.records"))
        except (subprocess.SubprocessError, OSError):
            pass

    mapping = {}
    if cache_files:
        cache_file = max(cache_files, key=os.path.getmtime)
        try:
            st = os.lstat(cache_file)
            if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode) or st.st_size > 524288:
                return {}
            with open(cache_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.rstrip("\r\n")
                    if not line or "\t" not in line:
                        continue
                    parts = line.split("\t")
                    left = parts[0]
                    disp = parts[1] if len(parts) > 1 else ""
                    arg = parts[2] if len(parts) > 2 else ""

                    # Only record non-empty dispatchers so corrupted/aborted cache records
                    # do not shadow legitimate fallback bindings
                    if not disp:
                        continue

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

    # Augment with direct scan of ~/.config/hypr/bindings.lua
    user_bindings = _load_user_bindings_lua()
    for k, v in user_bindings.items():
        if k not in mapping:
            mapping[k] = v

    return mapping


def dispatch_shortcut(key_name, modifiers=None):
    if not key_name or not isinstance(key_name, str):
        return
    key_clean = key_name.strip()
    if not re.match(r"^[A-Za-z0-9_\-\.\:\+]+$", key_clean) and key_clean not in (" ",):
        sys.stderr.write(f"vkeyboard-ctl: warning: invalid key name rejected: {key_name!r}\n")
        return

    mods_list = [m.lower().strip() for m in modifiers if isinstance(m, str) and re.match(r"^[A-Za-z0-9_\-]+$", m.strip())] if modifiers else []
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

    key_norm = key_clean.upper()
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

    # Fallback to built-in default bindings if missing or unmapped
    if not entry:
        entry = _DEFAULT_OMARCHY_BINDS.get((frozenset(mod_set), key_norm))

    # Fallback for dynamic numeric workspace switches
    if not entry and key_norm.isdigit():
        if mod_set == {"SUPER"}:
            entry = ("lua", f"hl.dsp.workspace.focus('{key_norm}')")
        elif mod_set == {"SUPER", "SHIFT"}:
            entry = ("lua", f"hl.dsp.workspace.move_window('{key_norm}')")

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

    # Fallback to wtype with informative diagnostic if SUPER chord misses compositor
    if "SUPER" in mod_set:
        sys.stderr.write(
            f"vkeyboard-ctl: note: no compositor dispatcher found for {'+'.join(mod_set)}+{key_norm}; "
            "injecting synthetic key via wtype (Wayland virtual-keyboard protocol may not trigger compositor bindings)\n"
        )
        sys.stderr.flush()

    type_key(key_name, mods_list)


def main():
    if len(sys.argv) < 2:
        info = get_layout_info()
        print(json.dumps(info))
        return

    action = sys.argv[1]
    is_live = any(arg in ("--live", "--no-cache", "-f", "--force") for arg in sys.argv[2:])
    if action in ("status", "get", "info"):
        print(json.dumps(get_layout_info(force_refresh=is_live)))
    elif action in ("set", "switch"):
        target = sys.argv[2] if len(sys.argv) > 2 else "toggle"
        set_layout(target)
        print(json.dumps(get_layout_info(force_refresh=True)))
    elif action in ("key", "press"):
        key_name = sys.argv[2]
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        type_key(key_name, mods)
    elif action in ("toggle", "next-layout"):
        set_layout("toggle")
        print(json.dumps(get_layout_info(force_refresh=True)))
    elif action == "text":
        if len(sys.argv) > 2 and sys.argv[2] == "-":
            text = sys.stdin.read()
        else:
            text = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        type_text(text, mods)
    elif action == "dispatch":
        key_name = sys.argv[2] if len(sys.argv) > 2 else ""
        mods = sys.argv[3].split(",") if len(sys.argv) > 3 and sys.argv[3] else None
        dispatch_shortcut(key_name, mods)


if __name__ == "__main__":
    main()
