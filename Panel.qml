// Keyboard & Layout Selector Popup (Right Click Panel)
// Standard Omarchy KeyboardPanel Surface

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
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

  function toggleOsk(): void { if (hostWidget) hostWidget.toggleOsk(); }
  function resetOskPosition(): void { if (hostWidget) hostWidget.resetOskPosition(); }
  function setFormat(f): void { if (hostWidget) hostWidget.setFormat(f); }
  function setLayout(c): void { if (hostWidget) hostWidget.setLayout(c); }
  function setOskOpacity(o): void { if (hostWidget) hostWidget.setOskOpacity(o); }

  function open(): void { layoutPopup.open = true; }
  function close(): void { layoutPopup.open = false; }
  function toggle(): void { layoutPopup.open ? close() : open(); }
  function closeForPopoutSwitch(): void { layoutPopup.closeForPopoutSwitch(); }

  readonly property bool opened: layoutPopup.open
  readonly property bool popoutSwitchClosing: layoutPopup.popoutSwitchClosing

  KeyboardPanel {
    id: layoutPopup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: false
    padding: Commons.Style.spacing.popupPadding
    contentWidth: layoutPopup.fittedContentWidth(Math.round(Commons.Style.space(350) * Math.max(1.0, Commons.Style.fontScale)))
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
        spacing: Commons.Style.space(12)

        // ---------- Hero: Keyboard Icon · Title + State · Actions ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroActions.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: "󰌌"
            color: root.bar ? root.bar.foreground : Commons.Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: Commons.Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          RowLayout {
            id: heroActions
            spacing: Commons.Style.space(8)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Button {
              id: resetAction
              iconText: "󰑐"
              tooltipText: "Reset keyboard position"
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              iconSize: Commons.Style.font.subtitle * 1.3
              horizontalPadding: Commons.Style.space(5)
              verticalPadding: Commons.Style.space(2)
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.resetOskPosition()
            }

            ToggleSwitch {
              id: oskPowerSwitch
              checked: root.oskOpen
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              Layout.alignment: Qt.AlignVCenter
              onToggled: root.toggleOsk()

              PanelToolTip {
                visible: oskPowerSwitch.containsMouse
                text: root.oskOpen ? "Hide on-screen keyboard" : "Show on-screen keyboard"
                fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              }
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Commons.Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: heroActions.width > 0 ? heroActions.width + Commons.Style.space(12) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Style.space(2)

            Text {
              id: heroTitle
              textFormat: Text.PlainText
              width: parent.width
              text: "Virtual Keyboard"
              color: root.bar ? root.bar.foreground : Commons.Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: heroMeta
              textFormat: Text.PlainText
              width: parent.width
              text: (root.oskOpen ? "ACTIVE" : "STANDBY") + " · " + root.currentLayout + " (" + root.layoutFullName + ")"
              color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        // ---------- Section 1: Keyboard Layout ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        Column {
          width: parent.width
          spacing: Commons.Style.space(8)

          PanelSectionHeader {
            text: "KEYBOARD LAYOUT"
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
          }

          Grid {
            id: layoutGrid
            width: parent.width
            columns: Math.min(2, Math.max(1, root.availableLayouts.length))
            spacing: Commons.Style.space(6)

            Repeater {
              model: root.availableLayouts
              delegate: Button {
                required property var modelData
                required property int index

                width: Math.floor((layoutGrid.width - layoutGrid.spacing * (layoutGrid.columns - 1)) / layoutGrid.columns)
                text: (modelData.name || modelData.code) + " [" + modelData.code + "]"
                fontSize: Commons.Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
                horizontalPadding: Commons.Style.space(6)
                verticalPadding: Commons.Style.spacing.controlPaddingY + Commons.Style.space(2)
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
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        Column {
          width: parent.width
          spacing: Commons.Style.space(8)

          PanelSectionHeader {
            text: "KEYBOARD FORMAT"
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
          }

          Grid {
            id: formatGrid
            width: parent.width
            columns: 3
            spacing: Commons.Style.space(6)

            Repeater {
              model: root.availableFormats
              delegate: Button {
                required property string modelData
                required property int index

                width: Math.floor((formatGrid.width - formatGrid.spacing * 2) / 3)
                text: modelData
                fontSize: Commons.Style.font.bodySmall
                foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
                horizontalPadding: Commons.Style.space(4)
                verticalPadding: Commons.Style.spacing.controlPaddingY + Commons.Style.space(2)
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
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        Column {
          width: parent.width
          spacing: Commons.Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(opacityHeader.implicitHeight, opacityValue.implicitHeight)

            PanelSectionHeader {
              id: opacityHeader
              text: "WINDOW OPACITY"
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: opacityValue
              textFormat: Text.PlainText
              text: Math.round(root.oskOpacity * 100) + "%"
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: Commons.Color.accent
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
            onMoved: function(val) { root.setOskOpacity(val); }
          }
        }

        // ---------- Section 4: Header Appearance ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        Column {
          width: parent.width
          spacing: Commons.Style.space(8)

          Item {
            width: parent.width
            implicitHeight: Math.max(headerToggleLabel.implicitHeight, headerToggleRow.implicitHeight)

            PanelSectionHeader {
              id: headerToggleLabel
              text: "HEADER VISIBILITY"
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Row {
              id: headerToggleRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Commons.Style.space(6)

              Text {
                textFormat: Text.PlainText
                text: root.hideHeader ? "HIDDEN" : "VISIBLE"
                font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
                font.pixelSize: Commons.Style.font.caption
                font.bold: true
                color: root.hideHeader ? Commons.Color.accent : Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.4)
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: headerToggleSwitch
                anchors.verticalCenter: parent.verticalCenter
                checked: root.hideHeader
                foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
                onToggled: {
                  if (hostWidget) hostWidget.hideHeader = !hostWidget.hideHeader;
                }

                PanelToolTip {
                  visible: headerToggleSwitch.containsMouse
                  text: root.hideHeader ? "Show top header bar on keyboard" : "Hide top header bar for borderless look"
                  fontFamily: root.bar ? root.bar.fontFamily : Commons.Style.font.family
                }
              }
            }
          }
        }

        // ---------- Footer: Version & Shortcut Hint ----------
        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        Item {
          width: parent.width
          implicitHeight: Commons.Style.space(16)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Commons.Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: "v1.7.0"
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.6)
            }
            Text {
              textFormat: Text.PlainText
              text: "·"
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.6)
            }
            Text {
              textFormat: Text.PlainText
              text: "Omarchy"
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.caption
              font.bold: true
              color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.4)
            }
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "[Esc: Close]"
            font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
            font.pixelSize: Commons.Style.font.caption
            color: Qt.darker(root.bar ? root.bar.foreground : Commons.Color.foreground, 1.6)
          }
        }
      }
    }
  }
}
