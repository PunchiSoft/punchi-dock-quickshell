// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property bool motionEnabled: true
    property bool pointerEmphasis: true
    property var documents: null
    readonly property int count: documents ? documents.count : 0
    signal openRequested(string resource)
    signal forgetRequested()
    spacing: Kirigami.Units.smallSpacing
    implicitWidth: Math.max(Kirigami.Units.gridUnit * 12, files.implicitWidth, forgetAction.implicitWidth)
    PunchiDockContextSectionHeader {
        text: qsTr("Recent Files")
        Layout.fillWidth: true
    }
    ColumnLayout {
        id: files
        spacing: 0
        Layout.fillWidth: true
        Repeater {
            model: root.documents
            delegate: PunchiDockContextAction {
                pointerEmphasis: root.pointerEmphasis
                motionEnabled: root.motionEnabled
                required property string resource
                required property string name
                required property string iconName
                objectName: "recentDocument-" + resource
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                text: name
                icon.name: iconName
                onClicked: root.openRequested(resource)
            }
        }
    }
    PunchiDockContextSeparator { Layout.fillWidth: true }
    PunchiDockContextAction {
        pointerEmphasis: root.pointerEmphasis
        id: forgetAction
        motionEnabled: root.motionEnabled
        objectName: "forgetRecentAction"
        text: qsTr("Forget Recent Files")
        icon.name: "edit-clear-history"
        Layout.fillWidth: true
        onClicked: root.forgetRequested()
    }
}
