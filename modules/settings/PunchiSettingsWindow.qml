// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"

Window {
    id: root
    required property PunchiShellSettings settings
    property var applicationCatalog: null
    property var autostart: null
    property var license: null
    property var recentApplications: null
    property var updates: null
    property var screens: []
    property string primaryScreenName: ""
    property var runningApplications: null
    readonly property bool hasPendingChanges: editor.dirty
        || (autostart !== null && autostart.dirty)
    // The settings view builds every page at once. Load it on the first open so
    // a shell that never opens settings does not keep that tree alive; it stays
    // loaded afterwards, so close/reopen keeps the established view state.
    property bool viewRequested: false
    readonly property var view: settingsViewLoader.item
    title: qsTr("Punchi Dock Quickshell — Dock settings")
    visible: false
    readonly property real preferredWidth: Math.min(root.view
        ? root.view.implicitWidth : Kirigami.Units.gridUnit * 38,
        Screen.width - Kirigami.Units.gridUnit * 2)
    // Fixed height reference: pages scroll instead of resizing the window when
    // optional screen, desktop or activity rows appear.
    readonly property real preferredHeight: Math.min(Kirigami.Units.gridUnit * 38,
        Screen.height * 0.85)
    width: preferredWidth
    height: preferredHeight
    minimumWidth: Math.min(Kirigami.Units.gridUnit * 38, Screen.width - Kirigami.Units.gridUnit * 2)
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: root.view ? root.view.palette.window : Kirigami.Theme.backgroundColor
    // A compositor resize replaces the width/height binding. Reinstall the
    // established Kirigami size when the window is opened again instead of
    // treating the last dragged geometry as the new default.
    function applyDefaultGeometry(): void {
        if (visibility === Window.Maximized || visibility === Window.FullScreen)
            showNormal()
        width = Qt.binding(function() { return root.preferredWidth })
        height = Qt.binding(function() { return root.preferredHeight })
    }
    function open(): void {
        if (!root.viewRequested)
            root.viewRequested = true
        const wasVisible = visible
        if (!wasVisible) {
            editor.begin()
            if (autostart !== null) autostart.begin()
            if (root.view) root.view.clearSelection()
            applyDefaultGeometry()
        }
        show(); raise(); requestActivate()
        if (!wasVisible) Qt.callLater(root.applyDefaultGeometry)
        if (root.view) Qt.callLater(function() { if (root.view) root.view.focusFirst() })
    }
    function keepFocusVisible(): void {
        if (root.view) Qt.callLater(function() {
            if (root.view) root.view.ensureFocusedVisible(root.activeFocusItem)
        })
    }
    onActiveFocusItemChanged: keepFocusVisible()
    onWidthChanged: {
        if (visible && width < minimumWidth) {
            width = minimumWidth
            return
        }
        keepFocusVisible()
    }
    onHeightChanged: {
        if (visible && height < minimumHeight) {
            height = minimumHeight
            return
        }
        keepFocusVisible()
    }
    onClosing: {
        if (root.view) root.view.cancelAddingItem(false)
        if (autostart !== null) autostart.cancel()
        editor.cancel()
    }
    // Destroying the view while focus/layout callbacks are still queued logs
    // warnings and fails the settings tests. Release it only after a short
    // closed grace period; reopening cancels the timer.
    Timer {
        id: viewReleaseTimer
        interval: 1000
        repeat: false
        onTriggered: if (!root.visible && root.viewRequested) root.viewRequested = false
    }
    onVisibleChanged: {
        if (visible) viewReleaseTimer.stop()
        else if (root.viewRequested) viewReleaseTimer.restart()
    }
    Component.onCompleted: applyDefaultGeometry()
    PunchiSettingsEditService { id: editor; settings: root.settings }
    Shortcut {
        sequence: "Escape"
        enabled: !(root.view && (root.view.addingItem || root.view.aboutDialogOpen))
        onActivated: root.close()
    }
    Loader {
        id: settingsViewLoader
        anchors.fill: parent
        active: root.viewRequested
        sourceComponent: Component {
            PunchiSettingsView {
                settings: editor.draft
                autostart: root.autostart
                license: root.license
                recentApplications: root.recentApplications
                updates: root.updates
                screens: root.screens
                primaryScreenName: root.primaryScreenName
                runningApplications: root.runningApplications
                hasPendingChanges: root.hasPendingChanges
                applicationCatalog: root.applicationCatalog
                onApplyRequested: {
                    editor.apply()
                    if (root.autostart !== null) root.autostart.apply()
                }
                onAcceptRequested: {
                    editor.apply()
                    if (root.autostart === null || root.autostart.apply()) root.close()
                }
                onCloseRequested: root.close()
            }
        }
        onLoaded: {
            if (!root.visible) return
            root.applyDefaultGeometry()
            if (root.view) root.view.focusFirst()
        }
    }
}
