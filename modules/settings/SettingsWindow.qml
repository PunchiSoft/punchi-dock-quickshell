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
    readonly property bool hasPendingChanges: editor.dirty
    title: qsTr("Punchi Dock Quickshell — Dock settings")
    visible: false
    width: view.implicitWidth
    height: Math.min(view.implicitHeight, Screen.height * 0.85)
    minimumWidth: Kirigami.Units.gridUnit * 34
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: view.palette.window
    function open(): void {
        if (!visible) editor.begin()
        show(); raise(); requestActivate(); Qt.callLater(view.focusFirst)
    }
    function keepFocusVisible(): void {
        if (view) Qt.callLater(view.ensureFocusedVisible, root.activeFocusItem)
    }
    onActiveFocusItemChanged: keepFocusVisible()
    onWidthChanged: keepFocusVisible()
    onHeightChanged: keepFocusVisible()
    onClosing: { view.closeDialogs(); editor.cancel() }
    SettingsEditService { id: editor; settings: root.settings }
    Shortcut { sequence: "Escape"; enabled: !view.addingItem; onActivated: root.close() }
    SettingsView {
        id: view
        anchors.fill: parent
        settings: editor.draft
        hasPendingChanges: editor.dirty
        applicationCatalog: root.applicationCatalog
        onApplyRequested: editor.apply()
        onAcceptRequested: { editor.apply(); root.close() }
        onCloseRequested: root.close()
    }
}
