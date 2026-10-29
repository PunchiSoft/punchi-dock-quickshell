// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

.import "PunchiDefaultProfile.js" as PunchiDefaultProfile
.import "PunchiDockItemIds.js" as PunchiDockItemIds
.import "PunchiPanelModes.js" as PunchiPanelModes
.import "PunchiRecentPresentation.js" as PunchiRecentPresentation
.import "PunchiScreenSelection.js" as PunchiScreenSelection

// Portable profile document exchanged with the user. It is data only: a
// profile never carries a command, a script or a path chosen by the file.
const schema = "punchi-dock-quickshell/profile"
const version = 1
// A complete profile stays small. The bound protects the shell from a
// multi-gigabyte read and keeps the preview parse a single bounded pass.
const maximumBytes = 262144

const booleanKeys = ["magnificationEnabled", "reducedMotion", "bounceEnabled",
    "recentApplicationsEnabled", "updateBadgeEnabled", "runningMarkersFollowDesktop",
    "avoidInnerEdgeAutoHide", "menuBackgroundBlurEnabled", "menuShowDistributionName",
    "menuShowPageArrows", "menuShowLabels"]

function objectValue(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function own(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key)
}

function unsafeKey(key) {
    return key === "__proto__" || key === "constructor" || key === "prototype"
}

function inRange(value, range, integer) {
    if (integer ? !Number.isInteger(value) : !Number.isFinite(value)) return false
    return value >= range.minimum && value <= range.maximum
}

function validOptionalIconSize(value, range) {
    return value === 0 || inRange(value, range, true)
}

function validate(profile) {
    if (!objectValue(profile)) return "not-profile"
    for (const key of Object.keys(profile))
        if (unsafeKey(key)) return "invalid-field"
    const profileVersion = profile.version
    if (!Number.isInteger(profileVersion) || profileVersion < 1) return "not-profile"
    if (profileVersion > PunchiDefaultProfile.profile.version) return "newer"
    if (own(profile, "downloadsView") && !PunchiDockItemIds.validLayout(profile.downloadsView))
        return "invalid-field"
    if (own(profile, "containers") && !PunchiDockItemIds.validContainers(profile.containers))
        return "invalid-field"
    if (own(profile, "dockEdge") && ["bottom", "left", "right"].indexOf(profile.dockEdge) < 0)
        return "invalid-field"
    if (own(profile, "panelMode") && !PunchiPanelModes.accepts(profile.panelMode))
        return "invalid-field"
    if (own(profile, "screenMode") && !PunchiScreenSelection.acceptsMode(profile.screenMode))
        return "invalid-field"
    if (own(profile, "selectedScreens") && !PunchiScreenSelection.validSelection(profile.selectedScreens))
        return "invalid-field"
    if (own(profile, "desktopMode") && !PunchiScreenSelection.acceptsTargetMode(profile.desktopMode))
        return "invalid-field"
    if (own(profile, "selectedDesktops") && !PunchiScreenSelection.validSelection(profile.selectedDesktops))
        return "invalid-field"
    if (own(profile, "activityMode") && !PunchiScreenSelection.acceptsTargetMode(profile.activityMode))
        return "invalid-field"
    if (own(profile, "selectedActivities") && !PunchiScreenSelection.validSelection(profile.selectedActivities))
        return "invalid-field"
    if (own(profile, "sizePercent")
            && !inRange(profile.sizePercent, PunchiDefaultProfile.limits.sizePercent, true))
        return "invalid-field"
    if (own(profile, "maximumIconScale")
            && !inRange(profile.maximumIconScale, PunchiDefaultProfile.limits.maximumIconScale, false))
        return "invalid-field"
    if (own(profile, "popupScale")
            && !inRange(profile.popupScale, PunchiDefaultProfile.limits.popupScale, false))
        return "invalid-field"
    if (own(profile, "popupIconSize")
            && !validOptionalIconSize(profile.popupIconSize, PunchiDefaultProfile.limits.popupIconSize))
        return "invalid-field"
    if (own(profile, "popupListIconSize")
            && !validOptionalIconSize(profile.popupListIconSize, PunchiDefaultProfile.limits.popupListIconSize))
        return "invalid-field"
    if (own(profile, "popupFanIconSize")
            && !validOptionalIconSize(profile.popupFanIconSize, PunchiDefaultProfile.limits.popupFanIconSize))
        return "invalid-field"
    if (own(profile, "popupHeightPercent")
            && !inRange(profile.popupHeightPercent, PunchiDefaultProfile.limits.popupHeightPercent, true))
        return "invalid-field"
    if (own(profile, "menuBackgroundOpacity")
            && !inRange(profile.menuBackgroundOpacity,
                PunchiDefaultProfile.limits.menuBackgroundOpacity, false))
        return "invalid-field"
    if (own(profile, "menuIconScale")
            && !inRange(profile.menuIconScale, PunchiDefaultProfile.limits.menuIconScale, false))
        return "invalid-field"
    if (own(profile, "menuCloseButtonPosition")
            && ["left", "right"].indexOf(profile.menuCloseButtonPosition) < 0)
        return "invalid-field"
    if (own(profile, "menuHoverAnimation")
            && ["none", "individual", "pulse", "bounce"].indexOf(profile.menuHoverAnimation) < 0)
        return "invalid-field"
    if (own(profile, "recentApplicationsCount")
            && !inRange(profile.recentApplicationsCount,
                PunchiDefaultProfile.limits.recentApplicationsCount, true))
        return "invalid-field"
    if (own(profile, "recentApplicationsPresentation")
            && !PunchiRecentPresentation.validPresentation(profile.recentApplicationsPresentation))
        return "invalid-field"
    if (own(profile, "recentApplicationsContainerLayout")
            && !PunchiRecentPresentation.validContainerLayout(profile.recentApplicationsContainerLayout))
        return "invalid-field"
    for (const key of booleanKeys)
        if (own(profile, key) && typeof profile[key] !== "boolean") return "invalid-field"
    if (own(profile, "iconOverrides") && !PunchiDockItemIds.validIconOverrides(profile.iconOverrides))
        return "invalid-field"
    if (own(profile, "pinnedIds") && !PunchiDockItemIds.validList(profile.pinnedIds))
        return "invalid-field"
    return ""
}

// The exported document is self-describing, so a future file that this build
// cannot read is rejected before any value reaches the settings object.
function serialize(profile) {
    try {
        return JSON.stringify({schema: schema, version: version, profile: profile}, null, 2) + "\n"
    } catch (error) {
        return ""
    }
}

// Accepts the portable document and the raw saved profile, so a user can copy
// the settings file itself. Both paths pass the same field validation.
function parse(text) {
    if (typeof text !== "string" || text.length === 0) return {ok: false, reason: "invalid-json"}
    if (text.length > maximumBytes) return {ok: false, reason: "too-large"}
    let document
    try {
        document = JSON.parse(text)
    } catch (error) {
        return {ok: false, reason: "invalid-json"}
    }
    if (!objectValue(document)) return {ok: false, reason: "not-profile"}
    let profile = document
    if (own(document, "schema")) {
        if (document.schema !== schema) return {ok: false, reason: "not-profile"}
        if (!Number.isInteger(document.version) || document.version < 1)
            return {ok: false, reason: "not-profile"}
        if (document.version > version) return {ok: false, reason: "newer"}
        if (!objectValue(document.profile)) return {ok: false, reason: "not-profile"}
        profile = document.profile
    }
    const reason = validate(profile)
    return reason.length > 0 ? {ok: false, reason: reason} : {ok: true, profile: profile}
}
