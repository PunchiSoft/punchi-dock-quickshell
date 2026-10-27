// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native

// Lists a folder container's entries so its owner can keep some of them out of
// the popup. Every entry is listed, including the ones already hidden, so a
// choice can always be undone. The listing is unfiltered on purpose: the popup
// applies the stored names, this view only edits them.
ColumnLayout {
    id: root
    objectName: "folderEntrySelection"
    // Absolute path of the container folder; empty means a built-in container,
    // whose standard location the native model resolves.
    property string folderPath: ""
    // The built-in Home container stores no path but lists only the standard
    // KDE/XDG user folders at the home root.
    property bool homeFolder: false
    // The editor starts with no folder chosen and must not list anything yet.
    // The built-in Downloads container stores no path but is already chosen,
    // so its details keep listing the Downloads folder.
    property bool folderChosen: true
    // File names the popup skips.
    property var hiddenEntries: []
    signal entriesChosen(var names)

    activeFocusOnTab: true
    spacing: Kirigami.Units.smallSpacing

    function isHidden(entryName: string): bool {
        return root.hiddenEntries.indexOf(entryName) >= 0
    }
    function choose(entryName: string, shown: bool): void {
        const next = []
        for (const name of root.hiddenEntries) if (name !== entryName) next.push(name)
        if (!shown) next.push(entryName)
        root.entriesChosen(next)
    }
    function selectAll(): void { root.entriesChosen([]) }

    readonly property int hiddenCount: root.hiddenEntries.length
    // The listing only exists while this view is on screen: KDirLister is a
    // KIO object, and keeping it alive in a hidden settings page costs a worker
    // and outlives the window that owns it.
    readonly property var listing: listingLoader.item
    readonly property int entryCount: root.listing ? root.listing.count : 0
    readonly property bool listingLoading: root.listing ? root.listing.loading : false
    readonly property string listingError: root.listing ? root.listing.error : ""
    // Room kept clear on the right so a row highlight never runs under the
    // overlaid scroll bar.
    readonly property real scrollBarReserve: Kirigami.Units.gridUnit * 0.8

    RowLayout {
        Layout.fillWidth: true
        visible: root.folderChosen
        spacing: Kirigami.Units.mediumSpacing
        Label {
            objectName: "folderEntrySelectionLabel"
            text: qsTr("Shown in the popup")
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            objectName: "folderEntrySelectionCount"
            visible: root.folderChosen
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 6
            // A count instead of a mode switch: the empty list already means
            // "show everything", so the state is readable at a glance.
            text: root.hiddenCount > 0
                ? qsTr("%1 of %2 hidden").arg(root.hiddenCount).arg(root.entryCount)
                : qsTr("All shown")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            textFormat: Text.PlainText
        }
        Button {
            objectName: "folderEntrySelectionShowAll"
            visible: root.folderChosen
            text: qsTr("Show all")
            icon.name: "edit-select-all"
            display: AbstractButton.TextBesideIcon
            enabled: root.hiddenCount > 0
            onClicked: root.selectAll()
        }
    }

    SettingsCardFrame {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        visible: root.folderChosen
        Item {
            anchors.fill: parent
            // The card owns the rounded border; the list stays inside it so a
            // hover fill never touches the edge.
            anchors.margins: Kirigami.Units.smallSpacing
            ListView {
                id: entries
                objectName: "folderEntrySelectionList"
                anchors.fill: parent
                clip: true
                model: root.listing
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: CheckDelegate {
                    id: entryRow
                    required property string entryName
                    required property string entryIcon
                    required property bool directory
                    objectName: "folderEntry-" + entryName
                    width: entries.width - root.scrollBarReserve
                    text: entryName
                    checked: !root.isHidden(entryName)
                    icon.name: entryIcon
                    Accessible.name: entryName
                    Accessible.description: directory
                        ? qsTr("Folder") : qsTr("File")
                    onToggled: {
                        root.choose(entryRow.entryName, entryRow.checked)
                        // The gesture breaks the declarative binding; the owner
                        // list stays the source of truth.
                        entryRow.checked = Qt.binding(function() {
                            return !root.isHidden(entryRow.entryName)
                        })
                    }
                }
            }
            Label {
                objectName: "folderEntrySelectionEmpty"
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.7
                visible: entries.count === 0
                text: root.listingLoading ? qsTr("Loading…")
                    : root.listingError.length > 0 ? root.listingError
                    : qsTr("This folder is empty.")
            }
        }
    }

    Label {
        objectName: "folderEntrySelectionHint"
        Layout.fillWidth: true
        visible: !root.folderChosen
        text: qsTr("Choose a folder to list its contents.")
        textFormat: Text.PlainText
        wrapMode: Text.WordWrap
        opacity: 0.7
    }

    // Read-only listing for this view: the popup is the consumer of the stored
    // names, so filtering happens there.
    Loader {
        id: listingLoader
        active: root.visible && root.folderChosen
        sourceComponent: folderListing
    }
    Component {
        id: folderListing
        Native.FolderContents {
            location: root.folderPath.length > 0 ? "file://" + root.folderPath
                : root.homeFolder ? homeUrl : downloadsUrl
            standardUserDirsOnly: root.homeFolder
            sortMode: "name"
            active: true
        }
    }
}
