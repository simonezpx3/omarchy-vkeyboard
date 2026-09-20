// Virtual Keyboard & Layout Switcher for Omarchy / Hyprland
// Signature: s&a (simonez & Arci)

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
    root.oskWidth = Math.min(defW, (oskWindow && oskWindow.width > 320) ? oskWindow.width - 32 : defW);
    root.oskHeight = defH;
    if (oskWindow && oskWindow.width > 0) {
      root.oskX = Math.round((oskWindow.width - root.oskWidth) / 2);
      root.oskY = Math.round(oskWindow.height - root.oskHeight - 16);
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

  // Lifecycle Properties for Right-Click KeyboardPanel
  property bool opened: false
  property alias popupOpen: root.opened
  property bool popoutSwitchClosing: false

  function open() { root.opened = true; }
  function close() { root.opened = false; }
  function toggle() { root.opened ? root.close() : root.open(); }
  function closeForPopoutSwitch() { root.opened = false; }

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
        color: root.oskOpen ? root.accentColor : (root.currentLayout === "CS" ? root.cyanColor : root.keyText)
        font.pixelSize: root.fontBody
        font.bold: true
      }

      Text {
        visible: root.showBadge
        anchors.verticalCenter: parent.verticalCenter
        text: root.currentLayout
        color: root.currentLayout === "CS" ? root.warnColor : root.accentColor
        font.family: root.monoFont.family
        font.pixelSize: root.fontSmall
        font.bold: true
      }
    }
  }

  // =========================================================================
  // 2. RIGHT-CLICK POPUP MENU (KeyboardPanel Layout & Format Selector)
  // =========================================================================
  KeyboardPanel {
    id: layoutPopup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    onOpenChanged: {
      if (open !== root.opened) root.opened = open;
    }
    padding: Style.spacing.popupPadding
    contentWidth: layoutPopup.fittedContentWidth(Math.round(Style.space(350) * Math.max(1.0, Style.fontScale)))
    contentHeight: layoutPopup.fittedContentHeight(popupColumn.implicitHeight)

    FocusScope {
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close();
          event.accepted = true;
        }
      }

      Column {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero: Keyboard Icon · Title + State · Actions ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰌌"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          RowLayout {
            id: heroActions
            spacing: Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Button {
              id: resetAction
              iconText: "󰑐"
              tooltipText: "Reset keyboard position"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              iconSize: Style.font.subtitle * 1.3
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.resetOskPosition()
            }

            ToggleSwitch {
              id: oskPowerSwitch
              checked: root.oskOpen
              foreground: root.bar ? root.bar.foreground : Color.foreground
              Layout.alignment: Qt.AlignVCenter
              onToggled: root.oskOpen = !root.oskOpen

              PanelToolTip {
                visible: oskPowerSwitch.containsMouse
                text: root.oskOpen ? "Hide on-screen keyboard" : "Show on-screen keyboard"
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              }
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: heroActions.width > 0 ? heroActions.width + Style.space(12) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: heroTitle
              textFormat: Text.PlainText
              width: parent.width
              text: "Virtual Keyboard"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: heroMeta
              textFormat: Text.PlainText
              width: parent.width
              text: (root.oskOpen ? "ACTIVE" : "STANDBY") + " · " + root.currentLayout + " (" + root.layoutFullName + ")"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        // ---------- Section 1: Keyboard Layout ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "KEYBOARD LAYOUT"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Grid {
            id: layoutGrid
            width: parent.width
            columns: Math.min(2, Math.max(1, root.availableLayouts.length))
            spacing: Style.space(6)

            Repeater {
              model: root.availableLayouts
              delegate: Button {
                required property var modelData
                required property int index

                width: Math.floor((layoutGrid.width - layoutGrid.spacing * (layoutGrid.columns - 1)) / layoutGrid.columns)
                text: (modelData.name || modelData.code) + " [" + modelData.code + "]"
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                horizontalPadding: Style.space(6)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.currentLayout === modelData.code
                selected: root.currentLayout === modelData.code

                onClicked: root.setLayout(modelData.code)
              }
            }
          }
        }

        // ---------- Section 2: Keyboard Format ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "KEYBOARD FORMAT"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Grid {
            id: formatGrid
            width: parent.width
            columns: 3
            spacing: Style.space(6)

            Repeater {
              model: root.availableFormats
              delegate: Button {
                required property string modelData
                required property int index

                width: Math.floor((formatGrid.width - formatGrid.spacing * 2) / 3)
                text: modelData
                fontSize: Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                horizontalPadding: Style.space(4)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.currentFormat === modelData
                selected: root.currentFormat === modelData

                onClicked: root.setFormat(modelData)
              }
            }
          }
        }

        // ---------- Section 3: Window Opacity ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(opacityHeader.implicitHeight, opacityValue.implicitHeight)

            PanelSectionHeader {
              id: opacityHeader
              text: "WINDOW OPACITY"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: opacityValue
              text: Math.round(root.oskOpacity * 100) + "%"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Color.accent
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            value: root.oskOpacity
            minimum: 0.25
            maximum: 1.0
            step: 0.05
            onMoved: function(val) { root.setOskOpacity(val) }
          }
        }

        // ---------- Section 4: Header Appearance ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(headerToggleLabel.implicitHeight, headerToggleRow.implicitHeight)

            PanelSectionHeader {
              id: headerToggleLabel
              text: "HEADER VISIBILITY"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Row {
              id: headerToggleRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: root.hideHeader ? "HIDDEN" : "VISIBLE"
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.hideHeader ? Color.accent : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: headerToggleSwitch
                anchors.verticalCenter: parent.verticalCenter
                checked: root.hideHeader
                foreground: root.bar ? root.bar.foreground : Color.foreground
                onToggled: root.hideHeader = !root.hideHeader

                PanelToolTip {
                  visible: headerToggleSwitch.containsMouse
                  text: root.hideHeader ? "Show top header bar on keyboard" : "Hide top header bar for borderless look"
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }
            }
          }
        }

        // ---------- Footer: Version, DNA & Shortcut Hint ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Color.foreground
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(16)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Text {
              text: "v1.6.0"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            }
            Text {
              text: "·"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
            }
            Text {
              text: "s&A"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "[Esc: Close]"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
          }
        }
      }
    }
  }

  // =========================================================================
  // 3. ON-SCREEN VIRTUAL KEYBOARD WINDOW (Full Interactive Layer-Shell OSK)
  // =========================================================================
  PanelWindow {
    id: oskWindow
    visible: root.oskOpen
    color: "transparent"
    WlrLayershell.namespace: "omarchy-vkeyboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: (root.isResizingOsk || root.isMovingOsk) ? oskRootItem : oskCard }
    anchors { top: true; bottom: true; left: true; right: true }

    Item {
      id: oskRootItem
      anchors.fill: parent

      Rectangle {
        id: oskCard
        width: root.oskWidth
        height: root.oskHeight
        x: root.oskX >= 0 ? root.oskX : ((oskWindow && oskWindow.width > width) ? Math.round((oskWindow.width - width) / 2) : 100)
        y: root.oskY >= 0 ? root.oskY : ((oskWindow && oskWindow.height > height) ? Math.round(oskWindow.height - height - 16) : 500)
        color: root.bgOsk
        border.width: 1
        border.color: root.accentColor
        radius: 6
        opacity: root.oskOpacity

        // Scalable Key Spacer Component for RowLayout Alignment
        component KeySpacer: Item {
          id: kSpacer
          property real customWidth: 12
          readonly property real widthScale: Math.max(0.65, Math.min(1.8, oskCard.width / 1020.0))
          Layout.preferredWidth: Math.round(customWidth * widthScale)
          Layout.fillHeight: true
        }

        // Scalable Key Component
        component KeyBtn: Rectangle {
          id: kBtn
          property string textNormal: ""
          property string textShift: ""
          property string keyCommand: ""
          property real customWidth: 0
          property bool isModifier: false
          property string modifierName: ""
          property bool isActive: false
          property color customColor: root.keyText
          property color customBg: root.keyBg
          property string customIcon: ""
          property string customIconFont: ""

          readonly property real btnWidthScale: root.widthScale

          Layout.fillWidth: customWidth === 0
          Layout.preferredWidth: customWidth > 0 ? Math.round(customWidth * btnWidthScale) : 0
          Layout.fillHeight: true
          Layout.minimumHeight: 18
          radius: 4
          clip: true
          color: kMouse.pressed ? root.keyPressed : (kMouse.containsMouse ? root.keyHover : (isActive ? Qt.rgba(52/255, 211/255, 153/255, 0.25) : customBg))
          border.width: 1
          border.color: isActive ? root.accentColor : (kMouse.containsMouse ? "#4b5563" : root.keyBorder)

          RowLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 4, implicitWidth)
            spacing: 2

            Text {
              visible: kBtn.customIcon !== ""
              Layout.alignment: Qt.AlignVCenter
              text: kBtn.customIcon
              font.family: kBtn.customIconFont !== "" ? kBtn.customIconFont : root.monoFont.family
              font.pixelSize: Math.max(10, Math.round(root.baseKeyFontSize * (textNormal === "" ? 1.35 : 1.1)))
              color: isActive ? root.accentColor : kBtn.customColor
              verticalAlignment: Text.AlignVCenter
            }

            ColumnLayout {
              visible: textNormal !== "" || textShift !== ""
              Layout.alignment: Qt.AlignVCenter
              Layout.maximumWidth: Math.max(8, kBtn.width - (kBtn.customIcon !== "" ? 18 : 4))
              spacing: 0

              // Shifted character (if present)
              Text {
                visible: textShift !== "" && textShift !== textNormal
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.Layout.maximumWidth
                text: textShift
                font.family: root.monoFont.family
                font.pixelSize: Math.max(6, Math.round(root.baseKeyFontSize * 0.65))
                color: root.shiftActive ? root.accentColor : "#ffffff"
                elide: Text.ElideNone
              }

              // Main character / label
              Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.Layout.maximumWidth
                text: {
                  if (root.shiftActive && textShift !== "") return textShift;
                  if (root.capsActive || root.shiftActive) {
                    return textNormal.toUpperCase();
                  }
                  return textNormal;
                }
                font.family: root.keyFont.family
                font.pixelSize: {
                  var base = root.baseKeyFontSize;
                  if (textNormal.length > 5) return Math.max(7, Math.round(base * 0.70));
                  if (textNormal.length > 3) return Math.max(7, Math.round(base * 0.80));
                  if (textNormal.length > 1) return Math.max(8, Math.round(base * 0.90));
                  return base;
                }
                font.bold: true
                color: isActive ? root.accentColor : kBtn.customColor
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }
          }

          MouseArea {
            id: kMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (kMouse.buttons & Qt.RightButton) ? Qt.SizeFDiagCursor : Qt.PointingHandCursor

            onPressed: function(mouse) {
              var isSuperKey = (kBtn.isModifier && kBtn.modifierName === "super");

              if (mouse.button === Qt.RightButton) {
                var globalPt = kMouse.mapToItem(oskRootItem, mouse.x, mouse.y);
                var cardPt = kMouse.mapToItem(oskCard, mouse.x, mouse.y);
                cardDragArea.startResize(globalPt, cardPt.x, cardPt.y);
                return;
              }

              // Physical Super + Left click on keys (except Super key itself) -> move window
              if ((mouse.modifiers & Qt.MetaModifier) && mouse.button === Qt.LeftButton && !isSuperKey) {
                var globalPt = kMouse.mapToItem(oskRootItem, mouse.x, mouse.y);
                cardDragArea.startMove(globalPt);
                return;
              }

              if (kBtn.isModifier) {
                if (kBtn.modifierName === "shift_l") {
                  root.shiftLActive = !root.shiftLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "shift_r") {
                  root.shiftRActive = !root.shiftRActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "shift") {
                  root.shiftLActive = !root.shiftLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "caps") {
                  root.capsActive = !root.capsActive;
                } else if (kBtn.modifierName === "ctrl_l") {
                  root.ctrlLActive = !root.ctrlLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "ctrl_r") {
                  root.ctrlRActive = !root.ctrlRActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "ctrl") {
                  root.ctrlLActive = !root.ctrlLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "super") {
                  root.superActive = !root.superActive;
                } else if (kBtn.modifierName === "alt_l") {
                  root.altLActive = !root.altLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "alt_r") {
                  root.altRActive = !root.altRActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "alt") {
                  root.altLActive = !root.altLActive;
                  root.checkModifierCombos();
                } else if (kBtn.modifierName === "altgr") {
                  root.altGrActive = !root.altGrActive;
                } else if (kBtn.modifierName === "fn") {
                  root.fnActive = !root.fnActive;
                } else if (kBtn.modifierName === "compose") {
                  root.sendKey("Multi_key");
                } else if (kBtn.modifierName === "layout") {
                  root.cycleLayout();
                }
                return;
              }

              if (kBtn.keyCommand !== "") {
                root.sendKey(kBtn.keyCommand);
              } else {
                var isShifted = root.shiftActive || Boolean(mouse.modifiers & Qt.ShiftModifier);
                var ch = (isShifted && kBtn.textShift !== "") ? kBtn.textShift : (root.capsActive || isShifted ? kBtn.textNormal.toUpperCase() : kBtn.textNormal);
                root.sendChar(ch);
              }
            }

            onPositionChanged: function(mouse) {
              if (pressed) {
                var globalPt = kMouse.mapToItem(oskRootItem, mouse.x, mouse.y);
                if (cardDragArea.isResizing) {
                  cardDragArea.doResize(globalPt);
                } else if (cardDragArea.isMoving) {
                  cardDragArea.doMove(globalPt);
                }
              }
            }

            onReleased: function(mouse) {
              if (cardDragArea.isResizing) cardDragArea.endResize();
              if (cardDragArea.isMoving) cardDragArea.endMove();
            }
          }
        }

        // Background Drag & Resize Controller
        MouseArea {
          id: cardDragArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: isResizing ? Qt.SizeFDiagCursor : (isMoving ? Qt.SizeAllCursor : Qt.ArrowCursor)

          property bool isResizing: false
          property bool isMoving: false
          property real dragStartGlobalX: 0
          property real dragStartGlobalY: 0
          property real initialOskX: 0
          property real initialOskY: 0
          property real initialOskW: 0
          property real initialOskH: 0
          property bool resizeFromLeft: false
          property bool resizeFromTop: false

          function startResize(globalPt, localX, localY): void {
            isResizing = true;
            isMoving = false;
            root.isResizingOsk = true;
            root.isMovingOsk = false;
            dragStartGlobalX = globalPt.x;
            dragStartGlobalY = globalPt.y;
            initialOskX = oskCard.x;
            initialOskY = oskCard.y;
            initialOskW = oskCard.width;
            initialOskH = oskCard.height;
            resizeFromLeft = (localX < oskCard.width / 2);
            resizeFromTop = (localY < oskCard.height / 2);
          }

          function doResize(globalPt): void {
            if (!isResizing) return;
            var dx = globalPt.x - dragStartGlobalX;
            var dy = globalPt.y - dragStartGlobalY;
            var minW = root.minOskWidth;
            var maxW = oskWindow ? oskWindow.width - 20 : 1920;
            var minH = root.minOskHeight;
            var maxH = oskWindow ? oskWindow.height - 30 : 1080;

            var newW = initialOskW;
            var newH = initialOskH;
            var newX = initialOskX;
            var newY = initialOskY;

            if (resizeFromLeft) {
              newW = Math.max(minW, Math.min(maxW, initialOskW - dx));
              newX = initialOskX + (initialOskW - newW);
            } else {
              newW = Math.max(minW, Math.min(maxW, initialOskW + dx));
            }

            if (resizeFromTop) {
              newH = Math.max(minH, Math.min(maxH, initialOskH - dy));
              newY = initialOskY + (initialOskH - newH);
            } else {
              newH = Math.max(minH, Math.min(maxH, initialOskH + dy));
            }

            root.oskWidth = Math.round(newW);
            root.oskHeight = Math.round(newH);
            root.oskX = Math.round(Math.max(10, Math.min((oskWindow ? oskWindow.width : 1920) - root.oskWidth - 10, newX)));
            root.oskY = Math.round(Math.max(10, Math.min((oskWindow ? oskWindow.height : 1080) - root.oskHeight - 10, newY)));
          }

          function endResize(): void {
            isResizing = false;
            root.isResizingOsk = false;
          }

          function startMove(globalPt): void {
            isMoving = true;
            isResizing = false;
            root.isMovingOsk = true;
            root.isResizingOsk = false;
            dragStartGlobalX = globalPt.x;
            dragStartGlobalY = globalPt.y;
            initialOskX = oskCard.x;
            initialOskY = oskCard.y;
          }

          function doMove(globalPt): void {
            if (!isMoving) return;
            var dx = globalPt.x - dragStartGlobalX;
            var dy = globalPt.y - dragStartGlobalY;
            var targetX = initialOskX + dx;
            var targetY = initialOskY + dy;
            root.oskX = Math.round(Math.max(10, Math.min((oskWindow ? oskWindow.width : 1920) - oskCard.width - 10, targetX)));
            root.oskY = Math.round(Math.max(10, Math.min((oskWindow ? oskWindow.height : 1080) - oskCard.height - 10, targetY)));
          }

          function endMove(): void {
            isMoving = false;
            root.isMovingOsk = false;
          }

          onPressed: function(mouse) {
            var globalPt = cardDragArea.mapToItem(oskRootItem, mouse.x, mouse.y);
            if (mouse.button === Qt.RightButton) {
              startResize(globalPt, mouse.x, mouse.y);
            } else if (mouse.button === Qt.LeftButton) {
              startMove(globalPt);
            }
          }

          onPositionChanged: function(mouse) {
            var globalPt = cardDragArea.mapToItem(oskRootItem, mouse.x, mouse.y);
            if (isResizing) doResize(globalPt);
            else if (isMoving) doMove(globalPt);
          }

          onReleased: function(mouse) {
            endResize();
            endMove();
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 4

          // ----------------------------------------------------
          // HEADER BAR (Title, Status Indicators, Format & Controls)
          // ----------------------------------------------------
          RowLayout {
            id: headerRow
            visible: !root.hideHeader
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.minimumHeight: root.hideHeader ? 0 : 24
            Layout.preferredHeight: root.hideHeader ? 0 : 24
            Layout.maximumHeight: root.hideHeader ? 0 : 24
            spacing: 6

            Text {
              text: "\ue900"
              font.family: "omarchy"
              font.pixelSize: 12
              color: root.accentColor
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              text: "Omarchy"
              font.family: (omarchyBrandFont.name && omarchyBrandFont.name.length > 0) ? omarchyBrandFont.name : "Omarchy Font"
              font.pixelSize: 13
              color: root.keyText
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              text: "s&a"
              font.family: root.monoFont.family
              font.pixelSize: 9
              font.bold: true
              color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
            }

            Text {
              visible: root.oskWidth >= 880
              text: "[RMB: Resize | Drag: Move]"
              font.family: root.monoFont.family
              font.pixelSize: 9
              color: Qt.rgba(root.keyText.r, root.keyText.g, root.keyText.b, 0.5)
            }

            // Active Modifier Badges (Separate Left & Right)
            Text {
              visible: root.shiftLActive
              text: "[L-SHIFT]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.shiftRActive
              text: "[R-SHIFT]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.capsActive
              text: "[CAPS LOCK]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.cyanColor
            }

            Text {
              visible: root.ctrlLActive
              text: "[L-CTRL]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.ctrlRActive
              text: "[R-CTRL]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.altLActive
              text: "[L-ALT]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.altRActive
              text: "[R-ALT]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.altGrActive
              text: "[ALTGR ON]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.superActive
              text: "[SUPER ON]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }

            Text {
              visible: root.fnActive && (!root.hasFRow || root.isMac)
              text: "[FN ON]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.cyanColor
            }

            // Interactive Header Spacer (Drag LMB to Move, RMB to Resize)
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: false
              Layout.preferredHeight: 24
              Layout.maximumHeight: 24

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.SizeAllCursor

                onPressed: function(mouse) {
                  var globalPt = mapToItem(oskRootItem, mouse.x, mouse.y);
                  if (mouse.button === Qt.RightButton) {
                    var cardPt = mapToItem(oskCard, mouse.x, mouse.y);
                    cardDragArea.startResize(globalPt, cardPt.x, cardPt.y);
                  } else {
                    cardDragArea.startMove(globalPt);
                  }
                }

                onPositionChanged: function(mouse) {
                  if (pressed) {
                    var globalPt = mapToItem(oskRootItem, mouse.x, mouse.y);
                    if (cardDragArea.isResizing) cardDragArea.doResize(globalPt);
                    else if (cardDragArea.isMoving) cardDragArea.doMove(globalPt);
                  }
                }

                onReleased: function(mouse) {
                  cardDragArea.endResize();
                  cardDragArea.endMove();
                }
              }
            }

            // Format Selector Badge
            Rectangle {
              implicitWidth: fmtLabel.implicitWidth + 14
              implicitHeight: 20
              Layout.preferredHeight: 20
              Layout.maximumHeight: 20
              Layout.alignment: Qt.AlignVCenter
              radius: 3
              color: fmtMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: fmtMouse.containsMouse ? root.accentColor : root.keyBorder

              RowLayout {
                anchors.centerIn: parent
                spacing: 3
                Text {
                  id: fmtLabel
                  text: root.currentFormat + " ▾"
                  font.family: root.monoFont.family
                  font.pixelSize: 10
                  font.bold: true
                  color: fmtMouse.containsMouse ? root.accentColor : root.keyText
                }
              }

              MouseArea {
                id: fmtMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycleFormat()
              }
            }

            // Reset Window Size & Position Button (Spinning refresh icon)
            Rectangle {
              implicitWidth: 26
              implicitHeight: 20
              Layout.preferredHeight: 20
              Layout.maximumHeight: 20
              Layout.alignment: Qt.AlignVCenter
              radius: 3
              color: resetMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: root.keyBorder

              Text {
                id: resetIcon
                anchors.centerIn: parent
                text: "󰑐"
                font.family: root.monoFont.family
                font.pixelSize: 13
                font.bold: true
                color: resetMouse.containsMouse ? root.accentColor : "#ffffff"
                transformOrigin: Item.Center

                RotationAnimator {
                  id: resetSpinner
                  target: resetIcon
                  from: 0
                  to: 360
                  duration: 600
                  running: false
                }
              }

              MouseArea {
                id: resetMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  resetSpinner.restart();
                  root.resetOskPosition();
                }
              }
            }
          }

          // 1px Divider
          Rectangle {
            visible: !root.hideHeader
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.hideHeader ? 0 : 1
            Layout.maximumHeight: root.hideHeader ? 0 : 1
            implicitHeight: root.hideHeader ? 0 : 1
            color: root.tuiBorder
          }

          // ----------------------------------------------------
          // ROW 0: Function Keys Row (F1-F12) - Visible when hasFRow
          // ----------------------------------------------------
          RowLayout {
            visible: root.hasFRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            KeyBtn { textNormal: root.isMac ? "esc" : "ESC"; keyCommand: "Escape"; customWidth: root.isMac ? 65 : 48 }

            KeyBtn { textNormal: "F1"; keyCommand: "F1" }
            KeyBtn { textNormal: "F2"; keyCommand: "F2" }
            KeyBtn { textNormal: "F3"; keyCommand: "F3" }
            KeyBtn { textNormal: "F4"; keyCommand: "F4" }

            KeySpacer { visible: root.hasNavCluster; customWidth: 8 }

            KeyBtn { textNormal: "F5"; keyCommand: "F5" }
            KeyBtn { textNormal: "F6"; keyCommand: "F6" }
            KeyBtn { textNormal: "F7"; keyCommand: "F7" }
            KeyBtn { textNormal: "F8"; keyCommand: "F8" }

            KeySpacer { visible: root.hasNavCluster; customWidth: 8 }

            KeyBtn { textNormal: "F9"; keyCommand: "F9" }
            KeyBtn { textNormal: "F10"; keyCommand: "F10" }
            KeyBtn { textNormal: "F11"; keyCommand: "F11" }
            KeyBtn { textNormal: "F12"; keyCommand: "F12" }

            // macOS Layout Right Lock
            KeyBtn { visible: root.isMac; textNormal: "⚲"; keyCommand: "Escape"; customWidth: 46 }

            // 75% Right Del
            KeyBtn { visible: root.is75; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46 }

            // 80% TKL & Full Size Right Cluster (PrtSc, ScrLk, Pause)
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PrtSc"; keyCommand: "Print"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "ScrLk"; keyCommand: "Scroll_Lock"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Pause"; keyCommand: "Pause"; customWidth: 46 }

            // Full Size Media/Numpad Top
            KeySpacer { visible: root.hasNumpad; customWidth: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Calc"; keyCommand: "Calc"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Mute"; keyCommand: "XF86AudioMute"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Vol-"; keyCommand: "XF86AudioLowerVolume"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Vol+"; keyCommand: "XF86AudioRaiseVolume"; customWidth: 44 }
          }

          // ----------------------------------------------------
          // ROW 1: Numbers & Diacritics
          // ----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "~" : (root.currentLayout === "CS" ? ";" : "`")
              textShift: (!root.hasFRow && root.fnActive) ? "`" : (root.currentLayout === "CS" ? "°" : "~")
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F1" : (root.currentLayout === "CS" ? "+" : "1")
              textShift: (!root.hasFRow && root.fnActive) ? "F1" : (root.currentLayout === "CS" ? "1" : "!")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F1" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F2" : (root.currentLayout === "CS" ? "ě" : "2")
              textShift: (!root.hasFRow && root.fnActive) ? "F2" : (root.currentLayout === "CS" ? "2" : "@")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F2" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F3" : (root.currentLayout === "CS" ? "š" : "3")
              textShift: (!root.hasFRow && root.fnActive) ? "F3" : (root.currentLayout === "CS" ? "3" : "#")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F3" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F4" : (root.currentLayout === "CS" ? "č" : "4")
              textShift: (!root.hasFRow && root.fnActive) ? "F4" : (root.currentLayout === "CS" ? "4" : "$")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F4" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F5" : (root.currentLayout === "CS" ? "ř" : "5")
              textShift: (!root.hasFRow && root.fnActive) ? "F5" : (root.currentLayout === "CS" ? "5" : "%")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F5" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F6" : (root.currentLayout === "CS" ? "ž" : "6")
              textShift: (!root.hasFRow && root.fnActive) ? "F6" : (root.currentLayout === "CS" ? "6" : "^")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F6" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F7" : (root.currentLayout === "CS" ? "ý" : "7")
              textShift: (!root.hasFRow && root.fnActive) ? "F7" : (root.currentLayout === "CS" ? "7" : "&")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F7" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F8" : (root.currentLayout === "CS" ? "á" : "8")
              textShift: (!root.hasFRow && root.fnActive) ? "F8" : (root.currentLayout === "CS" ? "8" : "*")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F8" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F9" : (root.currentLayout === "CS" ? "í" : "9")
              textShift: (!root.hasFRow && root.fnActive) ? "F9" : (root.currentLayout === "CS" ? "9" : "(")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F9" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F10" : (root.currentLayout === "CS" ? "é" : "0")
              textShift: (!root.hasFRow && root.fnActive) ? "F10" : (root.currentLayout === "CS" ? "0" : ")")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F10" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F11" : (root.currentLayout === "CS" ? "=" : "-")
              textShift: (!root.hasFRow && root.fnActive) ? "F11" : (root.currentLayout === "CS" ? "%" : "_")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F11" : ""
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F12" : (root.currentLayout === "CS" ? "´" : "=")
              textShift: (!root.hasFRow && root.fnActive) ? "F12" : (root.currentLayout === "CS" ? "ˇ" : "+")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F12" : ""
            }
            KeyBtn {
              textNormal: root.isMac ? "delete" : "⌫ BKSP"
              keyCommand: "BackSpace"
              customWidth: root.isMac ? 82 : 88
            }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46 }
            KeyBtn { visible: root.is75; textNormal: "Home"; keyCommand: "Home"; customWidth: 46 }

            // Extensions: 80% TKL & Full Size
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Ins"; keyCommand: "Insert"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Home"; keyCommand: "Home"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PgUp"; keyCommand: "Page_Up"; customWidth: 46 }

            // Extensions: Full Size Numpad
            KeySpacer { visible: root.hasNumpad; customWidth: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Num"; keyCommand: "Num_Lock"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "/"; keyCommand: "KP_Divide"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "*"; keyCommand: "KP_Multiply"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "-"; keyCommand: "KP_Subtract"; customWidth: 44 }
          }

          // ----------------------------------------------------
          // ROW 2: Tab & QWERTY Row
          // ----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            KeyBtn { textNormal: root.isMac ? "tab" : "⇥ TAB"; keyCommand: "Tab"; customWidth: root.isMac ? 65 : 70 }
            KeyBtn { textNormal: "q" }
            KeyBtn { textNormal: "w" }
            KeyBtn { textNormal: "e" }
            KeyBtn { textNormal: "r" }
            KeyBtn { textNormal: "t" }
            KeyBtn { textNormal: "y" }
            KeyBtn { textNormal: "u" }
            KeyBtn { textNormal: "i" }
            KeyBtn { textNormal: "o" }
            KeyBtn { textNormal: "p" }
            KeyBtn { textNormal: root.currentLayout === "CS" ? "ú" : "["; textShift: root.currentLayout === "CS" ? "/" : "{" }
            KeyBtn { textNormal: root.currentLayout === "CS" ? ")" : "]"; textShift: root.currentLayout === "CS" ? "(" : "}" }
            KeyBtn { textNormal: "\\"; textShift: "|"; customWidth: 55 }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65; textNormal: "PgUp"; keyCommand: "Page_Up"; customWidth: 46 }
            KeyBtn { visible: root.is75; textNormal: "PgUp"; keyCommand: "Page_Up"; customWidth: 46 }

            // Extensions: 80% TKL & Full Size
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "End"; keyCommand: "End"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PgDn"; keyCommand: "Page_Down"; customWidth: 46 }

            // Extensions: Full Size Numpad
            KeySpacer { visible: root.hasNumpad; customWidth: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "7"; keyCommand: "KP_7"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "8"; keyCommand: "KP_8"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "9"; keyCommand: "KP_9"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "+"; keyCommand: "KP_Add"; customWidth: 44 }
          }

          // ----------------------------------------------------
          // ROW 3: CapsLock & Home Row & Enter
          // ----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            KeyBtn {
              textNormal: root.isMac ? "caps lock" : "⇪ CAPS"
              customWidth: root.isMac ? 75 : 85
              isModifier: true
              modifierName: "caps"
              isActive: root.capsActive
            }
            KeyBtn { textNormal: "a" }
            KeyBtn { textNormal: "s" }
            KeyBtn { textNormal: "d" }
            KeyBtn { textNormal: "f" }
            KeyBtn { textNormal: "g" }
            KeyBtn { textNormal: "h" }
            KeyBtn { textNormal: "j" }
            KeyBtn { textNormal: "k" }
            KeyBtn { textNormal: "l" }
            KeyBtn { textNormal: root.currentLayout === "CS" ? "ů" : ";"; textShift: root.currentLayout === "CS" ? "\"" : ":" }
            KeyBtn { textNormal: root.currentLayout === "CS" ? "\"" : "'"; textShift: root.currentLayout === "CS" ? "!" : "\"" }
            KeyBtn {
              textNormal: root.isMac ? "return" : "↵ ENTER"
              keyCommand: "Return"
              customWidth: root.isMac ? 90 : 98
            }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65; textNormal: "PgDn"; keyCommand: "Page_Down"; customWidth: 46 }
            KeyBtn { visible: root.is75; textNormal: "PgDn"; keyCommand: "Page_Down"; customWidth: 46 }

            // Extensions: 80% TKL & Full Size (Nav cluster spacer)
            Item { visible: root.hasNavCluster; width: 12 + 46 * 3 + 4 * 2 }

            // Extensions: Full Size Numpad
            Item { visible: root.hasNumpad; width: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "4"; keyCommand: "KP_4"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "5"; keyCommand: "KP_5"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "6"; keyCommand: "KP_6"; customWidth: 44 }
            Item { visible: root.hasNumpad; width: 44 }
          }

          // ----------------------------------------------------
          // ROW 4: Shift & Bottom Letter Row
          // ----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            KeyBtn {
              textNormal: root.isMac ? "shift" : "⇧ SHIFT"
              customWidth: root.isMac ? 95 : 105
              isModifier: true
              modifierName: "shift_l"
              isActive: root.shiftLActive
            }
            KeyBtn { textNormal: "z" }
            KeyBtn { textNormal: "x" }
            KeyBtn { textNormal: "c" }
            KeyBtn { textNormal: "v" }
            KeyBtn { textNormal: "b" }
            KeyBtn { textNormal: "n" }
            KeyBtn { textNormal: "m" }
            KeyBtn { textNormal: ","; textShift: root.currentLayout === "CS" ? "?" : "<" }
            KeyBtn { textNormal: "."; textShift: root.currentLayout === "CS" ? ":" : ">" }
            KeyBtn { textNormal: root.currentLayout === "CS" ? "-" : "/"; textShift: root.currentLayout === "CS" ? "_" : "?" }
            KeyBtn {
              textNormal: root.isMac ? "shift" : (root.sysShiftsToggle ? "SHIFT ⇧ (TOGGLE)" : "SHIFT ⇧")
              customWidth: (root.is65 || root.is75 || root.isMac) ? 75 : 110
              isModifier: true
              modifierName: "shift_r"
              isActive: root.shiftRActive
            }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65 || root.is75; textNormal: "▲"; keyCommand: "Up"; customWidth: 42 }
            KeyBtn { visible: root.is65 || root.is75; textNormal: "End"; keyCommand: "End"; customWidth: 46 }

            // Extensions: macOS Layout Up Arrow
            KeyBtn { visible: root.isMac; textNormal: "▲"; keyCommand: "Up"; customWidth: 42 }

            // Extensions: 80% TKL & Full Size Inverted-T Up Arrow
            Item { visible: root.hasNavCluster; width: 12 }
            Item { visible: root.hasNavCluster; width: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "▲"; keyCommand: "Up"; customWidth: 46 }
            Item { visible: root.hasNavCluster; width: 46 }

            // Extensions: Full Size Numpad
            Item { visible: root.hasNumpad; width: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "1"; keyCommand: "KP_1"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "2"; keyCommand: "KP_2"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "3"; keyCommand: "KP_3"; customWidth: 44 }
            KeyBtn { visible: root.hasNumpad; textNormal: "↵"; keyCommand: "KP_Enter"; customWidth: 44 }
          }

          // ----------------------------------------------------
          // ROW 5: Bottom Function Row (Space, Layout, Modifiers, Arrows)
          // ----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            // macOS Layout Modifiers
            KeyBtn {
              visible: root.isMac
              textNormal: "fn"
              customWidth: 50
              isModifier: true
              modifierName: "fn"
              isActive: root.fnActive
            }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌃ control"
              customWidth: 65
              isModifier: true
              modifierName: "ctrl_l"
              isActive: root.ctrlLActive
            }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌥ option"
              customWidth: 70
              isModifier: true
              modifierName: "alt_l"
              isActive: root.altLActive
            }
            KeyBtn { visible: root.isMac; textNormal: "⌘ command"; customWidth: 75; isModifier: true; modifierName: "super"; isActive: root.superActive }
            KeyBtn { visible: root.isMac; textNormal: "SPACE"; keyCommand: "space"; Layout.fillWidth: true }
            KeyBtn { visible: root.isMac; textNormal: "⌘ command"; customWidth: 75; isModifier: true; modifierName: "super"; isActive: root.superActive }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌥ option"
              customWidth: 70
              isModifier: true
              modifierName: "alt_r"
              isActive: root.altRActive
            }
            KeyBtn { visible: root.isMac; textNormal: "󰌌 " + root.currentLayout; customWidth: 65; isModifier: true; modifierName: "layout" }
            KeyBtn { visible: root.isMac; textNormal: "◄"; keyCommand: "Left"; customWidth: 42 }
            KeyBtn { visible: root.isMac; textNormal: "▼"; keyCommand: "Down"; customWidth: 42 }
            KeyBtn { visible: root.isMac; textNormal: "►"; keyCommand: "Right"; customWidth: 42 }

            // Standard Modifiers (60%, 65%, 75%, 80% TKL, Full Size)
            KeyBtn {
              visible: !root.isMac
              textNormal: root.sysSwapLaltLctl ? "Alt" : "Ctrl"
              customWidth: 60
              isModifier: true
              modifierName: root.sysSwapLaltLctl ? "alt_l" : "ctrl_l"
              isActive: root.sysSwapLaltLctl ? root.altLActive : root.ctrlLActive
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: ""
              customIcon: "\ue900"
              customIconFont: "omarchy"
              customWidth: 60
              isModifier: true
              modifierName: "super"
              isActive: root.superActive
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: root.sysSwapLaltLctl ? "Ctrl" : "Alt"
              customWidth: 60
              isModifier: true
              modifierName: root.sysSwapLaltLctl ? "ctrl_l" : "alt_l"
              isActive: root.sysSwapLaltLctl ? root.ctrlLActive : root.altLActive
            }

            // Spacebar
            KeyBtn {
              visible: !root.isMac
              textNormal: "SPACE"
              keyCommand: "space"
              Layout.fillWidth: true
            }

            // Right Modifiers (Alt for European/Czech special characters, RAlt for US)
            KeyBtn {
              visible: !root.isMac
              textNormal: "Alt"
              customWidth: 55
              isModifier: true
              modifierName: root.sysHasAltGr ? "altgr" : "alt_r"
              isActive: root.sysHasAltGr ? root.altGrActive : root.altRActive
            }
            KeyBtn {
              visible: !root.isMac && (!root.hasFRow)
              textNormal: "Fn"
              customWidth: (root.currentFormat === "60%") ? 60 : 50
              isModifier: true
              modifierName: "fn"
              isActive: root.fnActive
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: "󰌌 " + root.currentLayout
              customWidth: 75
              isModifier: true
              modifierName: "layout"
            }
            KeyBtn {
              visible: !root.isMac && (root.currentFormat === "60%" || root.hasNavCluster || root.is75)
              textNormal: root.sysRctrlIsCompose ? "Comp" : "Ctrl"
              customWidth: 55
              isModifier: true
              modifierName: root.sysRctrlIsCompose ? "compose" : "ctrl_r"
              isActive: root.ctrlRActive
            }

            // Arrow Keys for 65% and 75%
            KeyBtn { visible: !root.isMac && (root.is65 || root.is75); textNormal: "◄"; keyCommand: "Left"; customWidth: 42 }
            KeyBtn { visible: !root.isMac && (root.is65 || root.is75); textNormal: "▼"; keyCommand: "Down"; customWidth: 42 }
            KeyBtn { visible: !root.isMac && (root.is65 || root.is75); textNormal: "►"; keyCommand: "Right"; customWidth: 42 }

            // Arrow Keys for 80% TKL and Full Size
            Item { visible: !root.isMac && root.hasNavCluster; width: 12 }
            KeyBtn { visible: !root.isMac && root.hasNavCluster; textNormal: "◄"; keyCommand: "Left"; customWidth: 46 }
            KeyBtn { visible: !root.isMac && root.hasNavCluster; textNormal: "▼"; keyCommand: "Down"; customWidth: 46 }
            KeyBtn { visible: !root.isMac && root.hasNavCluster; textNormal: "►"; keyCommand: "Right"; customWidth: 46 }

            // Full Size Numpad Bottom Row
            Item { visible: !root.isMac && root.hasNumpad; width: 12 }
            KeyBtn { visible: !root.isMac && root.hasNumpad; textNormal: "0"; keyCommand: "KP_0"; customWidth: 92 }
            KeyBtn { visible: !root.isMac && root.hasNumpad; textNormal: "."; keyCommand: "KP_Decimal"; customWidth: 44 }
            Item { visible: !root.isMac && root.hasNumpad; width: 44 }
          }
        }

        // Corner Resize Grip (Bottom-Right)
        MouseArea {
          id: cornerResizeGrip
          width: 24
          height: 24
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          cursorShape: Qt.SizeFDiagCursor
          hoverEnabled: true

          Text {
            anchors.centerIn: parent
            text: "◢"
            font.family: root.monoFont.family
            font.pixelSize: 11
            color: cornerResizeGrip.containsMouse ? root.accentColor : Qt.rgba(root.keyText.r, root.keyText.g, root.keyText.b, 0.4)
          }

          property real dragStartX: 0
          property real dragStartY: 0
          property real startW: 0
          property real startH: 0

          onPressed: function(mouse) {
            var pt = cornerResizeGrip.mapToItem(oskRootItem, mouse.x, mouse.y);
            root.isResizingOsk = true;
            dragStartX = pt.x;
            dragStartY = pt.y;
            startW = oskCard.width;
            startH = oskCard.height;
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              var pt = cornerResizeGrip.mapToItem(oskRootItem, mouse.x, mouse.y);
              var dx = pt.x - dragStartX;
              var dy = pt.y - dragStartY;
              var minW = root.minOskWidth;
              var maxW = oskWindow ? oskWindow.width - 20 : 1920;
              var minH = root.minOskHeight;
              var maxH = oskWindow ? oskWindow.height - 30 : 1080;
              root.oskWidth = Math.round(Math.max(minW, Math.min(maxW, startW + dx)));
              root.oskHeight = Math.round(Math.max(minH, Math.min(maxH, startH + dy)));
            }
          }

          onReleased: function(mouse) {
            root.isResizingOsk = false;
          }
        }

        // Edge Resize Handles (Left, Right, Top, Bottom)
        MouseArea {
          id: leftResizeEdge
          width: 8
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.topMargin: 8
          anchors.bottomMargin: 8
          cursorShape: Qt.SizeHorCursor
          hoverEnabled: true

          property real startGlobalX: 0
          property real startW: 0
          property real startX: 0

          onPressed: function(mouse) {
            var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
            root.isResizingOsk = true;
            startGlobalX = pt.x;
            startW = oskCard.width;
            startX = oskCard.x;
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
              var dx = pt.x - startGlobalX;
              var minW = root.minOskWidth;
              var maxW = oskWindow ? oskWindow.width - 20 : 1920;
              var newW = Math.max(minW, Math.min(maxW, startW - dx));
              root.oskWidth = Math.round(newW);
              root.oskX = Math.round(startX + (startW - newW));
            }
          }

          onReleased: function(mouse) {
            root.isResizingOsk = false;
          }
        }

        MouseArea {
          id: rightResizeEdge
          width: 8
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.topMargin: 8
          anchors.bottomMargin: 24
          cursorShape: Qt.SizeHorCursor
          hoverEnabled: true

          property real startGlobalX: 0
          property real startW: 0

          onPressed: function(mouse) {
            var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
            root.isResizingOsk = true;
            startGlobalX = pt.x;
            startW = oskCard.width;
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
              var dx = pt.x - startGlobalX;
              var minW = root.minOskWidth;
              var maxW = oskWindow ? oskWindow.width - 20 : 1920;
              root.oskWidth = Math.round(Math.max(minW, Math.min(maxW, startW + dx)));
            }
          }

          onReleased: function(mouse) {
            root.isResizingOsk = false;
          }
        }

        MouseArea {
          id: topResizeEdge
          height: 8
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          cursorShape: Qt.SizeVerCursor
          hoverEnabled: true

          property real startGlobalY: 0
          property real startH: 0
          property real startY: 0

          onPressed: function(mouse) {
            var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
            root.isResizingOsk = true;
            startGlobalY = pt.y;
            startH = oskCard.height;
            startY = oskCard.y;
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
              var dy = pt.y - startGlobalY;
              var minH = root.minOskHeight;
              var maxH = oskWindow ? oskWindow.height - 30 : 1080;
              var newH = Math.max(minH, Math.min(maxH, startH - dy));
              root.oskHeight = Math.round(newH);
              root.oskY = Math.round(startY + (startH - newH));
            }
          }

          onReleased: function(mouse) {
            root.isResizingOsk = false;
          }
        }

        MouseArea {
          id: bottomResizeEdge
          height: 8
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 8
          anchors.rightMargin: 24
          cursorShape: Qt.SizeVerCursor
          hoverEnabled: true

          property real startGlobalY: 0
          property real startH: 0

          onPressed: function(mouse) {
            var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
            root.isResizingOsk = true;
            startGlobalY = pt.y;
            startH = oskCard.height;
          }

          onPositionChanged: function(mouse) {
            if (pressed) {
              var pt = mapToItem(oskRootItem, mouse.x, mouse.y);
              var dy = pt.y - startGlobalY;
              var minH = root.minOskHeight;
              var maxH = oskWindow ? oskWindow.height - 30 : 1080;
              root.oskHeight = Math.round(Math.max(minH, Math.min(maxH, startH + dy)));
            }
          }

          onReleased: function(mouse) {
            root.isResizingOsk = false;
          }
        }
      }
    }
  }
}
