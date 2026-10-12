// SPDX-License-Identifier: GPL-3.0-or-later
// Shares the tooltip balloon silhouette with compact themed menu rows.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../components"
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root
    property string itemName: ""
    property var actions: []
    property var recentDocuments: null
    property var places: null
    property bool usesPlaces: false
    property bool canLaunchNewWindow: false
    property bool pinned: false
    property real pointerX: width / 2
    readonly property real pointerHeight: Kirigami.Units.largeSpacing
    readonly property real pointerCenter: surface.pointerCenter
    readonly property real contentPadding: Kirigami.Units.largeSpacing
    signal actionRequested(string actionId)
    signal placeRequested(string resource)
    signal morePlacesRequested()
    signal placesGroupRequested(string group)
    signal placesBackRequested()
    signal recentRequested(string resource)
    signal forgetRecentRequested()
    signal newWindowRequested()
    signal unpinRequested()
    signal settingsRequested()
    signal closeRequested()
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    readonly property real labelWidth: actions.reduce(function(width, action) {
        return Math.max(width, labelMetrics.advanceWidth(action.name))
    }, labelMetrics.advanceWidth(configureAction.text))
    implicitWidth: Math.max(Kirigami.Units.gridUnit * 12,
        labelWidth + Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 6 + contentPadding * 2,
        recentContent.visible ? Math.min(recentContent.implicitWidth, Kirigami.Units.gridUnit * 24) + contentPadding * 2 : 0,
        placesContent.visible ? placesContent.implicitWidth + contentPadding * 2 : 0,
        canLaunchNewWindow ? newWindowAction.implicitWidth + contentPadding * 2 : 0,
        pinned ? unpinAction.implicitWidth + contentPadding * 2 : 0)
    FontMetrics { id: labelMetrics; font: configureAction.font }
    implicitHeight: rows.implicitHeight + contentPadding * 2 + pointerHeight
    width: implicitWidth
    height: implicitHeight

    function focusFirst() { configureAction.forceActiveFocus(Qt.PopupFocusReason) }
    Keys.onEscapePressed: root.closeRequested()

    BalloonSurface {
        id: surface
        objectName: "dockContextSurface"
        anchors.fill: parent
        pointerX: root.pointerX
        tailHeight: root.pointerHeight
    }
    ColumnLayout {
        id: rows
        anchors.fill: parent
        anchors.leftMargin: root.contentPadding
        anchors.rightMargin: root.contentPadding
        anchors.topMargin: root.contentPadding
        anchors.bottomMargin: root.contentPadding + root.pointerHeight
        spacing: Kirigami.Units.smallSpacing
        DockContextPlaces {
            id: placesContent
            Layout.fillWidth: true
            places: root.places
            visible: root.usesPlaces
            onOpenRequested: function(resource) { root.placeRequested(resource) }
            onMoreRequested: root.morePlacesRequested()
            onGroupRequested: function(group) { root.placesGroupRequested(group) }
            onBackRequested: root.placesBackRequested()
        }
        DockContextRecentFiles {
            id: recentContent
            Layout.fillWidth: true
            documents: root.recentDocuments
            visible: !root.usesPlaces && count > 0
            onOpenRequested: function(resource) { root.recentRequested(resource) }
            onForgetRequested: root.forgetRecentRequested()
        }
        DockContextSectionHeader {
            visible: recentContent.visible || placesContent.visible
            text: qsTr("Actions")
            Layout.fillWidth: true
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(6, root.actions.length) * configureAction.implicitHeight
            visible: root.actions.length > 0
            clip: true
            ListView {
                model: root.actions
                boundsBehavior: Flickable.StopAtBounds
                delegate: DockContextAction {
                    id: desktopAction
                    required property var modelData
                    objectName: "desktopAction-" + modelData.actionId
                    width: ListView.view.width
                    height: implicitHeight
                    text: modelData.name
                    icon.name: modelData.icon || "system-run"
                    onClicked: root.actionRequested(modelData.actionId)
                }
            }
        }
        DockContextAction {
            id: newWindowAction
            objectName: "openNewWindowAction"
            Layout.fillWidth: true
            visible: root.canLaunchNewWindow
            text: qsTr("Open New Window")
            icon.name: "window-new"
            onClicked: root.newWindowRequested()
        }
        DockContextAction {
            id: unpinAction
            objectName: "unpinDockAction"
            Layout.fillWidth: true
            visible: root.pinned
            text: qsTr("Unpin from Dock")
            icon.name: "window-unpin"
            onClicked: root.unpinRequested()
        }
        DockContextSeparator {
            visible: root.actions.length > 0 || root.canLaunchNewWindow || root.pinned || recentContent.visible || placesContent.visible
            Layout.fillWidth: true
        }
        DockContextAction {
            id: configureAction
            objectName: "configureDockAction"
            Layout.fillWidth: true
            text: qsTr("Configure Dock")
            icon.name: "preferences-system"
            onClicked: root.settingsRequested()
        }
    }
}
