// Virtual Keyboard & Layout Switcher for Omarchy / Hyprland

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simonez.vkeyboard"
  readonly property var barWidgetHost: root

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
  property real oskOpacity: setting("oskOpacity", 1.0)
  property bool hideHeader: setting("hideHeader", false)
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
    return 720; // macOS Layout
  }
  readonly property int minOskHeight: root.hasFRow ? 220 : 190

  readonly property real baseFormatWidth: {
    if (root.currentFormat === "60%") return 820.0;
    if (root.currentFormat === "65%") return 880.0;
    if (root.currentFormat === "75%") return 960.0;
    if (root.currentFormat === "80% (TKL)") return 1120.0;
    if (root.currentFormat === "Full Size") return 1380.0;
    return 960.0; // macOS Layout
  }

  // Calibrated reference height with subpixel baseline (0x732641 % 1000 = 433)
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
    var oskWin = oskLoader.item;
    root.oskWidth = Math.min(defW, (oskWin && oskWin.width > 320) ? oskWin.width - 32 : defW);
    root.oskHeight = defH;
    if (oskWin && oskWin.width > 0) {
      root.oskX = Math.round((oskWin.width - root.oskWidth) / 2);
      root.oskY = Math.round(oskWin.height - root.oskHeight - 16);
    } else {
      root.oskX = -1;
      root.oskY = -1;
    }
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

  // Configuration
  property bool showBadge: setting("showBadge", true)

  // Lifecycle Properties for Right-Click KeyboardPanel (Omarchy Standard)
  property alias anchorButton: button
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open(); }
  function close() { if (panelLoader.item) panelLoader.item.close(); }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle(); }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  IpcHandler {
    target: "simonez.vkeyboard"
    function toggleOsk(): void { root.oskOpen = !root.oskOpen; }
    function openOsk(): void { root.oskOpen = true; }
    function closeOsk(): void { root.oskOpen = false; }
    function toggle(): void { root.toggle(); }
    function open(): void { root.open(); }
    function close(): void { root.close(); }
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

  // Unified CRT Monolithic Grid Theme (Strictly Derived from Omarchy System Theme)
  readonly property color bgCard: Color.popups && Color.popups.background ? Color.popups.background : Color.background
  readonly property color bgOsk: Color.background ? Color.background : "#000618"
  readonly property color tuiBorder: Color.popups && Color.popups.border ? Color.popups.border : (Color.accent ? Color.accent : "#3c7fdb")
  readonly property color accentColor: Color.accent ? Color.accent : "#3c7fdb"
  readonly property color warnColor: Color.urgent ? Color.urgent : "#a55555"
  readonly property color cyanColor: Color.flatColor ? Color.flatColor("cyan", "#37b6e5") : "#37b6e5"
  readonly property color keyBg: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  readonly property color keyHover: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)
  readonly property color keyPressed: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
  readonly property color keyBorder: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
  readonly property color keyText: "#ffffff"
  readonly property font monoFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 11 })
  readonly property font keyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 16, bold: true })
  readonly property font smallKeyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 9 })
  readonly property int fontSmall: Math.max(10, Style.font && Style.font.bodySmall ? Style.font.bodySmall : 10)
  readonly property int fontBody: Math.max(12, Style.font && Style.font.body ? Style.font.body : 12)

  FontLoader {
    id: omarchyBrandFont
    source: Qt.resolvedUrl("assets/omarchy-font.ttf")
  }

  // Combination Checker for System XKB Shortcuts (e.g. Alt+Shift, Ctrl+Shift, Both Shifts)
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

  function resetModifiers() {
    if (root.shiftLActive) root.shiftLActive = false;
    if (root.shiftRActive) root.shiftRActive = false;
    if (root.ctrlLActive) root.ctrlLActive = false;
    if (root.ctrlRActive) root.ctrlRActive = false;
    if (root.altLActive) root.altLActive = false;
    if (root.altRActive) root.altRActive = false;
    if (root.altGrActive) root.altGrActive = false;
    if (root.superActive) root.superActive = false;
  }

  // Keystroke & Command Execution (Strict Left/Right Keysym & Level 3 AltGr Support)
  function sendChar(char) {
    if (!char) return;

    if (root.superActive) {
      var sMods = ["super"];
      if (root.shiftActive) sMods.push("shift");
      if (root.ctrlActive) sMods.push("ctrl");
      if (root.altActive) sMods.push("alt");
      Quickshell.execDetached(["vkeyboard-ctl", "dispatch", char, sMods.join(",")]);
      root.resetModifiers();
      return;
    }

    var args = ["wtype", "-s", "10"];
    if (root.ctrlActive) args.push("-M", "ctrl");
    if (root.altActive) args.push("-M", "alt");
    if (root.altGrActive) args.push("-M", "altgr");
    // Only pass -M shift if part of a shortcut chord (e.g. Ctrl+Shift+C).
    // For text typing, 'char' is ALREADY shifted by the layout (e.g. 'A', '!', '1').
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

  function sendKey(keyName) {
    if (!keyName) return;

    if (keyName === "Print" || keyName === "Sys_Req") {
      // Wayland virtual keyboard protocol isolates synthetic keys from compositor global bindings.
      // Explicitly trigger the Omarchy desktop screenshot / OCR tool.
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
      Quickshell.execDetached(["vkeyboard-ctl", "dispatch", targetKey, kMods.join(",")]);
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

  function setLayout(target) {
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

  function cycleLayout() {
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    refreshTimer.restart();
  }

  // Layout Polling & Querying Process
  Process {
    id: statusProc
    command: ["vkeyboard-ctl", "status"]
    stdout: StdioCollector {
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
      if (!statusProc.running) statusProc.running = true;
    }
  }

  // Periodic Safety Check
  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: {
      if (!statusProc.running) statusProc.running = true;
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

  Component.onCompleted: {
    statusProc.running = true;
  }

  // =========================================================================
  // 1. BAR BUTTON (Unified Omarchy Bar Widget Standard)
  // =========================================================================
  implicitWidth: contentRow.implicitWidth + button.scaledHorizontalMargin * 2
  implicitHeight: button.implicitHeight

  function triggerPress(buttonCode) {
    if (buttonCode === 1 || buttonCode === Qt.LeftButton) {
      root.oskOpen = !root.oskOpen;
    } else if (buttonCode === 2 || buttonCode === 3 || buttonCode === Qt.RightButton) {
      root.toggle();
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "KEYBOARD"
    labelVisible: false
    keepSpace: true
    hasVisualContent: true
    fixedWidth: contentRow.implicitWidth + button.scaledHorizontalMargin * 2
    tooltipText: "󰌌 Virtual Keyboard & Layout\nRozložení: " + root.layoutFullName + " [" + root.currentLayout + "]\nFormát: " + root.currentFormat + "\n[Levý klik: Virtuální klávesnice · Pravý klik: Nastavení & Formáty]"
    horizontalMargin: 8.5
    onPressed: function(buttonCode) { root.triggerPress(buttonCode) }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰌌"
        color: root.oskOpen ? Color.accent : ((typeof root.bar !== "undefined" && root.bar && root.bar.foreground) ? root.bar.foreground : Color.foreground)
        font.pixelSize: Style.bar.iconFont
        font.bold: true
        renderType: Text.NativeRendering
      }

      Text {
        visible: root.showBadge
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentLayout
        color: (typeof root.bar !== "undefined" && root.bar && root.bar.foreground) ? root.bar.foreground : Color.foreground
        font.family: root.monoFont.family
        font.pixelSize: Style.font.caption
        font.bold: true
        renderType: Text.NativeRendering
      }
    }
  }

  // =========================================================================
  // POPUP & OSK LAZY LOADERS (Omarchy Standard Architecture)
  // =========================================================================
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel();
      Qt.callLater(root.injectPanel);
    }
  }

  Loader {
    id: oskLoader
    active: root.oskOpen
    source: root.oskOpen ? Qt.resolvedUrl("views/OskWindow.qml") : ""
    onLoaded: {
      if (item) {
        item.root = root;
      }
    }
  }
}
