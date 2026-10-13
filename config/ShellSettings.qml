// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "LauncherIds.js" as LauncherIds
import "PanelModes.js" as PanelModes
import "../adapters/kde"

QtObject {
    readonly property DockMetrics metrics: DockMetrics {}
    property int sizePercent: 100
    property int iconSize: Math.round(metrics.iconSize * sizePercent / 100)
    property int itemSize: iconSize + metrics.itemSize - metrics.iconSize
    property int spacing: metrics.spacing
    property int padding: metrics.padding
    property int edgeMargin: metrics.edgeMargin
    property real surfaceRadius: metrics.surfaceRadius
    property int bottomContentPadding: metrics.bottomContentPadding
    property string panelMode: "overlay"
    onPanelModeChanged: {
        if (panelMode === "desktop") panelMode = PanelModes.normalize(panelMode)
    }
    property bool magnificationEnabled: true
    property bool reducedMotion: false
    property bool bounceEnabled: true
    property var pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular", "item:trash"]
    property real maximumIconScale: 2.0
    property real waveSharedScaleLimit: 1.0
    readonly property MotionPreferences desktopMotion: MotionPreferences {}
    readonly property bool effectiveReducedMotion: reducedMotion || desktopMotion.reducedMotion
    readonly property int clickDuration: bounceEnabled ? desktopMotion.clickDuration : 0
    readonly property int waveEnterDuration: desktopMotion.enterDuration
    readonly property int waveLeaveDuration: desktopMotion.leaveDuration
    readonly property int slideDuration: desktopMotion.slideDuration

    function snapshot(): var {
        return {version: 2, panelMode, sizePercent, magnificationEnabled,
            reducedMotion, bounceEnabled, maximumIconScale, pinnedIds}
    }
    function restore(data: var): bool {
        if (!data || (data.version !== 1 && data.version !== 2)) return false
        if (PanelModes.accepts(data.panelMode)) panelMode = PanelModes.normalize(data.panelMode)
        if (Number.isInteger(data.sizePercent) && data.sizePercent >= 50 && data.sizePercent <= 150)
            sizePercent = data.sizePercent
        if (Number.isFinite(data.maximumIconScale) && data.maximumIconScale >= 1 && data.maximumIconScale <= 3)
            maximumIconScale = data.maximumIconScale
        for (const key of ["magnificationEnabled", "reducedMotion", "bounceEnabled"])
            if (typeof data[key] === "boolean") this[key] = data[key]
        if (LauncherIds.validList(data.pinnedIds)) {
            pinnedIds = data.pinnedIds.slice()
            if (data.version === 1 && pinnedIds.indexOf("item:trash") < 0
                    && pinnedIds.length < LauncherIds.maximumPins)
                pinnedIds = pinnedIds.concat(["item:trash"])
        }
        return true
    }
    function reset(): void {
        restore({version: 2, panelMode: "overlay", sizePercent: 100,
            maximumIconScale: 2, magnificationEnabled: true, reducedMotion: false,
            bounceEnabled: true, pinnedIds: ["files", "terminal", "browser", "kate", "systemsettings", "discover", "gwenview", "okular", "item:trash"]})
    }
}
