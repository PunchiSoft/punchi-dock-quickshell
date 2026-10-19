// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property var windowActions: ({})
    property var virtualDesktops: []
    property string openSubmenu: ""
    signal actionRequested(string action, var virtualDesktop)
    spacing: Kirigami.Units.smallSpacing
    readonly property bool hasWindow: !!windowActions.available
    readonly property bool hasDesktopSubmenu: hasWindow && !!windowActions.desktopChangeable && virtualDesktops.length > 1

    DockContextSeparator { visible: root.hasDesktopSubmenu || root.hasWindow; Layout.fillWidth: true }
    DockContextAction {
        id: desktopAction
        objectName: "moveToDesktopSubmenu"
        Layout.fillWidth: true
        visible: root.hasDesktopSubmenu
        text: qsTr("Move to Desktop")
        icon.name: "virtual-desktops"
        submenu: true
        onClicked: root.openSubmenu = root.openSubmenu === "desktops" ? "" : "desktops"
    }
    DockContextAction {
        objectName: "moveToCurrentDesktopAction"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        visible: root.openSubmenu === "desktops" && root.hasWindow
            && root.virtualDesktops.some(function(desktop) { return desktop.current })
        text: qsTr("Move to Current Desktop")
        marked: !!root.windowActions.available && root.windowActions.virtualDesktops.length === 1
            && root.virtualDesktops.some(function(desktop) {
                return desktop.current && root.windowActions.virtualDesktops.indexOf(desktop.id) >= 0
            })
        enabled: !marked
        onClicked: {
            const desktop = root.virtualDesktops.find(function(candidate) { return candidate.current })
            if (desktop) root.actionRequested("desktop", desktop.id)
        }
    }
    DockContextAction {
        objectName: "allDesktopsAction"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        visible: root.openSubmenu === "desktops" && root.hasWindow
        text: qsTr("All Desktops")
        marked: !!root.windowActions.available && !!root.windowActions.onAllDesktops
        onClicked: root.actionRequested("desktop", [])
    }
    Repeater {
        model: root.virtualDesktops
        delegate: DockContextAction {
            required property var modelData
            required property int index
            objectName: "virtualDesktop-" + modelData.id
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            visible: root.openSubmenu === "desktops" && !modelData.current && root.hasWindow
            text: modelData.name.length > 0 ? modelData.name : qsTr("Desktop %1").arg(index + 1)
            marked: !!root.windowActions.available
                && root.windowActions.virtualDesktops.indexOf(modelData.id) >= 0
            onClicked: root.actionRequested("desktop", modelData.id)
        }
    }
    DockContextAction {
        objectName: "newVirtualDesktopAction"
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        visible: root.openSubmenu === "desktops" && root.hasWindow
        text: qsTr("New Desktop")
        icon.name: "list-add"
        onClicked: root.actionRequested("new-desktop", null)
    }
    DockContextSeparator { visible: root.hasDesktopSubmenu && root.openSubmenu === "desktops"; Layout.fillWidth: true }
    DockContextAction {
        id: moreAction
        objectName: "moreWindowActionsSubmenu"
        Layout.fillWidth: true
        visible: root.hasWindow
        text: qsTr("More")
        icon.name: "view-more-symbolic"
        submenu: true
        onClicked: root.openSubmenu = root.openSubmenu === "window" ? "" : "window"
    }
    Repeater {
        model: [
            {action: "move", key: "movable", label: qsTr("Move"), icon: "transform-move"},
            {action: "resize", key: "resizable", label: qsTr("Resize"), icon: "transform-scale"},
            {action: "maximize", key: "maximizable", check: "maximized", label: qsTr("Maximize"), icon: "window-maximize"},
            {action: "minimize", key: "minimizable", check: "minimized", label: qsTr("Minimize"), icon: "window-minimize"},
            {action: "keep-above", key: "available", check: "keepAbove", label: qsTr("Keep Above Others"), icon: "window-keep-above"},
            {action: "keep-below", key: "available", check: "keepBelow", label: qsTr("Keep Below Others"), icon: "window-keep-below"},
            {action: "fullscreen", key: "fullscreenable", check: "fullscreen", label: qsTr("Fullscreen"), icon: "view-fullscreen"},
            {action: "no-border", key: "canSetNoBorder", check: "noBorder", label: qsTr("No Titlebar and Frame"), icon: "edit-none-border"},
            {action: "hide-capture", key: "canHideFromCapture", check: "excludedFromCapture", label: qsTr("Hide from Screencast"), icon: "view-private"}
        ]
        delegate: DockContextAction {
            required property var modelData
            objectName: "windowAction-" + modelData.action
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.gridUnit
            visible: root.openSubmenu === "window" && root.hasWindow
                && (modelData.action !== "hide-capture" || !!root.windowActions.canHideFromCapture)
            text: modelData.label
            icon.name: modelData.icon
            enabled: !!root.windowActions[modelData.key]
            marked: !!modelData.check && !!root.windowActions[modelData.check]
            onClicked: root.actionRequested(modelData.action, null)
        }
    }
    DockContextSeparator { visible: moreAction.visible; Layout.fillWidth: true }
    DockContextAction {
        id: closeAction
        objectName: "closeWindowAction"
        Layout.fillWidth: true
        visible: root.hasWindow
        enabled: !!root.windowActions.closable
        text: qsTr("Close")
        icon.name: "window-close"
        onClicked: root.actionRequested("close", null)
    }
    DockContextSeparator { visible: closeAction.visible; Layout.fillWidth: true }
}
