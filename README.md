# Virtual Keyboard & Layout (`simonez.vkeyboard`)

An advanced, non-focus-stealing On-Screen Virtual Keyboard (OSK) with instant `wtype` keystroke injection, system shortcut dispatching, dynamic multi-language XKB layout switching, and **Unified CRT Monolithic Grid** styling for Omarchy Linux & Hyprland.

**Authors:** `simonez & Arci`  
**Version:** `1.5.9`  
**License:** MIT  

---

## 1. Core Architecture & Window Focus Resolution

### How the Virtual Keyboard Targets Windows
* **Non-Focus-Stealing Layer-Shell (`WlrKeyboardFocus.None`):**
  * The virtual keyboard runs on `WlrLayer.Overlay` with `WlrKeyboardFocus.None` and `exclusionMode: ExclusionMode.Ignore`.
  * Clicking keys on the virtual keyboard never steals keyboard focus from your active application window. The target window (e.g. Alacritty, Firefox, text editor) stays 100% active, its text cursor continues blinking, and input streams directly into it.
* **Wayland Seat Routing (`zwp_virtual_keyboard_v1` on `wl_seat`):**
  * Keystrokes are injected via the native Wayland virtual keyboard protocol into the current `wl_seat`.
  * The compositor (Hyprland) routes virtual keystrokes to whichever client surface holds active keyboard focus at that moment.

### Interaction with Hyprland's `follow_mouse` Focus Model
* **Default Focus Mode (`follow_mouse = 1` - Focus Follows Mouse):**
  * By default in Omarchy Linux and Hyprland, moving the mouse cursor across an open window immediately gives that window keyboard focus without clicking.
  * When moving the mouse onto the virtual keyboard, because the keyboard explicitly rejects focus (`WlrKeyboardFocus.None`), the keyboard focus stays locked on the window the cursor crossed last.
  * *Tip:* If you hover over Window B on your way to the virtual keyboard, Window B will receive the focus.
* **Click-to-Focus Alternative (`follow_mouse = 2`):**
  * If you prefer switching focus exclusively by explicit mouse clicks (so hovering over windows never changes focus), you can set `follow_mouse = 2` in `~/.config/hypr/input.lua`:
    ```lua
    hl.config({
      input = {
        follow_mouse = 2,
      }
    })
    ```

---

## 2. Key Features

### 󰌌 Bar Indicator & Popout Menu
* **Left Click:** Toggles the full On-Screen Virtual Keyboard on/off.
* **Right Click:** Opens the CRT Quick Settings Panel:
  * **Active Layout Selector:** Dynamically detects all configured XKB layouts from Hyprland with live indicators and switching.
  * **6 Hardware Formats:** 60%, 65%, 75%, 80% (TKL), Full Size, and macOS Layout.
  * **Opacity / Transparency Slider:** Smooth CRT slider (`25%–100%`) with instant live preview.
  * **System XKB & Hardware Profile:** Live audit of system layout options, AltGr Level 3, and modifier toggle settings.

### System Shortcut Dispatcher (`SUPER` combinations)
* Wayland normally isolates virtual keyboards from compositor-level root keybindings for security.
* `simonez.vkeyboard` integrates an intelligent **System Shortcut Dispatcher** via `vkeyboard-ctl dispatch`:
  * Intercepts combinations when `SUPER` is active and resolves them against active Omarchy & Hyprland keybindings.
  * **`SUPER + SPACE`** $\rightarrow$ Omarchy launcher / root menu.
  * **`SUPER + RETURN`** $\rightarrow$ Terminal.
  * **`SUPER + A`** $\rightarrow$ Arci AI Scratchpad (`arci-scratchpad`).
  * **`SUPER + SHIFT + A`** $\rightarrow$ Arci Quick Explainer (`arci-quick-prompt`).
  * **`SUPER + ALT + A`** $\rightarrow$ Arci Vision Explainer (`arci-vision-prompt`).
  * **`SUPER + SHIFT + V`** $\rightarrow$ Arci Voice Assistant (`arci-voice`).
  * **`SUPER + B`** $\rightarrow$ Beads Viewer (`beads-launcher`).
  * **`SUPER + H`** $\rightarrow$ Gaming GPU Telemetry HUD (`gpu-workload osd`).
  * **`SUPER + W`** $\rightarrow$ Close active window (`hl.dsp.window.close()`).
  * **`SUPER + F`** $\rightarrow$ Toggle fullscreen.
  * **`SUPER + T`** $\rightarrow$ Toggle floating/tiling.
  * **`SUPER + 1` .. `9`** $\rightarrow$ Switch workspace 1–9.
  * **`SUPER + C / V / X`** $\rightarrow$ Universal copy, paste, cut with automatic terminal detection.

### Navigation Keys & Double-Shift Protection
* Modernized keysyms: `Page_Up` and `Page_Down` (with fallback for legacy `Prior` / `Next`).
* Pre-sleep delay (`-s 10`) ensuring reliable delivery across Wayland clients.
* Clean text typing: `sendChar()` avoids redundant double-shift modifiers on text characters (`A`, `!`, `1`), preserving exact diacritics and symbols on both US and Czech QWERTY layouts.
* Dedicated system hardware keys: `PrtSc` (direct screenshot/OCR capture), `Calc` (`omacalc`), and Volume/Mute controls (`wpctl`).

---

## 3. Installation & Removal

### Installation
```bash
cd ~/Projects/VirtualKeyboard
./install.sh
```

### Removal
```bash
cd ~/Projects/VirtualKeyboard
./uninstall.sh
```

---

## 4. CLI Control (`vkeyboard-ctl`)

```bash
vkeyboard-ctl status              # Show active layout & system configuration
vkeyboard-ctl switch cs          # Switch layout to Czech (QWERTY)
vkeyboard-ctl switch en          # Switch layout to English (US)
vkeyboard-ctl toggle             # Toggle between configured layouts
vkeyboard-ctl dispatch space super    # Dispatch Super+Space system shortcut
vkeyboard-ctl key Page_Up shift       # Send Shift+Page_Up
vkeyboard-ctl text "Hello World"      # Type arbitrary text string
```
