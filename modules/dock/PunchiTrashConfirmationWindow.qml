// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import org.kde.kirigami as Kirigami

Window {
    id: root
    required property var service
    required property string questionText
    required property string warningText
    property bool reducedMotion: false
    title: qsTr("Empty Trash")
    flags: Qt.Dialog | Qt.FramelessWindowHint
    color: "transparent"
    width: content.implicitWidth + Kirigami.Units.largeSpacing * 4
    height: content.implicitHeight + Kirigami.Units.largeSpacing * 4
    x: Screen.virtualX + (Screen.width - width) / 2
    y: Screen.virtualY + (Screen.height - height) / 2
    visible: motion.present
    onVisibleChanged: if (visible) { requestActivate(); Qt.callLater(content.focusFirst) }
    onClosing: function(event) { event.accepted = false; root.service.cancel() }
    PunchiTrashConfirmationMotion {
        id: motion
        requested: root.service.confirming
        reducedMotion: root.reducedMotion
    }
    PunchiTrashConfirmationContent {
        id: content
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        scale: motion.surfaceScale
        opacity: motion.surfaceOpacity
        questionText: root.questionText
        warningText: root.warningText
        canConfirm: root.service.confirming && root.service.canEmpty
        onConfirmRequested: root.service.confirm()
        onCancelRequested: root.service.cancel()
    }
}
