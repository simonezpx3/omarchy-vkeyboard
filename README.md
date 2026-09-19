# Virtual Keyboard & Layout (`simonez.vkeyboard`)

An on-screen virtual keyboard with instant `wtype` typing, CS/ENG layout switcher, and **Unified CRT Monolithic Grid** styling for Omarchy Linux & Hyprland.

**Authors:** `simonez & Arci`  
**License:** MIT  

---

## Features

* **󰌌 Bar Icon & Dynamic Badge:**
  * Displays the keyboard icon and current layout badge (`CS` / `EN`).
  * **Left Click:** Toggles the full On-Screen Virtual Keyboard.
  * **Right Click:** Opens the CRT Popout Menu for selecting `Čeština (QWERTY)` or `English (US)`.
* **Interactive On-Screen Virtual Keyboard (OSK):**
  * Built as a non-focus-stealing Wayland overlay (`WlrKeyboardFocus.None`), so active windows (terminals, editors, browser) retain focus.
  * Adaptive layout: Diacritics row and symbols adjust automatically based on active layout (Czech accents `+ ě š č ř ž ý á í é` vs English `1 2 3 4 5 6 7 8 9 0`).
  * Direct keystroke injection via `wtype`.
  * Modifiers support: Shift, CapsLock, Ctrl, Alt, Super (Win), Space, Enter, Backspace, Arrows.
  * Live synchronization with Hyprland's `activelayout` events.

---

## Installation

```bash
cd ~/Projects/VirtualKeyboard
./install.sh
```

---

## CLI Control (`vkeyboard-ctl`)

```bash
vkeyboard-ctl status      # Show current active layout
vkeyboard-ctl switch cs   # Switch layout to Czech
vkeyboard-ctl switch en   # Switch layout to English
vkeyboard-ctl toggle      # Toggle layout (Alt+Shift equivalent)
```
