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
  property bool oskOpen: false

  // Modifiers state for Virtual Keyboard
  property bool shiftActive: false
  property bool capsActive: false
  property bool ctrlActive: false
  property bool altActive: false
  property bool superActive: false

  // Configuration
  property bool showBadge: setting("showBadge", true)

  // Lifecycle Properties for Right-Click PopupCard
  property bool opened: false
  property alias popupOpen: root.opened
  property bool popoutSwitchClosing: false

  function open() { root.opened = true; }
  function close() { root.opened = false; }
  function toggle() { root.opened = !root.opened; }
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
  }

  // Unified CRT Monolithic Grid Theme
  readonly property color tuiBorder: Color.mBase && Color.mBase.border ? Color.mBase.border : "#30363d"
  readonly property color accentColor: "#34d399" // Emerald CRT
  readonly property color warnColor: "#fbbf24"   // Amber
  readonly property color cyanColor: "#38bdf8"   // Cyan
  readonly property color bgCard: "#0d1117"
  readonly property color bgOsk: "#0f141cee"
  readonly property color keyBg: "#161b22"
  readonly property color keyHover: "#21262d"
  readonly property color keyPressed: "#30363d"
  readonly property color keyBorder: "#30363d"
  readonly property color keyText: "#e6edf3"
  readonly property font monoFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 11 })
  readonly property font keyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 12, bold: true })
  readonly property font smallKeyFont: Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 9 })

  // Keystroke & Command Execution
  function sendChar(char) {
    if (!char) return;
    var mods = [];
    if (root.ctrlActive) mods.push("ctrl");
    if (root.altActive) mods.push("alt");
    if (root.superActive) mods.push("logo");
    
    // Construct wtype invocation
    var args = ["wtype"];
    for (var i = 0; i < mods.length; i++) {
      args.push("-M", mods[i]);
    }
    args.push("--", char);
    for (var j = mods.length - 1; j >= 0; j--) {
      args.push("-m", mods[j]);
    }
    Quickshell.execDetached(args);

    // Auto-release one-shot modifiers
    if (root.shiftActive) root.shiftActive = false;
    if (root.ctrlActive) root.ctrlActive = false;
    if (root.altActive) root.altActive = false;
    if (root.superActive) root.superActive = false;
  }

  function sendKey(keyName) {
    if (!keyName) return;
    var mods = [];
    if (root.ctrlActive) mods.push("ctrl");
    if (root.altActive) mods.push("alt");
    if (root.superActive) mods.push("logo");
    if (root.shiftActive) mods.push("shift");

    var args = ["wtype"];
    for (var i = 0; i < mods.length; i++) {
      args.push("-M", mods[i]);
    }
    args.push("-k", keyName);
    for (var j = mods.length - 1; j >= 0; j--) {
      args.push("-m", mods[j]);
    }
    Quickshell.execDetached(args);

    if (root.shiftActive) root.shiftActive = false;
    if (root.ctrlActive) root.ctrlActive = false;
    if (root.altActive) root.altActive = false;
    if (root.superActive) root.superActive = false;
  }

  function setLayout(code) {
    var idx = code === "CS" ? "1" : "0";
    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", idx]);
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
  // 1. BAR CHIP WIDGET (Top Bar Icon & Indicator)
  // =========================================================================
  implicitWidth: barChip.implicitWidth
  implicitHeight: barChip.implicitHeight

  Rectangle {
    id: barChip
    implicitWidth: chipRow.implicitWidth + 12
    implicitHeight: Math.max(24, root.barSize - 6)
    color: chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : (root.oskOpen ? Qt.rgba(52/255, 211/255, 153/255, 0.12) : "transparent")
    radius: 4
    border.width: 1
    border.color: root.oskOpen ? root.accentColor : (chipMouse.containsMouse ? root.tuiBorder : "transparent")

    RowLayout {
      id: chipRow
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: "󰌌"
        font.family: root.monoFont.family
        font.pixelSize: 14
        color: root.oskOpen ? root.accentColor : (root.currentLayout === "CS" ? root.cyanColor : root.keyText)
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        visible: root.showBadge
        text: root.currentLayout
        font.family: root.monoFont.family
        font.pixelSize: 10
        font.bold: true
        color: root.currentLayout === "CS" ? root.warnColor : root.accentColor
        verticalAlignment: Text.AlignVCenter
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.toggle(); // Right Click: Layout menu
        } else if (mouse.button === Qt.LeftButton) {
          root.oskOpen = !root.oskOpen; // Left Click: Toggle Virtual Keyboard
        }
      }
    }
  }

  // =========================================================================
  // 2. RIGHT-CLICK POPUP MENU (CS / ENG Layout Switcher)
  // =========================================================================
  PopupCard {
    id: layoutPopup
    anchorItem: barChip
    bar: root.bar
    open: root.opened
    contentWidth: 260
    contentHeight: 180

    Rectangle {
      anchors.fill: parent
      color: root.bgCard
      border.width: 1
      border.color: root.tuiBorder

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // Header
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "󰌌 KEYBOARD LAYOUT"
            font.family: root.monoFont.family
            font.pixelSize: 11
            font.bold: true
            color: root.accentColor
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "[R-CLICK]"
            font.family: root.monoFont.family
            font.pixelSize: 9
            color: "#6b7280"
          }
        }

        // 1px Divider
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: root.tuiBorder
        }

        // Option: Czech (QWERTY)
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 28
          color: csMouse.containsMouse ? root.keyHover : (root.currentLayout === "CS" ? Qt.rgba(56/255, 189/255, 248/255, 0.12) : "transparent")
          border.width: 1
          border.color: root.currentLayout === "CS" ? root.cyanColor : "transparent"
          radius: 3

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Text {
              text: root.currentLayout === "CS" ? "★" : "○"
              font.family: root.monoFont.family
              font.pixelSize: 11
              color: root.currentLayout === "CS" ? root.cyanColor : "#6b7280"
            }
            Text {
              text: "Čeština (QWERTY)"
              font.family: root.monoFont.family
              font.pixelSize: 11
              font.bold: root.currentLayout === "CS"
              color: root.currentLayout === "CS" ? "#ffffff" : root.keyText
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "CS"
              font.family: root.monoFont.family
              font.pixelSize: 10
              color: root.warnColor
            }
          }

          MouseArea {
            id: csMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setLayout("CS");
              root.close();
            }
          }
        }

        // Option: English (US)
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 28
          color: enMouse.containsMouse ? root.keyHover : (root.currentLayout === "EN" ? Qt.rgba(52/255, 211/255, 153/255, 0.12) : "transparent")
          border.width: 1
          border.color: root.currentLayout === "EN" ? root.accentColor : "transparent"
          radius: 3

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Text {
              text: root.currentLayout === "EN" ? "★" : "○"
              font.family: root.monoFont.family
              font.pixelSize: 11
              color: root.currentLayout === "EN" ? root.accentColor : "#6b7280"
            }
            Text {
              text: "English (US)"
              font.family: root.monoFont.family
              font.pixelSize: 11
              font.bold: root.currentLayout === "EN"
              color: root.currentLayout === "EN" ? "#ffffff" : root.keyText
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "EN"
              font.family: root.monoFont.family
              font.pixelSize: 10
              color: root.accentColor
            }
          }

          MouseArea {
            id: enMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.setLayout("EN");
              root.close();
            }
          }
        }

        // 1px Divider
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: root.tuiBorder
        }

        // Action: Toggle Virtual Keyboard
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 26
          color: oskActionMouse.containsMouse ? root.keyHover : "transparent"
          radius: 3

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
              font.pixelSize: 9
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

        // Footer Hint
        Text {
          Layout.fillWidth: true
          text: "Alt+Shift to switch layout quickly"
          font.family: root.monoFont.family
          font.pixelSize: 9
          color: "#4b5563"
          horizontalAlignment: Text.AlignHCenter
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
    mask: Region { item: oskCard }
    anchors { top: true; bottom: true; left: true; right: true }

    Rectangle {
      id: oskCard
      width: Math.min(parent ? parent.width - 32 : 1020, 1020)
      height: 285
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 16
      anchors.horizontalCenter: parent.horizontalCenter
      color: root.bgOsk
      border.width: 1
      border.color: root.accentColor
      radius: 6

      // Key Component
      component KeyBtn: Rectangle {
        id: kBtn
        property string textNormal: ""
        property string textShift: ""
        property string keyCommand: "" // for named keys like Return, BackSpace
        property real customWidth: 0
        property real customWeight: 1.0
        property bool isModifier: false
        property bool isActive: false
        property color customColor: root.keyText
        property color customBg: root.keyBg

        Layout.fillWidth: customWidth === 0
        Layout.preferredWidth: customWidth > 0 ? customWidth : 0
        Layout.preferredHeight: 38
        radius: 4
        color: kMouse.pressed ? root.keyPressed : (kMouse.containsMouse ? root.keyHover : (isActive ? Qt.rgba(52/255, 211/255, 153/255, 0.25) : customBg))
        border.width: 1
        border.color: isActive ? root.accentColor : (kMouse.containsMouse ? "#4b5563" : root.keyBorder)

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 1

          // Shifted character (if present)
          Text {
            visible: textShift !== "" && textShift !== textNormal
            Layout.alignment: Qt.AlignHCenter
            text: textShift
            font.family: root.monoFont.family
            font.pixelSize: 8
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
            font.pixelSize: textNormal.length > 2 ? 10 : 13
            font.bold: true
            color: isActive ? root.accentColor : kBtn.customColor
          }
        }

        MouseArea {
          id: kMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            if (kBtn.isModifier) {
              return; // handled in parent
            }
            if (kBtn.keyCommand !== "") {
              root.sendKey(kBtn.keyCommand);
            } else {
              var ch = (root.shiftActive && kBtn.textShift !== "") ? kBtn.textShift : (root.capsActive || root.shiftActive ? kBtn.textNormal.toUpperCase() : kBtn.textNormal);
              root.sendChar(ch);
            }
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // ----------------------------------------------------
        // HEADER BAR (Title, Status Indicators, Controls)
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 22
          spacing: 8

          Text {
            text: "󰌌 VIRTUAL KEYBOARD // ON-SCREEN"
            font.family: root.monoFont.family
            font.pixelSize: 11
            font.bold: true
            color: root.accentColor
          }

          // Layout Switcher Badge
          Rectangle {
            implicitWidth: layoutText.implicitWidth + 12
            implicitHeight: 20
            radius: 3
            color: lBtnMouse.containsMouse ? root.keyHover : Qt.rgba(251/255, 191/255, 36/255, 0.15)
            border.width: 1
            border.color: root.warnColor

            RowLayout {
              anchors.centerIn: parent
              spacing: 3
              Text {
                id: layoutText
                text: "★ " + root.currentLayout + " (" + (root.currentLayout === "CS" ? "Czech" : "English") + ")"
                font.family: root.monoFont.family
                font.pixelSize: 10
                font.bold: true
                color: root.warnColor
              }
            }

            MouseArea {
              id: lBtnMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cycleLayout()
            }
          }

          // Active Modifier Badges
          Text {
            visible: root.shiftActive
            text: "[SHIFT ON]"
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

          Item { Layout.fillWidth: true }

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
        // ROW 1: Numbers & Diacritics
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 4

          KeyBtn { textNormal: root.currentLayout === "CS" ? ";" : "`"; textShift: root.currentLayout === "CS" ? "°" : "~" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "+" : "1"; textShift: root.currentLayout === "CS" ? "1" : "!" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "ě" : "2"; textShift: root.currentLayout === "CS" ? "2" : "@" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "š" : "3"; textShift: root.currentLayout === "CS" ? "3" : "#" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "č" : "4"; textShift: root.currentLayout === "CS" ? "4" : "$" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "ř" : "5"; textShift: root.currentLayout === "CS" ? "5" : "%" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "ž" : "6"; textShift: root.currentLayout === "CS" ? "6" : "^" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "ý" : "7"; textShift: root.currentLayout === "CS" ? "7" : "&" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "á" : "8"; textShift: root.currentLayout === "CS" ? "8" : "*" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "í" : "9"; textShift: root.currentLayout === "CS" ? "9" : "(" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "é" : "0"; textShift: root.currentLayout === "CS" ? "0" : ")" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "=" : "-"; textShift: root.currentLayout === "CS" ? "%" : "_" }
          KeyBtn { textNormal: root.currentLayout === "CS" ? "´" : "="; textShift: root.currentLayout === "CS" ? "ˇ" : "+" }
          KeyBtn {
            textNormal: "⌫ BKSP"
            keyCommand: "BackSpace"
            customWidth: 90
            customColor: root.warnColor
          }
        }

        // ----------------------------------------------------
        // ROW 2: Tab & QWERTY Row
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 4

          KeyBtn { textNormal: "⇥ TAB"; keyCommand: "Tab"; customWidth: 70; customColor: root.cyanColor }
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
          KeyBtn { textNormal: "\\"; textShift: "|"; customWidth: 60 }
        }

        // ----------------------------------------------------
        // ROW 3: CapsLock & Home Row & Enter
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 4

          KeyBtn {
            textNormal: "⇪ CAPS"
            customWidth: 85
            isModifier: true
            isActive: root.capsActive
            customColor: root.capsActive ? root.cyanColor : root.keyText
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.capsActive = !root.capsActive
            }
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
            textNormal: "↵ ENTER"
            keyCommand: "Return"
            customWidth: 100
            customColor: "#ffffff"
            customBg: Qt.rgba(52/255, 211/255, 153/255, 0.22)
          }
        }

        // ----------------------------------------------------
        // ROW 4: Shift & Bottom Letter Row
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 4

          KeyBtn {
            textNormal: "⇧ SHIFT"
            customWidth: 105
            isModifier: true
            isActive: root.shiftActive
            customColor: root.shiftActive ? root.accentColor : root.keyText
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.shiftActive = !root.shiftActive
            }
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
            textNormal: "⇧ SHIFT"
            customWidth: 110
            isModifier: true
            isActive: root.shiftActive
            customColor: root.shiftActive ? root.accentColor : root.keyText
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.shiftActive = !root.shiftActive
            }
          }
        }

        // ----------------------------------------------------
        // ROW 5: Bottom Function Row (Space, Layout, Arrows)
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          spacing: 4

          KeyBtn {
            textNormal: "Ctrl"
            customWidth: 60
            isModifier: true
            isActive: root.ctrlActive
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.ctrlActive = !root.ctrlActive
            }
          }
          KeyBtn {
            textNormal: "󰘳 Win"
            customWidth: 65
            isModifier: true
            isActive: root.superActive
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.superActive = !root.superActive
            }
          }
          KeyBtn {
            textNormal: "Alt"
            customWidth: 60
            isModifier: true
            isActive: root.altActive
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.altActive = !root.altActive
            }
          }

          // Wide Spacebar
          KeyBtn {
            textNormal: "SPACE"
            keyCommand: "space"
            Layout.fillWidth: true
            customColor: "#9ca3af"
          }

          // Layout Toggle Button
          KeyBtn {
            textNormal: "󰌌 " + root.currentLayout
            customWidth: 80
            isModifier: true
            customColor: root.warnColor
            customBg: Qt.rgba(251/255, 191/255, 36/255, 0.12)
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.cycleLayout()
            }
          }

          // Arrow Keys
          KeyBtn { textNormal: "◄"; keyCommand: "Left"; customWidth: 42 }
          KeyBtn { textNormal: "▲"; keyCommand: "Up"; customWidth: 42 }
          KeyBtn { textNormal: "▼"; keyCommand: "Down"; customWidth: 42 }
          KeyBtn { textNormal: "►"; keyCommand: "Right"; customWidth: 42 }
        }
      }
    }
  }
}
