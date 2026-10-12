// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import "../../config"
import "../../services"

Window {
    id: root
    required property ShellSettings settings
    property var applicationCatalog: null
    readonly property bool hasPendingChanges: editor.dirty
    title: qsTr("Punchi Shell — Dock settings")
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
    onClosing: { view.closeDialogs(); editor.cancel() }
    SettingsEditService { id: editor; settings: root.settings }
    Shortcut { sequence: "Escape"; enabled: !view.addingApplication; onActivated: root.close() }
    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        SettingsView {
            id: view
            width: parent.width
            settings: editor.draft
            hasPendingChanges: editor.dirty
            applicationCatalog: root.applicationCatalog
            onApplyRequested: editor.apply()
            onAcceptRequested: { editor.apply(); root.close() }
            onCloseRequested: root.close()
        }
    }
}
