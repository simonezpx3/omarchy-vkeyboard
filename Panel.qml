// Keyboard & Layout Selector Popup (Right Click Panel)
// Standard Omarchy KeyboardPanel Surface

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "simonez.vkeyboard"
  ipcTarget: "simonez.vkeyboard"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Forwarded properties and methods for layoutPopup content
  readonly property var availableFormats: hostWidget ? hostWidget.availableFormats : []
  readonly property var availableLayouts: hostWidget ? hostWidget.availableLayouts : []
  readonly property string currentFormat: hostWidget ? hostWidget.currentFormat : "75%"
  readonly property string currentLayout: hostWidget ? hostWidget.currentLayout : "EN"
  readonly property string layoutFullName: hostWidget ? hostWidget.layoutFullName : "English (US)"
  readonly property bool oskOpen: hostWidget ? hostWidget.oskOpen : false
  readonly property real oskOpacity: hostWidget ? hostWidget.oskOpacity : 1.0
  property bool hideHeader: hostWidget ? hostWidget.hideHeader : false

  function toggleOsk() { if (hostWidget) hostWidget.oskOpen = !hostWidget.oskOpen; }

  function resetOskPosition() { if (hostWidget) hostWidget.resetOskPosition(); }
  function setFormat(f) { if (hostWidget) hostWidget.setFormat(f); }
  function setLayout(c) { if (hostWidget) hostWidget.setLayout(c); }
  function setOskOpacity(o) { if (hostWidget) hostWidget.setOskOpacity(o); }

  function open() { layoutPopup.open = true; }
  function close() { layoutPopup.open = false; }
  function toggle() { layoutPopup.open ? close() : open(); }
  function closeForPopoutSwitch() { layoutPopup.closeForPopoutSwitch(); }

  readonly property bool opened: layoutPopup.open
  readonly property bool popoutSwitchClosing: layoutPopup.popoutSwitchClosing

    KeyboardPanel {
    id: layoutPopup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: false
    onOpenChanged: {
      // synced with hostWidget
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
              onToggled: root.toggleOsk()

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
                onToggled: {
                  if (hostWidget) hostWidget.hideHeader = !hostWidget.hideHeader;
                }

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
              text: "v1.6.1"
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

}
