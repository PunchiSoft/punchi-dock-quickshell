// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    objectName: "settingsAboutContent"
    readonly property string applicationVersion: "0.1.25"
    readonly property string repositoryUrl: "https://github.com/PunchiSoft/punchi-dock-quickshell"
    readonly property string helpUrl: repositoryUrl + "/issues"
    property string licenseText: ""
    readonly property bool licenseAvailable: licenseText.length > 0
    signal licenseReadRequested()
    function focusFirst(): void { repositoryLink.forceActiveFocus(Qt.OtherFocusReason) }
    function focusLicenseButton(): void { readLicenseButton.forceActiveFocus(Qt.OtherFocusReason) }
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

        SettingsCard {
            Layout.fillWidth: true
            title: qsTr("Website")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Kirigami.UrlButton {
                    id: repositoryLink
                    objectName: "aboutRepositoryLink"
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignLeft
                    url: root.repositoryUrl
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            title: qsTr("Get help")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                Kirigami.UrlButton {
                    objectName: "aboutHelpLink"
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignLeft
                    url: root.helpUrl
                    text: qsTr("Report an issue")
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            title: qsTr("Copyright")
            SettingsRow {
                Layout.fillWidth: true
                text: qsTr("License: GPL-3.0-or-later")
                showSeparator: false
                Button {
                    id: readLicenseButton
                    objectName: "aboutReadLicense"
                    text: qsTr("Read the license")
                    icon.name: "document-open"
                    enabled: root.licenseAvailable
                    onClicked: root.licenseReadRequested()
                }
            }
        }

        SettingsCard {
            Layout.fillWidth: true
            title: qsTr("Authors")
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
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
}
