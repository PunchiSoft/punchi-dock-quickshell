// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    objectName: "settingsAboutContent"
    readonly property string applicationVersion: "0.1.23"
    readonly property string repositoryUrl: "https://github.com/PunchiSoft/punchi-dock-quickshell"
    readonly property string helpUrl: repositoryUrl + "/issues"
    readonly property string licenseUrl: "https://www.gnu.org/licenses/gpl-3.0.html"
    function focusFirst(): void { repositoryLink.forceActiveFocus(Qt.OtherFocusReason) }
    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 36
        Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            objectName: "aboutPageHeading"
            text: qsTr("About")
            level: 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            Image {
                objectName: "aboutProjectLogo"
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                source: Qt.resolvedUrl("../../assets/icons/punchi-dock-quickshell.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
                Accessible.name: qsTr("Punchi Dock Quickshell logo")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Heading {
                    objectName: "aboutProjectName"
                    Layout.fillWidth: true
                    text: qsTr("Punchi Dock Quickshell %1").arg(root.applicationVersion)
                    level: 2
                    wrapMode: Text.Wrap
                }
                Label {
                    objectName: "aboutProjectDescription"
                    Layout.fillWidth: true
                    text: qsTr("An animated, configurable dock for KDE Plasma, built with Quickshell and native Qt/KDE integration.")
                    wrapMode: Text.WordWrap
                }
            }
        }

        ToolSeparator { orientation: Qt.Horizontal; Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading { text: qsTr("Website"); level: 3 }
            Kirigami.UrlButton {
                id: repositoryLink
                objectName: "aboutRepositoryLink"
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                horizontalAlignment: Text.AlignLeft
                url: root.repositoryUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading { text: qsTr("Get help"); level: 3 }
            Kirigami.UrlButton {
                objectName: "aboutHelpLink"
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                horizontalAlignment: Text.AlignLeft
                url: root.helpUrl
                text: qsTr("Report an issue")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading { text: qsTr("Copyright"); level: 3 }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("License: GPL-3.0-or-later"); Layout.fillWidth: true }
                Button {
                    objectName: "aboutReadLicense"
                    text: qsTr("Read the license")
                    icon.name: "document-open"
                    onClicked: Qt.openUrlExternally(root.licenseUrl)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading { text: qsTr("Authors"); level: 3 }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Kirigami.Icon {
                    source: "user-identity"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Accessible.ignored: true
                }
                Label {
                    objectName: "aboutAuthors"
                    text: qsTr("PunchiSoft")
                }
            }
        }
    }
}
