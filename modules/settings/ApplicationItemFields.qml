// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Application fields of the add-item editor: the search row, its overlay results,
// the icon button and the description of the selected application. Results are
// opt-in: typing filters the applications and the search button reveals them all.
ColumnLayout {
    id: root
    required property var controller
    required property real labelWidth
    property bool browsing: false
    property bool resultsDismissed: false
    readonly property bool listVisible: !root.resultsDismissed
        && (root.browsing || root.controller.query.length > 0)
    signal searchRequested(string text)
    signal selectionRequested(string appId)
    signal iconChooserRequested()

    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing

    function focusSearch(reason: int): void {
        search.forceActiveFocus(reason)
    }
    function focusIconButton(): void {
        iconButton.forceActiveFocus(Qt.TabFocusReason)
    }
    function reset(): void {
        root.browsing = false
        root.resultsDismissed = false
    }
    function chooseApplication(appId: string): void {
        root.selectionRequested(appId)
        root.resultsDismissed = true
        search.forceActiveFocus(Qt.TabFocusReason)
    }

    // The results panel is created only when the user types or asks for the whole
    // list, so the form opens without it.
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Label {
            objectName: "applicationNameFieldLabel"
            text: qsTr("Name:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        TextField {
            id: search
            objectName: "applicationSearch"
            Layout.fillWidth: true
            placeholderText: qsTr("Type the application name or alias")
            Accessible.name: qsTr("Search applications")
            text: root.controller.query
            onTextEdited: {
                root.browsing = false
                root.resultsDismissed = false
                root.searchRequested(text)
            }
            // Editing writes the field text imperatively, which breaks the
            // declarative binding above. Mirror the service query so opening
            // or discarding the page always shows the real search state.
            Connections {
                target: root.controller
                function onQueryChanged() { search.text = root.controller.query }
            }
        }
        ToolButton {
            objectName: "browseApplications"
            icon.name: "system-search"
            display: AbstractButton.IconOnly
            checkable: true
            checked: root.browsing
            Accessible.name: qsTr("Show all applications")
            ToolTip.text: Accessible.name
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: {
                root.resultsDismissed = false
                root.browsing = checked
            }
        }
    }

    Item {
        id: resultsHost
        Layout.fillWidth: true
        // The list hangs over the form from the typing row, so opening it
        // never pushes the remaining fields past the card.
        Layout.preferredHeight: 0
        Loader {
            id: resultsArea
            objectName: "applicationResultsArea"
            // It starts at the search field and reaches the magnifier's edge.
            x: root.labelWidth + Kirigami.Units.largeSpacing
            width: parent.width - x
            height: Kirigami.Units.gridUnit * 14
            z: 1
            visible: root.listVisible && root.visible
            active: root.listVisible && root.visible
            sourceComponent: resultsPanel
        }
    }

    Component {
        id: resultsPanel
        Rectangle {
            objectName: "applicationResultsPanel"
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.25)
            radius: Kirigami.Units.cornerRadius
            ScrollView {
                objectName: "applicationResultsScroll"
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ListView {
                    objectName: "applicationSearchResults"
                    model: root.controller.applications
                    cacheBuffer: 0
                    activeFocusOnTab: true
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ApplicationListRow {
                        required property string appId
                        required property string name
                        required property string appIconName
                        iconName: appIconName
                        objectName: "applicationResult-" + appId
                        width: ListView.view.width
                        text: name
                        selectionActive: root.controller.selectedAppId.length > 0
                        highlighted: root.controller.selectedAppId === appId
                        onClicked: root.chooseApplication(appId)
                        Keys.onReturnPressed: root.chooseApplication(appId)
                    }
                }
            }
            Label {
                objectName: "applicationResultsEmpty"
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
                visible: root.controller.applications.count === 0
                text: qsTr("No applications found.")
            }
        }
    }

    // Icon chosen for the item. The application icon stays the fallback.
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Label {
            objectName: "applicationIconLabel"
            text: qsTr("Icon:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        Button {
            id: iconButton
            objectName: "applicationIconButton"
            // The icon can be chosen before the application, so the button stays
            // available while the type is Application.
            display: AbstractButton.IconOnly
            icon.name: root.controller.selectedIconName.length > 0
                ? root.controller.selectedIconName : "application-x-executable"
            text: qsTr("Choose icon")
            Accessible.name: text
            ToolTip.text: text
            ToolTip.visible: hovered || activeFocus
            ToolTip.delay: Kirigami.Units.toolTipDelay
            onClicked: root.iconChooserRequested()
        }
        Item { Layout.fillWidth: true }
    }

    // Selected application description, below the icon.
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing
        Label {
            objectName: "applicationDescriptionLabel"
            text: qsTr("Description:")
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.preferredWidth: root.labelWidth
            opacity: 0.8
        }
        Label {
            objectName: "applicationDescriptionValue"
            text: root.controller.selectedApplication ? root.controller.selectedApplication.description : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
