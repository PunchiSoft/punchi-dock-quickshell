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
    readonly property bool hasPendingChanges: editor.dirty
        || (autostart !== null && autostart.dirty)
    title: qsTr("Punchi Dock Quickshell — Dock settings")
    visible: false
    width: Math.min(view.implicitWidth, Screen.width - Kirigami.Units.gridUnit * 2)
    height: Math.min(view.implicitHeight, Screen.height * 0.85)
    minimumWidth: Math.min(Kirigami.Units.gridUnit * 40, Screen.width - Kirigami.Units.gridUnit * 2)
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: view.palette.window
    function open(): void {
        if (!visible) {
            editor.begin()
            if (autostart !== null) autostart.begin()
            view.clearSelection()
        }
        show(); raise(); requestActivate(); Qt.callLater(view.focusFirst)
    }
    function keepFocusVisible(): void {
        if (view) Qt.callLater(view.ensureFocusedVisible, root.activeFocusItem)
    }
    onActiveFocusItemChanged: keepFocusVisible()
    onWidthChanged: keepFocusVisible()
    onHeightChanged: keepFocusVisible()
    onClosing: {
        view.cancelAddingItem(false)
        if (autostart !== null) autostart.cancel()
        editor.cancel()
    }
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
