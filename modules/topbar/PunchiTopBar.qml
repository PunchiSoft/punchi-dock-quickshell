// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../config"

// Quickshell host of the top panel for one screen. The surface is anchored to
// the top edge, reserves the bar height while the panel is enabled, and keeps
// the transparent allocation input-transparent outside the bar and the open
// popup. The view is a plain Qt Quick item; this file owns the window concerns.
PanelWindow {
    id: root
    required property PunchiShellSettings settings
    required property var services
    property var menuController: null
    signal settingsRequested()
    readonly property string screenKey: root.screen ? root.screen.name : ""
    readonly property bool windowAllowed: root.settings.topBarEnabled
    // Observable host state for the session probe and the shell composition.
    readonly property int reservedHeight: view.barHeight
    readonly property bool popupOpen: view.popupOpen
    visible: root.windowAllowed
    anchors.top: root.windowAllowed
    anchors.left: root.windowAllowed
    anchors.right: root.windowAllowed
    exclusiveZone: root.windowAllowed ? view.barHeight : 0
    exclusionMode: root.windowAllowed ? ExclusionMode.Normal : ExclusionMode.Ignore
    implicitWidth: root.screen ? root.screen.width : 1
    implicitHeight: root.windowAllowed && root.screen ? root.screen.height : 1
    color: "transparent"
    // A top panel stays above normal windows like the Plasma panel. Fullscreen
    // and maximized coexistence is a session observation recorded in the change
    // evidence, not an assumption of this window.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "punchi-topbar"
    WlrLayershell.keyboardFocus: root.windowAllowed && view.popupOpen
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // The full-screen allocation is transparent; only the bar and the open
    // popup accept input, and the popup is clamped inside the same screen.
    mask: Region {
        Region {
            x: 0
            y: 0
            width: root.windowAllowed ? root.width : 0
            height: root.windowAllowed ? view.barHeight : 0
        }
        Region {
            x: root.windowAllowed ? view.popupRegion.x : 0
            y: root.windowAllowed ? view.popupRegion.y : 0
            width: root.windowAllowed ? view.popupRegion.width : 0
            height: root.windowAllowed ? view.popupRegion.height : 0
        }
    }
    onWindowAllowedChanged: if (!root.windowAllowed) view.closePopups()
    PunchiTopBarView {
        id: view
        objectName: "topBarView"
        width: root.width
        height: root.height
        now: root.services ? root.services.clock.date : new Date()
        controls: root.services
        reducedMotion: root.settings.effectiveReducedMotion
        screenName: root.screenKey
        onApplicationsRequested: {
            if (root.menuController && root.screenKey.length > 0)
                root.menuController.toggle(root.screenKey)
        }
        onDockSettingsRequested: root.settingsRequested()
        onKrunnerRequested: if (root.services) root.services.launchKRunner()
        onBluetoothPairingRequested: if (root.services) root.services.launchBluetoothWizard()
        onSettingsModuleRequested: function(module) {
            if (root.services) root.services.openSettingsModule(module)
        }
    }
}
