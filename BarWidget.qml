// Virtual Keyboard & Layout Switcher for Omarchy / Hyprland
// Quattro BarWidget EntryPoint

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "simonez.vkeyboard"

  // Service Discovery / Singleton Binding (Quattro Architecture)
  readonly property var shellService: (bar && bar.shell && typeof bar.shell.serviceFor === "function")
    ? bar.shell.serviceFor("simonez.vkeyboard")
    : null

  Loader {
    id: localServiceLoader
    active: root.shellService === null && root.opened
    sourceComponent: Component {
      Service {
        activePolling: false
      }
    }
  }

  readonly property var svc: root.shellService ? root.shellService : (localServiceLoader.item || null)

  // Forwarded Properties for Panel and Views
  readonly property var availableFormats: svc ? svc.availableFormats : []
  readonly property var availableLayouts: svc ? svc.availableLayouts : []
  readonly property string currentFormat: svc ? svc.currentFormat : "75%"
  readonly property string currentLayout: svc ? svc.currentLayout : "EN"
  readonly property string layoutFullName: svc ? svc.layoutFullName : "English (US)"
  readonly property bool oskOpen: svc ? svc.oskOpen : false
  readonly property real oskOpacity: svc ? svc.oskOpacity : 1.0
  property bool hideHeader: setting("hideHeader", false)
  property bool showBadge: setting("showBadge", true)

  onHideHeaderChanged: {
    if (svc) svc.hideHeader = root.hideHeader;
  }

  Connections {
    target: root.svc
    function onOpenPanelRequested() { root.open(); }
    function onClosePanelRequested() { root.close(); }
    function onTogglePanelRequested() { root.toggle(); }
  }

  function toggleOsk(): void {
    if (svc) svc.oskOpen = !svc.oskOpen;
  }

  function resetOskPosition(): void {
    if (!svc) return;
    var defW = svc.getFormatDefaultWidth(root.currentFormat);
    var defH = svc.getFormatDefaultHeight(root.currentFormat);
    var oskWin = oskLoader.item;
    svc.oskWidth = Math.min(defW, (oskWin && oskWin.width > 320) ? oskWin.width - 32 : defW);
    svc.oskHeight = defH;
    if (oskWin && oskWin.width > 0) {
      svc.oskX = Math.round((oskWin.width - svc.oskWidth) / 2);
      svc.oskY = Math.round(oskWin.height - svc.oskHeight - 16);
    } else {
      svc.oskX = -1;
      svc.oskY = -1;
    }
  }

  function setFormat(fmt): void {
    if (svc) svc.setFormat(fmt);
    resetOskPosition();
  }

  function cycleFormat(): void {
    if (svc) svc.cycleFormat();
    resetOskPosition();
  }

  function setLayout(target): void {
    if (svc) svc.setLayout(target);
  }

  function cycleLayout(): void {
    if (svc) svc.cycleLayout();
  }

  function setOskOpacity(val): void {
    if (svc) svc.setOskOpacity(val);
  }

  function cycleOpacity(): void {
    if (svc) svc.cycleOpacity();
  }

  // Lifecycle Properties for Right-Click KeyboardPanel (Omarchy Standard)
  property alias anchorButton: button
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open(): void { if (panelLoader.item) panelLoader.item.open(); }
  function close(): void { if (panelLoader.item) panelLoader.item.close(); }
  function toggle(): void { if (panelLoader.item) panelLoader.item.toggle(); }
  function closeForPopoutSwitch(): void { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

  function injectPanel(): void {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // =========================================================================
  // 1. BAR BUTTON (Unified Omarchy Bar Widget Standard)
  // =========================================================================
  implicitWidth: contentRow.implicitWidth + button.scaledHorizontalMargin * 2
  implicitHeight: button.implicitHeight

  function triggerPress(buttonCode): void {
    if (buttonCode === 1 || buttonCode === Qt.LeftButton) {
      root.toggleOsk();
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
    tooltipText: "Virtual Keyboard & Layout\n" + (root.svc ? root.svc.layoutFullName : "Layout") + " [" + root.currentLayout + "]\nFormát: " + root.currentFormat + "\n[Levý klik: Virtuální klávesnice · Pravý klik: Nastavení & Formáty]"
    horizontalMargin: 8.5
    onPressed: function(buttonCode) { root.triggerPress(buttonCode); }

    Row {
      id: contentRow
      anchors.centerIn: parent
      spacing: Commons.Style.space(4)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "󰌌"
        color: root.oskOpen ? Commons.Color.accent : ((typeof root.bar !== "undefined" && root.bar && root.bar.foreground) ? root.bar.foreground : Commons.Color.foreground)
        font.pixelSize: Commons.Style.bar.iconFont
        font.bold: true
        renderType: Text.NativeRendering
      }

      Text {
        visible: root.showBadge
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.currentLayout
        color: (typeof root.bar !== "undefined" && root.bar && root.bar.foreground) ? root.bar.foreground : Commons.Color.foreground
        font.family: root.svc ? root.svc.monoFont.family : Commons.Style.font.familyMono
        font.pixelSize: Commons.Style.font.caption
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
    active: root.svc ? root.svc.oskOpen : false
    source: (root.svc && root.svc.oskOpen) ? Qt.resolvedUrl("views/OskWindow.qml") : ""
    onLoaded: {
      if (item) {
        item.root = root.svc;
      }
    }
  }
}
