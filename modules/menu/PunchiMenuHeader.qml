// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Header of the fullscreen menu: the distribution identity centred above the
// search entry, with the close affordance pinned to the configured corner.
// Every control is a real focus stop, so the keyboard path never depends on the
// pointer.
Item {
    id: root

    property string distributionName: ""
    property string distributionLogo: ""
    property bool showDistributionName: true
    property string closeButtonPosition: "right"
    property alias searchText: search.text
    property bool motionEnabled: true
    property int searchWidth: Kirigami.Units.gridUnit * 24

    readonly property bool closeOnLeft: root.closeButtonPosition === "left"
    readonly property int controlSize: Kirigami.Units.gridUnit * 2

    signal searchEdited(string text)
    signal closeRequested()
    signal searchFocusRequested()

    function focusSearch(): void {
        search.forceActiveFocus()
    }

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: titleRow.implicitHeight
            visible: root.distributionName.length > 0

            RowLayout {
                id: titleRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    source: root.distributionLogo
                    visible: root.showDistributionName
                        && root.distributionLogo.length > 0 && valid
                    Accessible.ignored: true
                }
                Kirigami.Heading {
                    level: 2
                    text: root.showDistributionName ? root.distributionName : ""
                    Accessible.name: root.distributionName
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            Controls.ToolButton {
                Layout.preferredWidth: root.controlSize
                Layout.preferredHeight: root.controlSize
                visible: root.closeOnLeft
                icon.name: "window-close-symbolic"
                text: qsTr("Close menu")
                Accessible.name: qsTr("Close menu")
                onClicked: root.closeRequested()
            }

            PunchiMenuSearchField {
                id: search
                Layout.preferredWidth: root.searchWidth
                Layout.preferredHeight: root.controlSize
                motionEnabled: root.motionEnabled
                onTextChanged: root.searchEdited(text)
                onCleared: {
                    text = ""
                    root.searchFocusRequested()
                }
                Keys.onEscapePressed: root.closeRequested()
            }

            Controls.ToolButton {
                Layout.preferredWidth: root.controlSize
                Layout.preferredHeight: root.controlSize
                visible: !root.closeOnLeft
                icon.name: "window-close-symbolic"
                text: qsTr("Close menu")
                Accessible.name: qsTr("Close menu")
                onClicked: root.closeRequested()
            }
        }
    }
}
