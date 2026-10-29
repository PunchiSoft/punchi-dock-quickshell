// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PunchiDefaultProfile.js" as PunchiDefaultProfile
import "../../services"
import "../../adapters/kde"

// Fullscreen application menu on one screen. It is an overlay layer surface
// that takes the keyboard only while it is open, so the dock keeps its own
// input and the desktop is never stolen while the menu is closed.
PanelWindow {
    id: root

    required property PunchiShellSettings settings
    required property var menuController
    required property var applications
    property var distribution: null

    readonly property string screenKey: root.screen ? root.screen.name : ""
    readonly property bool open: root.menuController
        ? root.menuController.isOpen(root.screenKey) : false
    // The shell assigns `settings` while the delegate is being created, so a
    // binding can be evaluated once before that assignment. The profile default
    // keeps those first evaluations silent and identical to the stored value.
    readonly property var profileDefaults: PunchiDefaultProfile.profile
    readonly property bool motionEnabled: !(root.settings
        ? root.settings.reducedMotion : root.profileDefaults.reducedMotion)
    readonly property int gridColumns: Math.max(4, Math.min(8,
        Math.floor(Math.max(1, root.width) / (Kirigami.Units.gridUnit * 7))))
    readonly property int gridRows: Math.max(3, Math.min(5,
        Math.floor(Math.max(1, content.height - header.height)
            / (Kirigami.Units.gridUnit * 6))))
    readonly property string distributionName: root.distribution
        ? String(root.distribution.name || "") : ""
    readonly property string distributionLogo: root.distribution
        ? String(root.distribution.logo || "") : ""

    signal applicationLaunched(string appId)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Stay mapped while the closing fade runs, then leave the compositor alone.
    visible: root.open || backdrop.opacity > 0.001
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "punchi-menu"
    WlrLayershell.keyboardFocus: root.open
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // The launch adapter needs the surface that received the click: on Wayland
    // the activation token comes from a visible window, so it belongs to this
    // menu surface and not to a shared service.
    PunchiDesktopApplicationAdapter {
        id: launchAdapter
        activationItem: content
    }
    PunchiApplicationLaunchService {
        id: launcher
        entries: root.applications
        adapter: launchAdapter
        onLaunchDispatched: function(appId) { root.applicationLaunched(appId) }
        onLaunchRejected: function(appId) {
            console.warn("Punchi Dock Quickshell: menu launch rejected:", appId)
        }
        onLaunchCompleted: function(desktopId, success, error) {
            if (!success) console.warn("Punchi Dock Quickshell: menu launch failed:", desktopId, error)
        }
    }
    PunchiMenuState {
        id: menuState
        applications: root.applications
        columns: root.gridColumns
        rows: root.gridRows
    }

    PunchiMenuBackdrop {
        id: backdrop
        active: root.open
        blurEnabled: root.settings
            ? root.settings.menuBackgroundBlurEnabled
            : root.profileDefaults.menuBackgroundBlurEnabled
        backgroundOpacity: root.settings
            ? root.settings.menuBackgroundOpacity
            : root.profileDefaults.menuBackgroundOpacity
        motionEnabled: root.motionEnabled
        onClicked: root.menuController.close()
    }

    FocusScope {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.gridUnit * 3
        anchors.rightMargin: Kirigami.Units.gridUnit * 3
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.bottomMargin: Kirigami.Units.gridUnit * 4
        opacity: root.open ? 1.0 : 0.0
        scale: root.open || !root.motionEnabled ? 1.0 : 0.97
        transformOrigin: Item.Center
        focus: root.open

        Behavior on opacity {
            enabled: root.motionEnabled
            NumberAnimation {
                duration: root.open ? Kirigami.Units.longDuration
                    : Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            enabled: root.motionEnabled
            NumberAnimation {
                duration: root.open ? Kirigami.Units.longDuration
                    : Kirigami.Units.shortDuration
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: layout
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            PunchiMenuHeader {
                id: header
                width: parent.width
                distributionName: root.distributionName
                distributionLogo: root.distributionLogo
                showDistributionName: root.settings
                    ? root.settings.menuShowDistributionName
                    : root.profileDefaults.menuShowDistributionName
                closeButtonPosition: root.settings
                    ? root.settings.menuCloseButtonPosition
                    : root.profileDefaults.menuCloseButtonPosition
                motionEnabled: root.motionEnabled
                searchText: menuState.searchText
                onSearchEdited: function(text) { menuState.searchText = text }
                onCloseRequested: root.menuController.close()
                onSearchFocusRequested: header.focusSearch()
            }

            PunchiMenuGrid {
                id: grid
                width: parent.width
                height: Math.max(0, layout.height - header.height
                    - layout.spacing)
                menuState: menuState
                active: root.open
                motionEnabled: root.motionEnabled
                showLabels: root.settings
                    ? root.settings.menuShowLabels : root.profileDefaults.menuShowLabels
                showPageArrows: root.settings
                    ? root.settings.menuShowPageArrows
                    : root.profileDefaults.menuShowPageArrows
                iconScale: root.settings
                    ? root.settings.menuIconScale : root.profileDefaults.menuIconScale
                hoverAnimation: root.settings
                    ? root.settings.menuHoverAnimation
                    : root.profileDefaults.menuHoverAnimation
                onLaunchRequested: function(index) {
                    const application = menuState.filtered[index]
                    if (!application) return
                    const appId = String(application.appId || "")
                    if (appId.length === 0) return
                    launcher.launch(appId)
                    root.menuController.close()
                }
            }
        }

        Keys.onEscapePressed: root.menuController.close()
        Keys.onLeftPressed: { grid.takeKeyboardEmphasis(); menuState.moveHorizontal(-1) }
        Keys.onRightPressed: { grid.takeKeyboardEmphasis(); menuState.moveHorizontal(1) }
        Keys.onUpPressed: { grid.takeKeyboardEmphasis(); menuState.moveVertical(-1) }
        Keys.onDownPressed: { grid.takeKeyboardEmphasis(); menuState.moveVertical(1) }
        Keys.onPressed: function(event) {
            grid.takeKeyboardEmphasis()
            if (event.key === Qt.Key_PageDown) { menuState.selectPage(1); event.accepted = true }
            else if (event.key === Qt.Key_PageUp) { menuState.selectPage(-1); event.accepted = true }
            else if (event.key === Qt.Key_Home) { menuState.selectFirst(); event.accepted = true }
            else if (event.key === Qt.Key_End) { menuState.selectLast(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const application = menuState.currentApplication
                if (application) {
                    const appId = String(application.appId || "")
                    if (appId.length > 0) {
                        launcher.launch(appId)
                        root.menuController.close()
                    }
                }
                event.accepted = true
            } else if (event.text.length > 0
                    && !header.searchText.length && !header.activeFocus
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                header.focusSearch()
            }
        }

        Connections {
            // A `var` property starts as undefined, and assigning that to a
            // QObject target warns; an explicit null keeps the first evaluation
            // silent until the shell sets the controller.
            target: root.menuController !== undefined ? root.menuController : null
            ignoreUnknownSignals: true
            function onOpened(screenKey) {
                if (screenKey !== root.screenKey) return
                menuState.reset()
                Qt.callLater(header.focusSearch)
            }
        }
    }
}
