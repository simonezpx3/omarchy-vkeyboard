// On-Screen Virtual Keyboard Window (Interactive Layer-Shell OSK)
// Standard Omarchy Floating Scope Window

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

PanelWindow {
  id: oskWindow
  property var root: null

  // Safe Fallback Style Properties when root is initializing
  readonly property font monoFont: root ? root.monoFont : Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 11 })
  readonly property font keyFont: root ? root.keyFont : Qt.font({ family: Style.font && Style.font.familyMono ? Style.font.familyMono : "JetBrains Mono NF", pixelSize: 16, bold: true })
  readonly property color keyText: root ? root.keyText : "#ffffff"
  readonly property color keyBg: root ? root.keyBg : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
  readonly property color keyHover: root ? root.keyHover : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)
  readonly property color keyPressed: root ? root.keyPressed : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28)
  readonly property color keyBorder: root ? root.keyBorder : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.18)
  readonly property color accentColor: root ? root.accentColor : (Color.accent ? Color.accent : "#3c7fdb")
  readonly property real widthScale: root ? root.widthScale : 1.0
  readonly property int baseKeyFontSize: root ? root.baseKeyFontSize : 15
  visible: root ? root.oskOpen : false
  color: "transparent"
  WlrLayershell.namespace: "omarchy-vkeyboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  mask: Region { item: (root && (root.isResizingOsk || root.isMovingOsk)) ? oskRootItem : oskCard }
  anchors { top: true; bottom: true; left: true; right: true }

    Item {
      id: oskRootItem
      anchors.fill: parent

      Rectangle {
        id: oskCard
        width: root ? root.oskWidth : 960
        height: root ? root.oskHeight : 285
        x: (root && root.oskX >= 0) ? root.oskX : ((oskWindow && oskWindow.width > width) ? Math.round((oskWindow.width - width) / 2) : 100)
        y: (root && root.oskY >= 0) ? root.oskY : ((oskWindow && oskWindow.height > height) ? Math.round(oskWindow.height - height - 16) : 500)
        color: root ? root.bgOsk : "#000618"
        border.width: 1
        border.color: root ? root.accentColor : "#3c7fdb"
        radius: 6
        opacity: root ? root.oskOpacity : 1.0

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
