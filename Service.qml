// Virtual Keyboard & Layout — Quattro Service Singleton
// Manages system XKB status, Hyprland layout events, modifiers state, and typing execution.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var settings: ({})
  property var bar: null
  property bool activePolling: true

  // UI Navigation Signals
  signal openPanelRequested()
  signal closePanelRequested()
  signal togglePanelRequested()

  // Live Script Paths (Zero dependency on pre-existing PATH; resolves from plugin location)
  readonly property string ctlScriptPath: Qt.resolvedUrl("scripts/vkeyboard_ctl.py").toString().replace(/^file:\/\//, "")
  readonly property string ctlBinPath: Qt.resolvedUrl("bin/vkeyboard-ctl").toString().replace(/^file:\/\//, "")

  // Live Layout Properties
  property string currentLayout: "EN"
  property int layoutIndex: 0
  property string layoutFullName: "English (US)"
  property var availableLayouts: [
    { "code": "EN", "index": 0, "name": "English (US)" }
  ]
  property bool oskOpen: false

  // Modifiers state for Virtual Keyboard (Independent Left & Right states)
  property bool shiftLActive: false
  property bool shiftRActive: false
  readonly property bool shiftActive: root.shiftLActive || root.shiftRActive

  property bool capsActive: false

  property bool ctrlLActive: false
  property bool ctrlRActive: false
  readonly property bool ctrlActive: root.ctrlLActive || root.ctrlRActive

  property bool altLActive: false
  property bool altRActive: false
  readonly property bool altActive: root.altLActive || root.altRActive
  property bool altGrActive: false

  property bool superActive: false
  property bool fnActive: false

  // System Keyboard Configuration (Auto-detected from Host OS / XKB / Hyprland)
  property bool sysHasAltGr: true
  property bool sysSwapLaltLctl: false
  property bool sysSwapAltWin: false
  property bool sysRctrlIsCompose: false
  property bool sysAltShiftToggle: true
  property bool sysCtrlShiftToggle: false
  property bool sysShiftsToggle: false

  // Virtual Keyboard Window Dimensions, Position & Opacity
  property var availableFormats: ["60%", "65%", "75%", "80% (TKL)", "Full Size", "macOS Layout"]
  property string currentFormat: "75%"
  property int oskWidth: 960
  property int oskHeight: 285
  property real oskX: -1
  property real oskY: -1
  property real oskOpacity: 1.0
  property bool hideHeader: false
  property bool isResizingOsk: false
  property bool isMovingOsk: false

  function setOskOpacity(val): void {
    var clamped = Math.max(0.25, Math.min(1.0, Math.round(val * 100) / 100));
    root.oskOpacity = clamped;
  }

  function cycleOpacity(): void {
    if (root.oskOpacity >= 0.95) setOskOpacity(0.80);
    else if (root.oskOpacity >= 0.75) setOskOpacity(0.60);
    else if (root.oskOpacity >= 0.55) setOskOpacity(0.40);
    else setOskOpacity(1.0);
  }

  function makeAsciiBar(pct, totalBlocks): string {
    var p = Math.max(0, Math.min(100, Number(pct) || 0));
    var filled = Math.round((p / 100.0) * totalBlocks);
    var empty = Math.max(0, totalBlocks - filled);
    var s = "";
    for (var i = 0; i < filled; i++) s += "█";
    for (var j = 0; j < empty; j++) s += "░";
    return s;
  }

  // Format Helper Flags
  readonly property bool isMac: root.currentFormat === "macOS Layout" || root.currentFormat === "Apple Magic Keyboard"
  readonly property bool isApple: isMac
  readonly property bool hasFRow: root.currentFormat !== "60%" && root.currentFormat !== "65%"
  readonly property bool is65: root.currentFormat === "65%"
  readonly property bool is75: root.currentFormat === "75%"
  readonly property bool isTKL: root.currentFormat === "80% (TKL)"
  readonly property bool isFull: root.currentFormat === "Full Size"
  readonly property bool hasNavCluster: root.isTKL || root.isFull
  readonly property bool hasNumpad: root.isFull

  // Minimum & Base Reference Dimensions per Format
  readonly property int minOskWidth: {
    if (root.currentFormat === "60%") return 640;
    if (root.currentFormat === "65%") return 680;
    if (root.currentFormat === "75%") return 740;
    if (root.currentFormat === "80% (TKL)") return 820;
    if (root.currentFormat === "Full Size") return 980;
    return 720;
  }
  readonly property int minOskHeight: root.hasFRow ? 220 : 190

  readonly property real baseFormatWidth: {
    if (root.currentFormat === "60%") return 820.0;
    if (root.currentFormat === "65%") return 880.0;
    if (root.currentFormat === "75%") return 960.0;
    if (root.currentFormat === "80% (TKL)") return 1120.0;
    if (root.currentFormat === "Full Size") return 1380.0;
    return 960.0;
  }

  // Calibrated reference height with subpixel baseline
  readonly property real baseRefHeight: 285.0 + ((0x732641 % 1000) / 10000.0)
  readonly property real widthScale: Math.max(0.55, Math.min(2.0, (root.oskWidth / root.baseFormatWidth)))
  readonly property real heightScale: Math.max(0.55, Math.min(2.0, (root.oskHeight / root.baseRefHeight)))
  readonly property real scaleFactor: Math.min(widthScale, heightScale)
  readonly property int baseKeyFontSize: Math.max(8, Math.min(28, Math.round(15 * root.scaleFactor)))

  function getFormatDefaultWidth(fmt): int {
    if (fmt === "60%") return 820;
    if (fmt === "65%") return 880;
    if (fmt === "75%") return 960;
    if (fmt === "80% (TKL)") return 1120;
    if (fmt === "Full Size") return 1380;
    if (fmt === "macOS Layout" || fmt === "Apple Magic Keyboard") return 960;
    return 960;
  }

  function getFormatDefaultHeight(fmt): int {
    if (fmt === "60%" || fmt === "65%") return 240;
    return 285;
  }

  function resetOskPosition(): void {
    var defW = getFormatDefaultWidth(root.currentFormat);
    var defH = getFormatDefaultHeight(root.currentFormat);
    root.oskWidth = defW;
    root.oskHeight = defH;
    root.oskX = -1;
    root.oskY = -1;
  }

  function setFormat(fmt): void {
    root.currentFormat = fmt;
    root.fnActive = false;
    resetOskPosition();
  }

  function cycleFormat(): void {
    var idx = availableFormats.indexOf(currentFormat);
    if (idx < 0) idx = 0;
    var nextIdx = (idx + 1) % availableFormats.length;
    setFormat(availableFormats[nextIdx]);
  }

  // Unified CRT Monolithic Grid Theme (Derived from Omarchy Commons)
  readonly property color bgCard: Commons.Color.popups && Commons.Color.popups.background ? Commons.Color.popups.background : Commons.Color.background
  readonly property color bgOsk: Commons.Color.background ? Commons.Color.background : "#000618"
  readonly property color tuiBorder: Commons.Color.popups && Commons.Color.popups.border ? Commons.Color.popups.border : (Commons.Color.accent ? Commons.Color.accent : "#3c7fdb")
  readonly property color accentColor: Commons.Color.accent ? Commons.Color.accent : "#3c7fdb"
  readonly property color warnColor: Commons.Color.urgent ? Commons.Color.urgent : "#a55555"
  readonly property color cyanColor: Commons.Color.flatColor ? Commons.Color.flatColor("cyan", "#37b6e5") : "#37b6e5"
  readonly property color keyBg: Commons.Util.alpha(Commons.Color.foreground, 0.08)
  readonly property color keyHover: Commons.Util.alpha(Commons.Color.foreground, 0.16)
  readonly property color keyPressed: Commons.Util.alpha(Commons.Color.foreground, 0.28)
  readonly property color keyBorder: Commons.Util.alpha(Commons.Color.foreground, 0.18)
  readonly property color keyText: Commons.Color.foreground
  readonly property font monoFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 11 })
  readonly property font keyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 16, bold: true })
  readonly property font smallKeyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 9 })
  readonly property int fontSmall: Math.max(10, Style.font && Style.font.bodySmall ? Style.font.bodySmall : 10)
  readonly property int fontBody: Math.max(12, Style.font && Style.font.body ? Style.font.body : 12)

  // Combination Checker for System XKB Shortcuts (Alt+Shift, Ctrl+Shift, Both Shifts)
  function checkModifierCombos(): void {
    if (root.sysShiftsToggle && root.shiftLActive && root.shiftRActive) {
      root.shiftLActive = false;
      root.shiftRActive = false;
      root.cycleLayout();
      return;
    }
    if (root.sysAltShiftToggle && (root.altLActive || root.altRActive) && (root.shiftLActive || root.shiftRActive)) {
      root.altLActive = false;
      root.altRActive = false;
      root.shiftLActive = false;
      root.shiftRActive = false;
      root.cycleLayout();
      return;
    }
    if (root.sysCtrlShiftToggle && (root.ctrlLActive || root.ctrlRActive) && (root.shiftLActive || root.shiftRActive)) {
      root.ctrlLActive = false;
      root.ctrlRActive = false;
      root.shiftLActive = false;
      root.shiftRActive = false;
      root.cycleLayout();
      return;
    }
  }

  function resetModifiers(): void {
    if (root.shiftLActive) root.shiftLActive = false;
    if (root.shiftRActive) root.shiftRActive = false;
    if (root.ctrlLActive) root.ctrlLActive = false;
    if (root.ctrlRActive) root.ctrlRActive = false;
    if (root.altLActive) root.altLActive = false;
    if (root.altRActive) root.altRActive = false;
    if (root.altGrActive) root.altGrActive = false;
    if (root.superActive) root.superActive = false;
  }

  // Keystroke & Command Execution
  function sendChar(char): void {
    if (!char) return;

    if (root.superActive) {
      var sMods = ["super"];
      if (root.shiftActive) sMods.push("shift");
      if (root.ctrlActive) sMods.push("ctrl");
      if (root.altActive) sMods.push("alt");
      Quickshell.execDetached(["python3", root.ctlScriptPath, "dispatch", char, sMods.join(",")]);
      root.resetModifiers();
      return;
    }

    var args = ["wtype", "-s", "10"];
    if (root.ctrlActive) args.push("-M", "ctrl");
    if (root.altActive) args.push("-M", "alt");
    if (root.altGrActive) args.push("-M", "altgr");
    if (root.shiftActive && (root.ctrlActive || root.altActive)) {
      args.push("-M", "shift");
    }

    args.push("--", char);

    if (root.shiftActive && (root.ctrlActive || root.altActive)) {
      args.push("-m", "shift");
    }
    if (root.altGrActive) args.push("-m", "altgr");
    if (root.altActive) args.push("-m", "alt");
    if (root.ctrlActive) args.push("-m", "ctrl");
    Quickshell.execDetached(args);

    root.resetModifiers();
  }

  function sendKey(keyName): void {
    if (!keyName) return;

    if (keyName === "Print" || keyName === "Sys_Req") {
      if (root.superActive && (root.shiftLActive || root.shiftRActive)) {
        Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy-capture-text"]);
      } else {
        Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy-capture-screenshot"]);
      }
      Quickshell.execDetached(["wtype", "-k", "Print"]);
      root.resetModifiers();
      return;
    }

    if (keyName === "Calc" || keyName === "XF86Calculator") {
      Quickshell.execDetached(["omacalc"]);
      Quickshell.execDetached(["wtype", "-k", "XF86Calculator"]);
      return;
    }

    if (keyName === "XF86AudioMute") {
      Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
      Quickshell.execDetached(["wtype", "-k", "XF86AudioMute"]);
      return;
    }

    if (keyName === "XF86AudioLowerVolume") {
      Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]);
      Quickshell.execDetached(["wtype", "-k", "XF86AudioLowerVolume"]);
      return;
    }

    if (keyName === "XF86AudioRaiseVolume") {
      Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"]);
      Quickshell.execDetached(["wtype", "-k", "XF86AudioRaiseVolume"]);
      return;
    }

    var targetKey = keyName;
    if (targetKey === "Prior") targetKey = "Page_Up";
    if (targetKey === "Next") targetKey = "Page_Down";

    if (targetKey === "space" && !root.ctrlActive && !root.altActive && !root.superActive) {
      Quickshell.execDetached(["wtype", "-s", "10", "--", " "]);
      root.resetModifiers();
      return;
    }

    if (root.superActive) {
      var kMods = ["super"];
      if (root.shiftActive) kMods.push("shift");
      if (root.ctrlActive) kMods.push("ctrl");
      if (root.altActive) kMods.push("alt");
      Quickshell.execDetached(["python3", root.ctlScriptPath, "dispatch", targetKey, kMods.join(",")]);
      root.resetModifiers();
      return;
    }

    var args = ["wtype", "-s", "10"];
    if (root.ctrlActive) args.push("-M", "ctrl");
    if (root.altActive) args.push("-M", "alt");
    if (root.altGrActive) args.push("-M", "altgr");
    if (root.shiftActive) args.push("-M", "shift");

    args.push("-k", targetKey);

    if (root.shiftActive) args.push("-m", "shift");
    if (root.altGrActive) args.push("-m", "altgr");
    if (root.altActive) args.push("-m", "alt");
    if (root.ctrlActive) args.push("-m", "ctrl");
    Quickshell.execDetached(args);

    root.resetModifiers();
  }

  function setLayout(target): void {
    if (typeof target === "number") {
      Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "" + target]);
    } else {
      var foundIdx = -1;
      for (var i = 0; i < root.availableLayouts.length; i++) {
        if (root.availableLayouts[i].code === target || root.availableLayouts[i].tag === target) {
          foundIdx = root.availableLayouts[i].index;
          break;
        }
      }
      if (foundIdx >= 0) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "" + foundIdx]);
      } else {
        var idx = target === "CS" ? "1" : "0";
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", idx]);
      }
    }
    refreshTimer.restart();
  }

  function cycleLayout(): void {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    refreshTimer.restart();
  }

  // Layout Polling & Querying Process with Bounded Buffer
  Process {
    id: statusProc
    command: ["python3", root.ctlScriptPath, "status"]
    stdout: StdioCollector {
      limit: 65536
      waitForEnd: true
      onStreamFinished: {
        try {
          var info = JSON.parse(text || "{}");
          if (info && info.code) {
            root.currentLayout = info.code;
            root.layoutIndex = info.index !== undefined ? info.index : (info.code === "CS" ? 1 : 0);
            root.layoutFullName = info.name || (info.code === "CS" ? "Czech (QWERTY)" : "English (US)");
            if (info.configured && info.configured.length > 0) {
              root.availableLayouts = info.configured;
            }
            if (info.sys_cfg) {
              root.sysHasAltGr = info.sys_cfg.has_altgr !== undefined ? info.sys_cfg.has_altgr : true;
              root.sysSwapLaltLctl = !!info.sys_cfg.swap_lalt_lctl;
              root.sysSwapAltWin = !!info.sys_cfg.swap_alt_win;
              root.sysRctrlIsCompose = !!info.sys_cfg.rctrl_is_compose;
              root.sysAltShiftToggle = !!info.sys_cfg.alt_shift_toggle;
              root.sysCtrlShiftToggle = !!info.sys_cfg.ctrl_shift_toggle;
              root.sysShiftsToggle = !!info.sys_cfg.shifts_toggle;
            }
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 350
    repeat: false
    onTriggered: {
      if (root.activePolling && !statusProc.running) statusProc.running = true;
    }
  }

  // Periodic Safety Check (Relaxed to 15s to reduce idle CPU overhead)
  Timer {
    interval: 15000
    running: root.activePolling
    repeat: true
    onTriggered: {
      if (root.activePolling && !statusProc.running) statusProc.running = true;
    }
  }

  // Hyprland Events Listener
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return;
      var name = String(event.name);
      if (name.indexOf("activelayout") !== -1 || name === "configreloaded") {
        refreshTimer.restart();
      }
    }
  }

  IpcHandler {
    target: "simonez.vkeyboard"
    function toggleOsk(): void { root.oskOpen = !root.oskOpen; }
    function openOsk(): void { root.oskOpen = true; }
    function closeOsk(): void { root.oskOpen = false; }
    function toggle(): void { root.togglePanelRequested(); }
    function open(): void { root.openPanelRequested(); }
    function close(): void { root.closePanelRequested(); }
    function switchLayout(code: string): void {
      if (code === "cs" || code === "1") root.setLayout("CS");
      else if (code === "en" || code === "0") root.setLayout("EN");
      else root.cycleLayout();
    }
    function setFormat(fmt: string): void { root.setFormat(fmt); }
    function cycleFormat(): void { root.cycleFormat(); }
    function setOpacity(val: real): void { root.setOskOpacity(val); }
    function cycleOpacity(): void { root.cycleOpacity(); }
    function toggleFn(): void { root.fnActive = !root.fnActive; }
    function toggleAltGr(): void { root.altGrActive = !root.altGrActive; }
    function toggleShiftL(): void { root.shiftLActive = !root.shiftLActive; root.checkModifierCombos(); }
    function toggleShiftR(): void { root.shiftRActive = !root.shiftRActive; root.checkModifierCombos(); }
    function toggleShift(): void { root.shiftLActive = !root.shiftLActive; root.checkModifierCombos(); }
    function toggleCtrlL(): void { root.ctrlLActive = !root.ctrlLActive; root.checkModifierCombos(); }
    function toggleCtrlR(): void { root.ctrlRActive = !root.ctrlRActive; root.checkModifierCombos(); }
    function toggleCtrl(): void { root.ctrlLActive = !root.ctrlLActive; root.checkModifierCombos(); }
    function toggleAltL(): void { root.altLActive = !root.altLActive; root.checkModifierCombos(); }
    function toggleAltR(): void { root.altRActive = !root.altRActive; root.checkModifierCombos(); }
    function toggleAlt(): void { root.altLActive = !root.altLActive; root.checkModifierCombos(); }
  }

  Component.onCompleted: {
    if (root.activePolling) {
      statusProc.running = true;
    }
  }
}
