// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

// Read-only viewer for the license text bundled with the shell. The text is
// rendered exactly as shipped, without a browser, a network request or an
// external document viewer.
Dialog {
    id: root
    objectName: "aboutLicenseDialog"
    property string licenseText: ""
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    title: qsTr("GNU General Public License v3.0 or later")
    width: Math.min(Kirigami.Units.gridUnit * 44,
        parent ? parent.width - Kirigami.Units.gridUnit * 4 : Kirigami.Units.gridUnit * 44)
    padding: Kirigami.Units.largeSpacing
    onOpened: licenseTextArea.forceActiveFocus(Qt.PopupFocusReason)
    contentItem: Item {
        implicitWidth: Kirigami.Units.gridUnit * 40
        implicitHeight: root.parent
            ? Math.min(Kirigami.Units.gridUnit * 30,
                Math.max(Kirigami.Units.gridUnit * 10, root.parent.height * 0.62))
            : Kirigami.Units.gridUnit * 30
        ScrollView {
            id: licenseScroll
            objectName: "aboutLicenseScroll"
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            TextArea {
                id: licenseTextArea
                objectName: "aboutLicenseText"
                width: licenseScroll.availableWidth
                text: root.licenseText
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                Accessible.name: qsTr("License text")
            }
        }
    }
    footer: DialogButtonBox {
        Button {
            objectName: "aboutLicenseClose"
            text: qsTr("Close")
            onClicked: root.close()
        }
    }
}
