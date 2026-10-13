// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import org.kde.coreaddons as KCoreAddons

QtObject {
    id: root
    property var account: KCoreAddons.KUser {}
    readonly property string displayName: account ? (account.fullName || account.loginName) : ""
    readonly property url photoUrl: account ? account.faceIconUrl : ""
    // KUser invalidates same-path images through faceIconUrlChanged. The view
    // uses cache:false; no polling or separate account/photo cache is needed.
    readonly property url avatarSource: root.photoUrl.toString().startsWith("file:") ? root.photoUrl : ""
}
