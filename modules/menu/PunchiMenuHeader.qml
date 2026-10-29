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

    implicitHeight: Math.max(content.implicitHeight, root.controlSize)

    // Pinned to the surface corner instead of the centred row: the original menu
    // kept one close affordance in the configured corner and let the header stay
    // symmetrical.
    Controls.ToolButton {
        objectName: "menuCloseButton"
        anchors.top: parent.top
        anchors.left: root.closeOnLeft ? parent.left : undefined
        anchors.right: root.closeOnLeft ? undefined : parent.right
        width: root.controlSize
        height: root.controlSize
        icon.name: "window-close-symbolic"
        text: qsTr("Close menu")
        Accessible.name: qsTr("Close menu")
        focusPolicy: Qt.StrongFocus
        onClicked: root.closeRequested()
    }

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
        }
    }
}
