// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"

Window {
    id: root
    required property ShellSettings settings
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
    title: qsTr("Punchi Dock Quickshell — Dock settings")
    visible: false
    readonly property real preferredWidth: Math.min(view.implicitWidth,
        Screen.width - Kirigami.Units.gridUnit * 2)
    // Fixed height reference: pages scroll instead of resizing the window when
    // optional screen, desktop or activity rows appear.
    readonly property real preferredHeight: Math.min(Kirigami.Units.gridUnit * 38,
        Screen.height * 0.85)
    width: preferredWidth
    height: preferredHeight
    minimumWidth: Math.min(Kirigami.Units.gridUnit * 38, Screen.width - Kirigami.Units.gridUnit * 2)
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: view.palette.window
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
        const wasVisible = visible
        if (!wasVisible) {
            editor.begin()
            if (autostart !== null) autostart.begin()
            view.clearSelection()
            applyDefaultGeometry()
        }
        show(); raise(); requestActivate()
        if (!wasVisible) Qt.callLater(root.applyDefaultGeometry)
        Qt.callLater(view.focusFirst)
    }
    function keepFocusVisible(): void {
        if (view) Qt.callLater(view.ensureFocusedVisible, root.activeFocusItem)
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
        view.cancelAddingItem(false)
        if (autostart !== null) autostart.cancel()
        editor.cancel()
    }
    Component.onCompleted: applyDefaultGeometry()
    SettingsEditService { id: editor; settings: root.settings }
    Shortcut {
        sequence: "Escape"
        enabled: !view.addingItem && !view.aboutDialogOpen
        onActivated: root.close()
    }
    SettingsView {
        id: view
        anchors.fill: parent
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
