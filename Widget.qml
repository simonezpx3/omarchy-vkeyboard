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
    { "code": "EN", "index": 0, "name": "English (US)" },
    { "code": "CS", "index": 1, "name": "Czech (QWERTY)" }
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
  readonly property real heightScale: Math.max(0.65, Math.min(2.5, (root.oskHeight / 285.0)))
  readonly property int baseKeyFontSize: Math.max(10, Math.min(32, Math.round(16 * heightScale)))
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
    root.oskWidth = Math.min(defW, oskWindow ? oskWindow.width - 32 : defW);
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
  readonly property color keyText: Color.foreground ? Color.foreground : "#e2e6d8"
  readonly property font monoFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 11 })
  readonly property font keyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 16, bold: true })
  readonly property font smallKeyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 9 })
  readonly property int fontSmall: Math.max(10, Style.font && Style.font.bodySmall ? Style.font.bodySmall : 10)
  readonly property int fontBody: Math.max(12, Style.font && Style.font.body ? Style.font.body : 12)

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

  // Keystroke & Command Execution (Strict Left/Right Keysym & Level 3 AltGr Support)
  function sendChar(char) {
    if (!char) return;
    var args = ["wtype"];
    if (root.ctrlLActive) args.push("-P", "Control_L");
    if (root.ctrlRActive) args.push("-P", "Control_R");
    if (root.altLActive) args.push("-P", "Alt_L");
    if (root.altRActive) args.push("-P", "Alt_R");
    if (root.altGrActive) args.push("-M", "altgr");
    if (root.superActive) args.push("-M", "logo");
    if (root.shiftLActive) args.push("-P", "Shift_L");
    if (root.shiftRActive) args.push("-P", "Shift_R");

    args.push("--", char);

    if (root.shiftRActive) args.push("-p", "Shift_R");
    if (root.shiftLActive) args.push("-p", "Shift_L");
    if (root.superActive) args.push("-m", "logo");
    if (root.altGrActive) args.push("-m", "altgr");
    if (root.altRActive) args.push("-p", "Alt_R");
    if (root.altLActive) args.push("-p", "Alt_L");
    if (root.ctrlRActive) args.push("-p", "Control_R");
    if (root.ctrlLActive) args.push("-p", "Control_L");
    Quickshell.execDetached(args);

    // Auto-release one-shot modifiers
    if (root.shiftLActive) root.shiftLActive = false;
    if (root.shiftRActive) root.shiftRActive = false;
    if (root.ctrlLActive) root.ctrlLActive = false;
    if (root.ctrlRActive) root.ctrlRActive = false;
    if (root.altLActive) root.altLActive = false;
    if (root.altRActive) root.altRActive = false;
    if (root.altGrActive) root.altGrActive = false;
    if (root.superActive) root.superActive = false;
  }

  function sendKey(keyName) {
    if (!keyName) return;
    var args = ["wtype"];
    if (root.ctrlLActive) args.push("-P", "Control_L");
    if (root.ctrlRActive) args.push("-P", "Control_R");
    if (root.altLActive) args.push("-P", "Alt_L");
    if (root.altRActive) args.push("-P", "Alt_R");
    if (root.altGrActive) args.push("-M", "altgr");
    if (root.superActive) args.push("-M", "logo");
    if (root.shiftLActive) args.push("-P", "Shift_L");
    if (root.shiftRActive) args.push("-P", "Shift_R");

    args.push("-k", keyName);

    if (root.shiftRActive) args.push("-p", "Shift_R");
    if (root.shiftLActive) args.push("-p", "Shift_L");
    if (root.superActive) args.push("-m", "logo");
    if (root.altGrActive) args.push("-m", "altgr");
    if (root.altRActive) args.push("-p", "Alt_R");
    if (root.altLActive) args.push("-p", "Alt_L");
    if (root.ctrlRActive) args.push("-p", "Control_R");
    if (root.ctrlLActive) args.push("-p", "Control_L");
    Quickshell.execDetached(args);

    if (root.shiftLActive) root.shiftLActive = false;
    if (root.shiftRActive) root.shiftRActive = false;
    if (root.ctrlLActive) root.ctrlLActive = false;
    if (root.ctrlRActive) root.ctrlRActive = false;
    if (root.altLActive) root.altLActive = false;
    if (root.altRActive) root.altRActive = false;
    if (root.altGrActive) root.altGrActive = false;
    if (root.superActive) root.superActive = false;
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
    padding: Style.space(3)
    contentWidth: layoutPopup.fittedContentWidth(Math.round(Style.space(310) * Math.max(1.0, Style.fontScale)))
    contentHeight: layoutPopup.fittedContentHeight(popupColumn.implicitHeight + Style.space(8), Math.round(Style.space(680) * Math.max(1.0, Style.fontScale)))

    Rectangle {
      anchors.fill: parent
      focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close();
          event.accepted = true;
        }
      }
      color: root.bgCard
      border.width: 1
      border.color: root.tuiBorder

      ColumnLayout {
        id: popupColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "󰌌 KEYBOARD CONFIG"
            font.family: root.monoFont.family
            font.pixelSize: 11
            font.bold: true
            color: root.accentColor
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "[ESC]"
            font.family: root.monoFont.family
            font.pixelSize: 10
            color: "#6b7280"
          }
        }

        // 1px Divider
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tuiBorder }

        // Section: Active Layout
        Text {
          text: "ACTIVE KEYBOARD LAYOUT:"
          font.family: root.monoFont.family
          font.pixelSize: 10
          font.bold: true
          color: "#9ca3af"
        }

        Repeater {
          model: root.availableLayouts

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 24
            color: lMouse.containsMouse ? root.keyHover : (root.currentLayout === modelData.code ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : "transparent")
            radius: 2

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              Text {
                text: (root.currentLayout === modelData.code ? "● " : "○ ") + modelData.name
                font.family: root.monoFont.family
                font.pixelSize: 10
                font.bold: root.currentLayout === modelData.code
                color: root.currentLayout === modelData.code ? root.accentColor : root.keyText
              }
              Item { Layout.fillWidth: true }
              Text {
                text: modelData.code
                font.family: root.monoFont.family
                font.pixelSize: 10
                font.bold: true
                color: root.currentLayout === modelData.code ? root.accentColor : "#6b7280"
              }
            }

            MouseArea {
              id: lMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setLayout(modelData.code);
                root.close();
              }
            }
          }
        }

        // 1px Divider
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tuiBorder }

        // Section: Keyboard Formats
        Text {
          text: "KEYBOARD FORMAT / SIZE:"
          font.family: root.monoFont.family
          font.pixelSize: 10
          font.bold: true
          color: "#9ca3af"
        }

        Repeater {
          model: [
            { id: "60%", name: "60% (Compact)" },
            { id: "65%", name: "65% (Compact + Arrows)" },
            { id: "75%", name: "75% (Compact + F-Row)" },
            { id: "80% (TKL)", name: "80% (TKL Tenkeyless)" },
            { id: "Full Size", name: "Full Size (100% + Numpad)" },
            { id: "macOS Layout", name: "macOS Layout (Unix/Mac)" }
          ]

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 24
            color: fmtItemMouse.containsMouse ? root.keyHover : (root.currentFormat === modelData.id ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : "transparent")
            radius: 2

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6
              Text {
                text: (root.currentFormat === modelData.id ? "● " : "○ ") + modelData.name
                font.family: root.monoFont.family
                font.pixelSize: 10
                font.bold: root.currentFormat === modelData.id
                color: root.currentFormat === modelData.id ? root.accentColor : root.keyText
              }
              Item { Layout.fillWidth: true }
              Text {
                text: modelData.id === "macOS Layout" ? "macOS" : modelData.id
                font.family: root.monoFont.family
                font.pixelSize: 10
                color: "#6b7280"
              }
            }

            MouseArea {
              id: fmtItemMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.setFormat(modelData.id);
                root.close();
              }
            }
          }
        }

        // 1px Divider
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tuiBorder }

        // Section: Opacity Slider (Presets removed per user instruction)
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "WINDOW OPACITY / TRANSPARENCY:"
            font.family: root.monoFont.family
            font.pixelSize: 10
            font.bold: true
            color: "#9ca3af"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: Math.round(root.oskOpacity * 100) + "%"
            font.family: root.monoFont.family
            font.pixelSize: 10
            font.bold: true
            color: root.accentColor
          }
        }

        // Opacity Slider Track
        Item {
          id: opacitySlider
          Layout.fillWidth: true
          implicitHeight: 22

          Rectangle {
            id: opacTrack
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 6
            radius: 3
            color: root.keyBg
            border.color: root.keyBorder
            border.width: 1

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              radius: 3
              width: Math.round(parent.width * Math.max(0, Math.min(1, root.oskOpacity)))
              color: root.accentColor
            }
          }

          // Cursor Thumb
          Rectangle {
            width: 10
            height: 16
            radius: 2
            anchors.verticalCenter: opacTrack.verticalCenter
            x: Math.max(0, Math.min(opacitySlider.width - width, Math.round(opacitySlider.width * Math.max(0, Math.min(1, root.oskOpacity)) - width / 2)))
            color: opacSliderMouse.containsMouse || opacSliderMouse.pressed ? "#ffffff" : root.accentColor
            border.color: root.tuiBorder
            border.width: 1
          }

          MouseArea {
            id: opacSliderMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updatePos(mx) {
              var r = Math.max(0.25, Math.min(1.0, mx / width))
              var stepped = Math.round(r / 0.05) * 0.05
              root.setOskOpacity(stepped)
            }

            onPressed: function(mouse) { updatePos(mouse.x) }
            onPositionChanged: function(mouse) {
              if (pressed) updatePos(mouse.x)
            }
            onWheel: function(wheel) {
              var d = (wheel.angleDelta.y > 0) ? 0.05 : -0.05
              root.setOskOpacity(root.oskOpacity + d)
              wheel.accepted = true
            }
          }
        }

        // 1px Divider
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tuiBorder }

        // Section: System Hardware & XKB Profile
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "SYSTEM HARDWARE & XKB PROFILE:"
            font.family: root.monoFont.family
            font.pixelSize: 10
            font.bold: true
            color: "#9ca3af"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.sysHasAltGr ? "AltGr: Active" : "Alt: Standard"
            font.family: root.monoFont.family
            font.pixelSize: 10
            font.bold: true
            color: root.accentColor
          }
        }
        Text {
          Layout.fillWidth: true
          text: "• Independent L/R modifiers (Shift, Ctrl, Alt)" + (root.sysAltShiftToggle ? "\n• Shortcut Alt+Shift: Switch Layout" : "") + (root.sysShiftsToggle ? "\n• Shortcut L+R Shift: Switch Layout" : "") + (root.sysSwapLaltLctl ? "\n• Swapped: Left Ctrl ↔ Left Alt" : "") + (root.sysRctrlIsCompose ? "\n• Right Ctrl: Compose key" : "")
          font.family: root.monoFont.family
          font.pixelSize: 10
          color: "#9ca3af"
          wrapMode: Text.WordWrap
        }

        // 1px Divider
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tuiBorder }

        // Action: Toggle OSK
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          color: oskActionMouse.containsMouse ? root.keyHover : "transparent"
          radius: 2

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            Text {
              text: "󰌌"
              font.family: root.monoFont.family
              font.pixelSize: 12
              color: root.accentColor
            }
            Text {
              text: root.oskOpen ? "Hide Virtual Keyboard" : "Show Virtual Keyboard"
              font.family: root.monoFont.family
              font.pixelSize: 10
              color: root.keyText
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "[L-Click]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              color: "#6b7280"
            }
          }

          MouseArea {
            id: oskActionMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.oskOpen = !root.oskOpen;
              root.close();
            }
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

          readonly property real widthScale: Math.max(0.65, Math.min(1.8, oskCard.width / 1020.0))

          Layout.fillWidth: customWidth === 0
          Layout.preferredWidth: customWidth > 0 ? Math.round(customWidth * widthScale) : 0
          Layout.fillHeight: true
          Layout.minimumHeight: 24
          radius: 4
          color: kMouse.pressed ? root.keyPressed : (kMouse.containsMouse ? root.keyHover : (isActive ? Qt.rgba(52/255, 211/255, 153/255, 0.25) : customBg))
          border.width: 1
          border.color: isActive ? root.accentColor : (kMouse.containsMouse ? "#4b5563" : root.keyBorder)

          RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
              visible: kBtn.customIcon !== ""
              Layout.alignment: Qt.AlignVCenter
              text: kBtn.customIcon
              font.family: kBtn.customIconFont !== "" ? kBtn.customIconFont : root.monoFont.family
              font.pixelSize: Math.max(12, Math.round(root.baseKeyFontSize * 1.1))
              color: isActive ? root.accentColor : kBtn.customColor
              verticalAlignment: Text.AlignVCenter
            }

            ColumnLayout {
              Layout.alignment: Qt.AlignVCenter
              spacing: 1

              // Shifted character (if present)
              Text {
                visible: textShift !== "" && textShift !== textNormal
                Layout.alignment: Qt.AlignHCenter
                text: textShift
                font.family: root.monoFont.family
                font.pixelSize: Math.max(7, Math.round(root.baseKeyFontSize * 0.65))
                color: root.shiftActive ? root.accentColor : "#9ca3af"
              }

              // Main character / label
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                  if (root.shiftActive && textShift !== "") return textShift;
                  if (root.capsActive || root.shiftActive) {
                    return textNormal.toUpperCase();
                  }
                  return textNormal;
                }
                font.family: root.keyFont.family
                font.pixelSize: (textNormal.length > 3) ? Math.max(10, Math.round(root.baseKeyFontSize * 0.8)) : ((textNormal.length > 1) ? Math.max(11, Math.round(root.baseKeyFontSize * 0.9)) : root.baseKeyFontSize)
                font.bold: true
                color: isActive ? root.accentColor : kBtn.customColor
                verticalAlignment: Text.AlignVCenter
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
                var ch = (root.shiftActive && kBtn.textShift !== "") ? kBtn.textShift : (root.capsActive || root.shiftActive ? kBtn.textNormal.toUpperCase() : kBtn.textNormal);
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
            var minW = 600;
            var maxW = oskWindow ? oskWindow.width - 20 : 1920;
            var minH = 180;
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
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 6

            Text {
              text: "⠿"
              font.family: root.monoFont.family
              font.pixelSize: 12
              color: root.accentColor
            }

            Text {
              text: "󰌌 VIRTUAL KEYBOARD // ON-SCREEN"
              font.family: root.monoFont.family
              font.pixelSize: 11
              font.bold: true
              color: root.keyText
            }

            Text {
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
              visible: root.fnActive
              text: "[FN ON]"
              font.family: root.monoFont.family
              font.pixelSize: 10
              font.bold: true
              color: root.cyanColor
            }

            // Interactive Header Spacer (Drag LMB to Move, RMB to Resize)
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

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

            // Quick Opacity Badge (Cycle 100% -> 80% -> 60% -> 40%)
            Rectangle {
              implicitWidth: opacBadgeLabel.implicitWidth + 12
              implicitHeight: 20
              radius: 3
              color: opacBadgeMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: opacBadgeMouse.containsMouse ? root.accentColor : root.keyBorder

              RowLayout {
                anchors.centerIn: parent
                spacing: 3
                Text {
                  id: opacBadgeLabel
                  text: "◐ " + Math.round(root.oskOpacity * 100) + "%"
                  font.family: root.monoFont.family
                  font.pixelSize: 10
                  font.bold: true
                  color: opacBadgeMouse.containsMouse ? root.accentColor : root.keyText
                }
              }

              MouseArea {
                id: opacBadgeMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cycleOpacity()
              }
            }

            // Format Selector Badge
            Rectangle {
              implicitWidth: fmtLabel.implicitWidth + 14
              implicitHeight: 20
              radius: 3
              color: fmtMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: fmtMouse.containsMouse ? root.accentColor : root.keyBorder

              RowLayout {
                anchors.centerIn: parent
                spacing: 3
                Text {
                  id: fmtLabel
                  text: "⌨ " + root.currentFormat + " ▾"
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

            // Reset Window Size & Position Button (Icon only)
            Rectangle {
              implicitWidth: 24
              implicitHeight: 20
              radius: 3
              color: resetMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: root.keyBorder

              Text {
                anchors.centerIn: parent
                text: "↺"
                font.family: root.monoFont.family
                font.pixelSize: 13
                font.bold: true
                color: resetMouse.containsMouse ? root.accentColor : "#9ca3af"
              }

              MouseArea {
                id: resetMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetOskPosition()
              }
            }

            // Quick ESC Key
            Rectangle {
              implicitWidth: 42
              implicitHeight: 20
              radius: 3
              color: escMouse.containsMouse ? root.keyHover : root.keyBg
              border.width: 1
              border.color: root.keyBorder

              Text {
                anchors.centerIn: parent
                text: "ESC"
                font.family: root.monoFont.family
                font.pixelSize: 10
                color: root.keyText
              }

              MouseArea {
                id: escMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sendKey("Escape")
              }
            }

            // Close Button [X]
            Rectangle {
              implicitWidth: 26
              implicitHeight: 20
              radius: 3
              color: closeMouse.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.05)
              border.width: 1
              border.color: closeMouse.containsMouse ? "#ef4444" : root.tuiBorder

              Text {
                anchors.centerIn: parent
                text: "×"
                font.family: root.monoFont.family
                font.pixelSize: 14
                font.bold: true
                color: closeMouse.containsMouse ? "#ffffff" : "#9ca3af"
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.oskOpen = false
              }
            }
          }

          // 1px Divider
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
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

            KeyBtn { textNormal: root.isMac ? "esc" : "ESC"; keyCommand: "Escape"; customWidth: root.isMac ? 65 : 48; customColor: root.cyanColor }

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
            KeyBtn { visible: root.isMac; textNormal: "⚲"; keyCommand: "Escape"; customWidth: 46; customColor: root.accentColor }

            // 75% Right Del
            KeyBtn { visible: root.is75; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46; customColor: root.warnColor }

            // 80% TKL & Full Size Right Cluster (PrtSc, ScrLk, Pause)
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PrtSc"; keyCommand: "Print"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "ScrLk"; keyCommand: "Scroll_Lock"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Pause"; keyCommand: "Pause"; customWidth: 46 }

            // Full Size Media/Numpad Top
            KeySpacer { visible: root.hasNumpad; customWidth: 12 }
            KeyBtn { visible: root.hasNumpad; textNormal: "Calc"; customWidth: 44 }
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
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F2" : (root.currentLayout === "CS" ? "ě" : "2")
              textShift: (!root.hasFRow && root.fnActive) ? "F2" : (root.currentLayout === "CS" ? "2" : "@")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F2" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F3" : (root.currentLayout === "CS" ? "š" : "3")
              textShift: (!root.hasFRow && root.fnActive) ? "F3" : (root.currentLayout === "CS" ? "3" : "#")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F3" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F4" : (root.currentLayout === "CS" ? "č" : "4")
              textShift: (!root.hasFRow && root.fnActive) ? "F4" : (root.currentLayout === "CS" ? "4" : "$")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F4" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F5" : (root.currentLayout === "CS" ? "ř" : "5")
              textShift: (!root.hasFRow && root.fnActive) ? "F5" : (root.currentLayout === "CS" ? "5" : "%")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F5" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F6" : (root.currentLayout === "CS" ? "ž" : "6")
              textShift: (!root.hasFRow && root.fnActive) ? "F6" : (root.currentLayout === "CS" ? "6" : "^")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F6" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F7" : (root.currentLayout === "CS" ? "ý" : "7")
              textShift: (!root.hasFRow && root.fnActive) ? "F7" : (root.currentLayout === "CS" ? "7" : "&")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F7" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F8" : (root.currentLayout === "CS" ? "á" : "8")
              textShift: (!root.hasFRow && root.fnActive) ? "F8" : (root.currentLayout === "CS" ? "8" : "*")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F8" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F9" : (root.currentLayout === "CS" ? "í" : "9")
              textShift: (!root.hasFRow && root.fnActive) ? "F9" : (root.currentLayout === "CS" ? "9" : "(")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F9" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F10" : (root.currentLayout === "CS" ? "é" : "0")
              textShift: (!root.hasFRow && root.fnActive) ? "F10" : (root.currentLayout === "CS" ? "0" : ")")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F10" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F11" : (root.currentLayout === "CS" ? "=" : "-")
              textShift: (!root.hasFRow && root.fnActive) ? "F11" : (root.currentLayout === "CS" ? "%" : "_")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F11" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: (!root.hasFRow && root.fnActive) ? "F12" : (root.currentLayout === "CS" ? "´" : "=")
              textShift: (!root.hasFRow && root.fnActive) ? "F12" : (root.currentLayout === "CS" ? "ˇ" : "+")
              keyCommand: (!root.hasFRow && root.fnActive) ? "F12" : ""
              customColor: (!root.hasFRow && root.fnActive) ? root.cyanColor : root.keyText
            }
            KeyBtn {
              textNormal: root.isMac ? "delete" : "⌫ BKSP"
              keyCommand: "BackSpace"
              customWidth: root.isMac ? 82 : 88
              customColor: root.warnColor
            }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46; customColor: root.warnColor }
            KeyBtn { visible: root.is75; textNormal: "Home"; keyCommand: "Home"; customWidth: 46 }

            // Extensions: 80% TKL & Full Size
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Ins"; keyCommand: "Insert"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Home"; keyCommand: "Home"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PgUp"; keyCommand: "Prior"; customWidth: 46 }

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

            KeyBtn { textNormal: root.isMac ? "tab" : "⇥ TAB"; keyCommand: "Tab"; customWidth: root.isMac ? 65 : 70; customColor: root.cyanColor }
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
            KeyBtn { visible: root.is65; textNormal: "PgUp"; keyCommand: "Prior"; customWidth: 46 }
            KeyBtn { visible: root.is75; textNormal: "PgUp"; keyCommand: "Prior"; customWidth: 46 }

            // Extensions: 80% TKL & Full Size
            KeySpacer { visible: root.hasNavCluster; customWidth: 12 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "Del"; keyCommand: "Delete"; customWidth: 46; customColor: root.warnColor }
            KeyBtn { visible: root.hasNavCluster; textNormal: "End"; keyCommand: "End"; customWidth: 46 }
            KeyBtn { visible: root.hasNavCluster; textNormal: "PgDn"; keyCommand: "Next"; customWidth: 46 }

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
              customColor: root.capsActive ? root.cyanColor : root.keyText
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
              customColor: "#ffffff"
              customBg: Qt.rgba(52/255, 211/255, 153/255, 0.22)
            }

            // Extensions: 65% / 75%
            KeyBtn { visible: root.is65; textNormal: "PgDn"; keyCommand: "Next"; customWidth: 46 }
            KeyBtn { visible: root.is75; textNormal: "PgDn"; keyCommand: "Next"; customWidth: 46 }

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
              customColor: root.shiftLActive ? root.accentColor : root.keyText
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
              customColor: root.shiftRActive ? root.accentColor : root.keyText
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
            KeyBtn { visible: root.hasNumpad; textNormal: "↵"; keyCommand: "KP_Enter"; customWidth: 44; customColor: "#ffffff"; customBg: Qt.rgba(52/255, 211/255, 153/255, 0.22) }
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
              customColor: root.fnActive ? root.cyanColor : root.keyText
            }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌃ control"
              customWidth: 65
              isModifier: true
              modifierName: "ctrl_l"
              isActive: root.ctrlLActive
              customColor: root.ctrlLActive ? root.accentColor : root.keyText
            }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌥ option"
              customWidth: 70
              isModifier: true
              modifierName: "alt_l"
              isActive: root.altLActive
              customColor: root.altLActive ? root.accentColor : root.keyText
            }
            KeyBtn { visible: root.isMac; textNormal: "⌘ command"; customWidth: 75; isModifier: true; modifierName: "super"; isActive: root.superActive }
            KeyBtn { visible: root.isMac; textNormal: "SPACE"; keyCommand: "space"; Layout.fillWidth: true; customColor: "#9ca3af" }
            KeyBtn { visible: root.isMac; textNormal: "⌘ command"; customWidth: 75; isModifier: true; modifierName: "super"; isActive: root.superActive }
            KeyBtn {
              visible: root.isMac
              textNormal: "⌥ option"
              customWidth: 70
              isModifier: true
              modifierName: "alt_r"
              isActive: root.altRActive
              customColor: root.altRActive ? root.accentColor : root.keyText
            }
            KeyBtn { visible: root.isMac; textNormal: "󰌌 " + root.currentLayout; customWidth: 65; isModifier: true; modifierName: "layout"; customColor: root.warnColor; customBg: Qt.rgba(251/255, 191/255, 36/255, 0.12) }
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
              customColor: (root.sysSwapLaltLctl ? root.altLActive : root.ctrlLActive) ? root.accentColor : root.keyText
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: "Super"
              customIcon: "\ue900"
              customIconFont: "omarchy"
              customWidth: 72
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
              customColor: (root.sysSwapLaltLctl ? root.ctrlLActive : root.altLActive) ? root.accentColor : root.keyText
            }

            // Spacebar
            KeyBtn {
              visible: !root.isMac
              textNormal: "SPACE"
              keyCommand: "space"
              Layout.fillWidth: true
              customColor: "#9ca3af"
            }

            // Right Modifiers (Alt for European/Czech special characters, RAlt for US)
            KeyBtn {
              visible: !root.isMac
              textNormal: "Alt"
              customWidth: 55
              isModifier: true
              modifierName: root.sysHasAltGr ? "altgr" : "alt_r"
              isActive: root.sysHasAltGr ? root.altGrActive : root.altRActive
              customColor: (root.sysHasAltGr ? root.altGrActive : root.altRActive) ? root.accentColor : root.keyText
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: "Fn"
              customWidth: (root.currentFormat === "60%" || root.hasNavCluster) ? 60 : 50
              isModifier: true
              modifierName: "fn"
              isActive: root.fnActive
              customColor: root.fnActive ? root.cyanColor : root.keyText
            }
            KeyBtn {
              visible: !root.isMac
              textNormal: "󰌌 " + root.currentLayout
              customWidth: 75
              isModifier: true
              modifierName: "layout"
              customColor: root.warnColor
              customBg: Qt.rgba(251/255, 191/255, 36/255, 0.12)
            }
            KeyBtn {
              visible: !root.isMac && (root.currentFormat === "60%" || root.hasNavCluster)
              textNormal: root.sysRctrlIsCompose ? "Comp" : "Ctrl"
              customWidth: 55
              isModifier: true
              modifierName: root.sysRctrlIsCompose ? "compose" : "ctrl_r"
              isActive: root.ctrlRActive
              customColor: root.ctrlRActive ? root.accentColor : root.keyText
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
              var minW = 600;
              var maxW = oskWindow ? oskWindow.width - 20 : 1920;
              var minH = 180;
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
              var minW = 600;
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
              var minW = 600;
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
              var minH = 180;
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
              var minH = 180;
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
