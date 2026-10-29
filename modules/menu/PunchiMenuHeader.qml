// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../components"
import "../../adapters/kde"

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
    // Roughly a fifth of the surface, as in the reference, with a floor a
    // placeholder still fits and a ceiling that stops it spanning the menu.
    property int searchWidth: Math.round(Math.max(Kirigami.Units.gridUnit * 12,
        Math.min(Kirigami.Units.gridUnit * 26, width * 0.18)))

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
    PunchiDecorationButton {
        objectName: "menuCloseButton"
        anchors.top: parent.top
        anchors.left: root.closeOnLeft ? parent.left : undefined
        anchors.right: root.closeOnLeft ? undefined : parent.right
        width: root.controlSize
        height: root.controlSize
        role: "close"
        // The decoration of the user's window, with a theme icon as fallback so the
        // control is never invisible when the decoration ships no button.
        decorationImagePath: decorationButtons.pathFor("close")
        decorationButtonSize: decorationButtons.buttonSize
        fallbackIconName: "window-close"
        activePointerStates: true
        text: qsTr("Close menu")
        Accessible.name: qsTr("Close menu")
        onClicked: root.closeRequested()
    }
    PunchiDecorationButtonProvider { id: decorationButtons }

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
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    roundToIconSize: true
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
