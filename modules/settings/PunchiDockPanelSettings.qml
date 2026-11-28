// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../config"

// Panel settings category. The top-panel switch keeps editing the shared
// settings draft; this page only gives it a category of its own and leaves room
// for future panel cards without adding controls that do not exist yet.
ColumnLayout {
    id: root
    required property PunchiShellSettings settings
    spacing: Kirigami.Units.largeSpacing
    function focusFirst(): void { topBarCard.focusFirst() }
    PunchiTopBarSettingsCard {
        id: topBarCard
        settings: root.settings
    }
    Item { Layout.fillHeight: true }
}
