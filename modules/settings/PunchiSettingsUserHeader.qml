// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as Components
import "../../adapters/kde"

RowLayout {
    id: root
    objectName: "settingsUserHeader"
    property PunchiUserProfile profile: PunchiUserProfile {}
    readonly property bool shadersAvailable: GraphicsInfo.api !== GraphicsInfo.Software
    spacing: Kirigami.Units.smallSpacing
    Components.Avatar {
        objectName: "settingsUserAvatar"
        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        name: root.profile ? root.profile.displayName : ""
        source: root.profile ? root.profile.avatarSource : ""
        cache: false
        // The native icon chooses black/white from this color; use the surface
        // background so its contrast also holds for partially defined schemes.
        // Do not set a separate initials color: Kirigami Addons 1.16 removed
        // that property, and it never reached the icon this mode renders.
        color: Kirigami.Theme.backgroundColor
        initialsMode: Components.Avatar.InitialsMode.UseIcon
        // The native component does not mask photos in the software renderer.
        // Keep its circular user-icon fallback instead of an unmasked photo.
        imageMode: root.shadersAvailable ? Components.Avatar.ImageMode.AdaptiveImageOrInitals
            : Components.Avatar.ImageMode.AlwaysShowInitials
        Accessible.ignored: true
    }
    Label {
        objectName: "settingsUserName"
        Layout.fillWidth: true
        text: root.profile ? root.profile.displayName : ""
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.weight: Font.DemiBold
        Accessible.name: text
    }
}
