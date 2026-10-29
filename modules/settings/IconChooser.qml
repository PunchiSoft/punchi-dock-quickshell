// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Punchi.Kde as Native
import "../../adapters/kde"

// Icon chooser modeled on the KDE Menu Editor dialog: a separate window with its own
// search field and icon grid. It owns the draft choice and reports it only on OK.
Item {
    id: root
    property bool opened: false
    // Icon the chooser starts from; the caller decides what an empty name means.
    property string initialIcon: ""
    // Icons installed in the active Plasma theme, filtered by the picker search.
    readonly property var iconModel: IconThemeAdapter {}
    // Icon highlighted in the chooser; applied only when the user accepts.
    property string pickedIconName: ""
    // Category shown in the chooser; Applications first, as the native dialog.
    property string iconContextFilter: ""
    // The default category applies until the user picks another one.
    property bool iconContextChosen: false
    signal accepted(string iconName)
    signal cancelled()

    readonly property var iconContextValues: [""].concat(root.iconModel.contexts || [])
    readonly property var iconContextLabels: {
        const values = root.iconContextValues
        const labels = []
        for (let index = 0; index < values.length; ++index)
            labels.push(root.iconContextLabel(values[index]))
        return labels
    }
    // Categories arrive after the background scan finishes.
    readonly property Connections iconContextChanges: Connections {
        target: root.iconModel
        function onContextsChanged() { root.useDefaultIconContext() }
    }

    function open(iconName: string): void {
        root.initialIcon = iconName
        root.pickedIconName = iconName
        root.iconContextChosen = false
        root.iconModel.ensureLoaded()
        root.useDefaultIconContext()
        root.opened = true
    }
    function close(): void {
        root.opened = false
        root.cancelled()
    }
    function useDefaultIconContext(): void {
        if (root.iconContextChosen) return
        const contexts = root.iconModel.contexts || []
        root.iconContextFilter = contexts.indexOf("Applications") >= 0 ? "Applications" : ""
        root.iconModel.context = root.iconContextFilter
    }
    function iconContextLabel(context: string): string {
        switch (context) {
        case "": return qsTr("All")
        case "Actions": return qsTr("Actions")
        case "Animations": return qsTr("Animations")
        case "Applications": return qsTr("Applications")
        case "Categories": return qsTr("Categories")
        case "Devices": return qsTr("Devices")
        case "Emblems": return qsTr("Emblems")
        case "Emotes": return qsTr("Emotes")
        case "Filesystems": return qsTr("File systems")
        case "International": return qsTr("Languages")
        case "MimeTypes": return qsTr("File types")
        case "Places": return qsTr("Places")
        case "Status": return qsTr("Status")
        default: return context
        }
    }

    Loader {
        id: iconArea
        objectName: "iconPickerArea"
        active: root.opened
        sourceComponent: iconDialogComponent
    }

    Component {
        id: iconDialogComponent
        Window {
            id: iconDialog
            objectName: "iconPickerPopup"
            title: qsTr("Select Icon")
            transientParent: root.Window.window
            flags: Qt.Dialog
            modality: Qt.WindowModal
            width: Kirigami.Units.gridUnit * 30
            height: Kirigami.Units.gridUnit * 24
            visible: true
            color: Kirigami.Theme.backgroundColor
            // Closing the dialog is the only exit; the loader then drops it.
            onClosing: root.close()
            onVisibleChanged: {
                if (!visible) return
                requestActivate()
                iconSearch.forceActiveFocus(Qt.TabFocusReason)
            }
            // The dialog is its own window, so it sets the color set explicitly
            // instead of inheriting the settings window.
            Rectangle {
                anchors.fill: parent
                color: Kirigami.Theme.backgroundColor
                Kirigami.Theme.inherit: false
                Kirigami.Theme.colorSet: Kirigami.Theme.Window
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.mediumSpacing
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.mediumSpacing
                        ComboBox {
                            id: iconContext
                            objectName: "iconContext"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                            model: root.iconContextLabels
                            Accessible.name: qsTr("Icon category")
                            // The shown label follows the active filter; the
                            // control's own index is not a reliable mirror.
                            displayText: root.iconContextLabel(root.iconContextFilter)
                            onActivated: {
                                root.iconContextChosen = true
                                root.iconContextFilter = root.iconContextValues[currentIndex]
                                root.iconModel.context = root.iconContextFilter
                            }
                        }
                        TextField {
                            id: iconSearch
                            objectName: "iconSearch"
                            Layout.fillWidth: true
                            placeholderText: qsTr("Search icons…")
                            Accessible.name: qsTr("Search icons")
                            onTextEdited: root.iconModel.query = text
                            Keys.onEscapePressed: root.close()
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            GridView {
                                id: iconGrid
                                objectName: "iconGrid"
                                // The native chooser draws 60px tiles with a caption.
                                cellWidth: 92
                                cellHeight: 92
                                model: root.iconModel
                                cacheBuffer: 0
                                boundsBehavior: Flickable.StopAtBounds
                                Keys.onEscapePressed: root.close()
                                delegate: ItemDelegate {
                                    id: iconTile
                                    required property string iconName
                                    objectName: "iconResult-" + iconName
                                    width: iconGrid.cellWidth
                                    height: iconGrid.cellHeight
                                    highlighted: root.pickedIconName === iconName
                                    onClicked: root.pickedIconName = iconName
                                    // The native chooser captions every tile.
                                    contentItem: ColumnLayout {
                                        spacing: Kirigami.Units.smallSpacing
                                        Kirigami.Icon {
                                            id: tileIcon
                                            Native.IconThemeRefresh.enabled: true
                                            source: iconTile.iconName
                                            // A theme can list an asset Qt cannot
                                            // resolve; show the standard glyph
                                            // instead of an empty tile.
                                            fallback: "image-missing"
                                            Layout.alignment: Qt.AlignHCenter
                                            // The native chooser renders tiles at 48px.
                                            Layout.preferredWidth: Kirigami.Units.iconSizes.large
                                            Layout.preferredHeight: Kirigami.Units.iconSizes.large
                                        }
                                        Label {
                                            text: iconTile.iconName
                                            textFormat: Text.PlainText
                                            color: Kirigami.Theme.textColor
                                            font: Kirigami.Theme.smallFont
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            // A name the theme cannot paint stays
                                            // offered but reads as unavailable.
                                            opacity: tileIcon.valid ? 1.0 : 0.6
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                        Label {
                            objectName: "iconPickerEmpty"
                            anchors.centerIn: parent
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            opacity: 0.7
                            visible: root.iconModel.count === 0
                            text: qsTr("No icons found.")
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            objectName: "applyIconChoice"
                            text: qsTr("OK")
                            icon.name: "dialog-ok-apply"
                            enabled: root.pickedIconName.length > 0
                            onClicked: {
                                const chosen = root.pickedIconName
                                root.opened = false
                                root.accepted(chosen)
                            }
                        }
                        Button {
                            objectName: "cancelIconChoice"
                            text: qsTr("Cancel")
                            icon.name: "dialog-cancel"
                            onClicked: root.close()
                        }
                    }
                }
            }
        }
    }
}
