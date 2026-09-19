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

  // Virtual Keyboard Window Dimensions & Position
  property int oskWidth: 1020
  property int oskHeight: 285
  property real oskX: -1
  property real oskY: -1
  property int baseKeyFontSize: Math.max(10, Math.min(22, Math.round(12 * (oskCard ? oskCard.height / 285.0 : 1.0))))
  property bool isResizingOsk: false
  property bool isMovingOsk: false

  function resetOskPosition(): void {
    root.oskWidth = Math.min(1020, oskWindow ? oskWindow.width - 32 : 1020);
    root.oskHeight = 285;
    if (oskWindow && oskWindow.width > 0) {
      root.oskX = Math.round((oskWindow.width - root.oskWidth) / 2);
      root.oskY = Math.round(oskWindow.height - root.oskHeight - 16);
    } else {
      root.oskX = -1;
      root.oskY = -1;
    }
  }

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
    mask: Region { item: (root.isResizingOsk || root.isMovingOsk) ? oskWindow : oskCard }
    anchors { top: true; bottom: true; left: true; right: true }

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
      opacity: 1.0

      // Key Component
      component KeyBtn: Rectangle {
        id: kBtn
        property string textNormal: ""
        property string textShift: ""
        property string keyCommand: "" // for named keys like Return, BackSpace
        property real customWidth: 0
        property real customWeight: 1.0
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
            font.pixelSize: Math.max(11, Math.round(root.baseKeyFontSize * 1.1))
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
              font.pixelSize: Math.max(7, Math.round(root.baseKeyFontSize * 0.7))
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
              font.pixelSize: textNormal.length > 2 ? Math.max(9, Math.round(root.baseKeyFontSize * 0.85)) : root.baseKeyFontSize
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
          cursorShape: (kMouse.buttons & Qt.RightButton) ? Qt.SizeFDiagCursor : ((mouse.modifiers & Qt.MetaModifier) ? Qt.SizeAllCursor : Qt.PointingHandCursor)

          onPressed: function(mouse) {
            var globalPt = kMouse.mapToItem(oskWindow, mouse.x, mouse.y);
            var isSuperKey = (kBtn.isModifier && kBtn.modifierName === "super");

            if (mouse.button === Qt.RightButton) {
              var cardPt = kMouse.mapToItem(oskCard, mouse.x, mouse.y);
              cardDragArea.startResize(globalPt, cardPt.x, cardPt.y);
              return;
            }

            // Physical Super + Left click on keys (except Super key itself) -> move window
            if ((mouse.modifiers & Qt.MetaModifier) && mouse.button === Qt.LeftButton && !isSuperKey) {
              cardDragArea.startMove(globalPt);
              return;
            }

            if (kBtn.isModifier) {
              if (kBtn.modifierName === "shift") root.shiftActive = !root.shiftActive;
              else if (kBtn.modifierName === "caps") root.capsActive = !root.capsActive;
              else if (kBtn.modifierName === "ctrl") root.ctrlActive = !root.ctrlActive;
              else if (kBtn.modifierName === "super") root.superActive = !root.superActive;
              else if (kBtn.modifierName === "alt") root.altActive = !root.altActive;
              else if (kBtn.modifierName === "layout") root.cycleLayout();
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
            var globalPt = kMouse.mapToItem(oskWindow, mouse.x, mouse.y);
            if (cardDragArea.isResizing) {
              cardDragArea.doResize(globalPt);
            } else if (cardDragArea.isMoving) {
              cardDragArea.doMove(globalPt);
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
          var globalPt = cardDragArea.mapToItem(oskWindow, mouse.x, mouse.y);
          if (mouse.button === Qt.RightButton) {
            startResize(globalPt, mouse.x, mouse.y);
          } else if (mouse.button === Qt.LeftButton) {
            startMove(globalPt);
          }
        }

        onPositionChanged: function(mouse) {
          var globalPt = cardDragArea.mapToItem(oskWindow, mouse.x, mouse.y);
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
        // HEADER BAR (Title, Status Indicators, Controls)
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

          Text {
            visible: root.superActive
            text: "[SUPER ON]"
            font.family: root.monoFont.family
            font.pixelSize: 10
            font.bold: true
            color: root.accentColor
          }

          // Interactive Header Spacer (Drag LMB to Move, RMB to Resize)
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: (mouse.button === Qt.RightButton) ? Qt.SizeFDiagCursor : Qt.SizeAllCursor

              onPressed: function(mouse) {
                var globalPt = mapToItem(oskWindow, mouse.x, mouse.y);
                if (mouse.button === Qt.RightButton) {
                  var cardPt = mapToItem(oskCard, mouse.x, mouse.y);
                  cardDragArea.startResize(globalPt, cardPt.x, cardPt.y);
                } else {
                  cardDragArea.startMove(globalPt);
                }
              }

              onPositionChanged: function(mouse) {
                if (pressed) {
                  var globalPt = mapToItem(oskWindow, mouse.x, mouse.y);
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

          // Reset Window Size & Position Button
          Rectangle {
            implicitWidth: 54
            implicitHeight: 20
            radius: 3
            color: resetMouse.containsMouse ? root.keyHover : root.keyBg
            border.width: 1
            border.color: root.keyBorder

            Text {
              anchors.centerIn: parent
              text: "↺ RESET"
              font.family: root.monoFont.family
              font.pixelSize: 9
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
        // ROW 1: Numbers & Diacritics
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
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
          Layout.fillHeight: true
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
          Layout.fillHeight: true
          spacing: 4

          KeyBtn {
            textNormal: "⇪ CAPS"
            customWidth: 85
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
          Layout.fillHeight: true
          spacing: 4

          KeyBtn {
            textNormal: "⇧ SHIFT"
            customWidth: 105
            isModifier: true
            modifierName: "shift"
            isActive: root.shiftActive
            customColor: root.shiftActive ? root.accentColor : root.keyText
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
            modifierName: "shift"
            isActive: root.shiftActive
            customColor: root.shiftActive ? root.accentColor : root.keyText
          }
        }

        // ----------------------------------------------------
        // ROW 5: Bottom Function Row (Space, Layout, Arrows)
        // ----------------------------------------------------
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 4

          KeyBtn {
            textNormal: "Ctrl"
            customWidth: 60
            isModifier: true
            modifierName: "ctrl"
            isActive: root.ctrlActive
          }
          KeyBtn {
            textNormal: "Super"
            customIcon: "\ue900"
            customIconFont: "omarchy"
            customWidth: 74
            isModifier: true
            modifierName: "super"
            isActive: root.superActive
          }
          KeyBtn {
            textNormal: "Alt"
            customWidth: 60
            isModifier: true
            modifierName: "alt"
            isActive: root.altActive
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
            modifierName: "layout"
            customColor: root.warnColor
            customBg: Qt.rgba(251/255, 191/255, 36/255, 0.12)
          }

          // Arrow Keys
          KeyBtn { textNormal: "◄"; keyCommand: "Left"; customWidth: 42 }
          KeyBtn { textNormal: "▲"; keyCommand: "Up"; customWidth: 42 }
          KeyBtn { textNormal: "▼"; keyCommand: "Down"; customWidth: 42 }
          KeyBtn { textNormal: "►"; keyCommand: "Right"; customWidth: 42 }
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
          var pt = cornerResizeGrip.mapToItem(oskWindow, mouse.x, mouse.y);
          root.isResizingOsk = true;
          dragStartX = pt.x;
          dragStartY = pt.y;
          startW = oskCard.width;
          startH = oskCard.height;
        }

        onPositionChanged: function(mouse) {
          if (pressed) {
            var pt = cornerResizeGrip.mapToItem(oskWindow, mouse.x, mouse.y);
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
          var pt = mapToItem(oskWindow, mouse.x, mouse.y);
          root.isResizingOsk = true;
          startGlobalX = pt.x;
          startW = oskCard.width;
          startX = oskCard.x;
        }

        onPositionChanged: function(mouse) {
          if (pressed) {
            var pt = mapToItem(oskWindow, mouse.x, mouse.y);
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
          var pt = mapToItem(oskWindow, mouse.x, mouse.y);
          root.isResizingOsk = true;
          startGlobalX = pt.x;
          startW = oskCard.width;
        }

        onPositionChanged: function(mouse) {
          if (pressed) {
            var pt = mapToItem(oskWindow, mouse.x, mouse.y);
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
          var pt = mapToItem(oskWindow, mouse.x, mouse.y);
          root.isResizingOsk = true;
          startGlobalY = pt.y;
          startH = oskCard.height;
          startY = oskCard.y;
        }

        onPositionChanged: function(mouse) {
          if (pressed) {
            var pt = mapToItem(oskWindow, mouse.x, mouse.y);
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
          var pt = mapToItem(oskWindow, mouse.x, mouse.y);
          root.isResizingOsk = true;
          startGlobalY = pt.y;
          startH = oskCard.height;
        }

        onPositionChanged: function(mouse) {
          if (pressed) {
            var pt = mapToItem(oskWindow, mouse.x, mouse.y);
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
