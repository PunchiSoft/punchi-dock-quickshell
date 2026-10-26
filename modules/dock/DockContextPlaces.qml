// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"

ColumnLayout {
    id: root
    property bool motionEnabled: true
    property var places: null
    readonly property int count: places ? places.count : 0
    readonly property int remainingCount: places ? places.remainingCount : 0
    readonly property string groupName: places ? places.groupName : ""
    signal openRequested(string resource)
    signal moreRequested()
    signal groupRequested(string group)
    signal backRequested()
    spacing: Kirigami.Units.smallSpacing
    implicitWidth: Math.max(Kirigami.Units.gridUnit * 12,
        Math.min(files.implicitWidth, Kirigami.Units.gridUnit * 24), moreAction.implicitWidth,
        backAction.visible ? backAction.implicitWidth : 0)

    function focusNavigation(): void {
        Qt.callLater(function() {
            if (backAction.visible) backAction.forceActiveFocus(Qt.MouseFocusReason)
            else if (items.count > 0) items.itemAt(0).forceActiveFocus(Qt.MouseFocusReason)
        })
    }
    DockContextSectionHeader {
        objectName: "placesSectionHeader"
        text: root.groupName.length > 0 ? root.groupName : qsTr("Places")
        Layout.fillWidth: true
    }
    DockContextAction {
        id: backAction
        motionEnabled: root.motionEnabled
        objectName: "backToPlacesAction"
        Layout.fillWidth: true
        visible: root.groupName.length > 0
        text: qsTr("Back to Places")
        icon.name: "go-previous"
        onClicked: { root.backRequested(); root.focusNavigation() }
    }
    ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(files.implicitHeight, measurement.implicitHeight * 8)
        implicitWidth: files.implicitWidth
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: PopupScrollBar { motionEnabled: root.motionEnabled }
        ColumnLayout {
            id: files
            width: parent.width
            spacing: 0
            Repeater {
                id: items
                model: root.places
                delegate: DockContextAction {
                    motionEnabled: root.motionEnabled
                    required property string resource
                    required property string name
                    required property string iconName
                    required property string groupName
                    required property bool isGroup
                    required property bool available
                    objectName: isGroup ? "placeGroup-" + groupName : "place-" + resource
                    Layout.fillWidth: true
                    text: name
                    icon.name: iconName
                    submenu: isGroup
                    enabled: available
                    onClicked: {
                        if (isGroup) { root.groupRequested(groupName); root.focusNavigation() }
                        else root.openRequested(resource)
                    }
                }
            }
        }
    }
    DockContextAction { id: measurement; visible: false }
    DockContextAction {
        id: moreAction
        motionEnabled: root.motionEnabled
        objectName: "morePlacesAction"
        Layout.fillWidth: true
        visible: root.remainingCount > 0
        text: qsTr("%1 more Places…").arg(root.remainingCount)
        icon.name: "view-more-symbolic"
        onClicked: { root.moreRequested(); root.focusNavigation() }
    }
}
