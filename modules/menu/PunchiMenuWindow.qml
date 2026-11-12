// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import "../../config"
import "../../config/PunchiDefaultProfile.js" as PunchiDefaultProfile
import "../../services"
import "../../adapters/kde"

// Fullscreen application menu on one screen. It is a layer surface that takes
// the keyboard only while it is open, so the dock keeps its own input and the
// desktop is never stolen while the menu is closed. When the dock stays over the
// menu, the menu uses the top layer so the dock can take the overlay layer above
// it; otherwise the menu keeps the overlay layer.
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
    // The view fits the seven-column, five-row reference with a proportional
    // scale, so the column count only drops on a screen too narrow for the
    // reference pitch. The cells stay rectangular; the square selection card
    // lives inside each cell.
    readonly property int gridColumns: Math.max(4, Math.min(7,
        Math.floor(Math.max(1, root.width) / (Kirigami.Units.gridUnit * 8))))
    readonly property string distributionName: root.distribution
        ? String(root.distribution.name || "") : ""
    readonly property string distributionLogo: root.distribution
        ? String(root.distribution.logo || "") : ""
    // The dock keeps its position over the full-screen menu, as in the
    // reference: layer-shell stacks the overlay layer above the top layer, so
    // the menu yields the overlay to the dock while it is open and takes it back
    // after the menu closes.
    readonly property bool dockOverMenu: root.settings
        ? root.settings.menuShowDock : root.profileDefaults.menuShowDock

    // The surface outlives `open` for the closing fade, and the dock has to stay
    // above it for that whole time.
    onVisibleChanged: {
        if (!root.open && contextMenu) contextMenu.close()
        if (root.menuController)
            root.menuController.setMapped(root.screenKey, root.visible)
    }
    Component.onDestruction: if (root.menuController)
        root.menuController.setMapped(root.screenKey, false)

    function openApplication(appId: string): void {
        if (!appId || appId.length === 0) return
        launcher.launch(appId)
        root.menuController.close()
    }
    function showContextMenu(index: int, position: point): void {
        const application = menuState.filtered[index]
        if (!application) return
        const appId = String(application.appId || "")
        if (appId.length === 0) return
        contextMenu.applicationId = appId
        contextMenu.pinned = pinService.isPinned(appId)
        const local = content.mapFromItem(null, position.x, position.y)
        contextMenu.popup(local.x, local.y)
    }
    function togglePin(): void {
        if (contextMenu.applicationId.length === 0) return
        if (contextMenu.pinned)
            pinService.unpinApp(contextMenu.applicationId)
        else
            pinService.pinApp(contextMenu.applicationId)
        contextMenu.pinned = pinService.isPinned(contextMenu.applicationId)
    }

    signal applicationLaunched(string appId)

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    // No `exclusiveZone`: assigning it forces ExclusionMode.Normal, which places
    // the surface inside the area other panels reserved instead of covering the
    // screen. Ignore reserves nothing and ignores their reservations.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Stay mapped while the closing fade runs, then leave the compositor alone.
    visible: root.open || backdrop.opacity > 0.001
    WlrLayershell.layer: root.dockOverMenu ? WlrLayer.Top : WlrLayer.Overlay
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
        applicationOrder: root.settings
            ? root.settings.menuApplicationOrder
            : root.profileDefaults.menuApplicationOrder
    }
    PunchiApplicationPinService {
        id: pinService
        settings: root.settings
        catalog: root.applications
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

            PunchiMenuSections {
                id: sections
                width: parent.width
                height: Math.max(0, layout.height - header.height
                    - layout.spacing)
                menuState: menuState
                active: root.open
                motionEnabled: root.motionEnabled
                showLabels: root.settings
                    ? root.settings.menuShowLabels : root.profileDefaults.menuShowLabels
                showScrollBar: root.settings
                    ? root.settings.menuShowScrollBar
                    : root.profileDefaults.menuShowScrollBar
                iconScale: root.settings
                    ? root.settings.menuIconScale : root.profileDefaults.menuIconScale
                hoverAnimation: root.settings
                    ? root.settings.menuHoverAnimation
                    : root.profileDefaults.menuHoverAnimation
                onLaunchRequested: function(index) {
                    const application = menuState.filtered[index]
                    if (!application) return
                    root.openApplication(String(application.appId || ""))
                }
                onContextMenuRequested: function(index, position) {
                    root.showContextMenu(index, position)
                }
            }
        }

        Controls.Menu {
            id: contextMenu
            objectName: "menuContextMenu"
            property string applicationId: ""
            property bool pinned: false
            Controls.MenuItem {
                text: qsTr("Open")
                icon.name: "document-open"
                onTriggered: root.openApplication(contextMenu.applicationId)
            }
            Controls.MenuSeparator {
                visible: contextMenu.pinned || pinService.canPinApp(contextMenu.applicationId)
            }
            Controls.MenuItem {
                text: contextMenu.pinned ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
                icon.name: contextMenu.pinned ? "window-unpin" : "window-pin"
                visible: contextMenu.pinned || pinService.canPinApp(contextMenu.applicationId)
                onTriggered: root.togglePin()
            }
        }

        Keys.onEscapePressed: root.menuController.close()
        Keys.onLeftPressed: { sections.takeKeyboardEmphasis(); menuState.moveHorizontal(-1) }
        Keys.onRightPressed: { sections.takeKeyboardEmphasis(); menuState.moveHorizontal(1) }
        Keys.onUpPressed: { sections.takeKeyboardEmphasis(); menuState.moveVertical(-1) }
        Keys.onDownPressed: { sections.takeKeyboardEmphasis(); menuState.moveVertical(1) }
        Keys.onPressed: function(event) {
            sections.takeKeyboardEmphasis()
            if (event.key === Qt.Key_PageDown) { menuState.selectPage(1); event.accepted = true }
            else if (event.key === Qt.Key_PageUp) { menuState.selectPage(-1); event.accepted = true }
            else if (event.key === Qt.Key_Home) { menuState.selectFirst(); event.accepted = true }
            else if (event.key === Qt.Key_End) { menuState.selectLast(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const application = menuState.currentApplication
                if (application) {
                    const appId = String(application.appId || "")
                    if (appId.length > 0) root.openApplication(appId)
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
