// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml.Models

ListModel {
    ListElement {
        appId: "files"
        desktopId: "org.kde.dolphin"
        title: qsTr("Files")
        iconName: "system-file-manager"
    }
    ListElement {
        appId: "terminal"
        desktopId: "org.kde.konsole"
        title: qsTr("Terminal")
        iconName: "utilities-terminal"
    }
    ListElement {
        appId: "browser"
        desktopId: "org.mozilla.firefox"
        title: qsTr("Browser")
        iconName: "internet-web-browser"
    }
    ListElement {
        appId: "kate"
        desktopId: "org.kde.kate"
        title: qsTr("Kate")
        iconName: "kate"
    }
    ListElement {
        appId: "systemsettings"
        desktopId: "systemsettings"
        title: qsTr("System Settings")
        iconName: "preferences-system"
    }
    ListElement {
        appId: "discover"
        desktopId: "org.kde.discover"
        title: qsTr("Discover")
        iconName: "plasmadiscover"
    }
    ListElement {
        appId: "gwenview"
        desktopId: "org.kde.gwenview"
        title: qsTr("Gwenview")
        iconName: "gwenview"
    }
    ListElement {
        appId: "okular"
        desktopId: "org.kde.okular"
        title: qsTr("Okular")
        iconName: "okular"
    }
}
