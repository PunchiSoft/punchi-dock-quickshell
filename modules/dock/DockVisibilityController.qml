// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQuick

QtObject {
    id: root
    property bool autoHide: false
    property bool pointerInside: false
    property bool menuOpen: false
    property bool keyboardFocused: false
    property bool configuring: false
    property bool reducedMotion: false
    property int transitionDuration: 100
    property int hideDelay: 450
    readonly property bool interacting: pointerInside || menuOpen || keyboardFocused || configuring
    property bool revealed: true
    property bool surfaceVisible: true
    property real slideProgress: revealed || !autoHide ? 1 : 0
    readonly property real boundedSlideProgress: Math.max(0, Math.min(1, slideProgress))
    readonly property real opacity: !autoHide || boundedSlideProgress > 0 ? 1 : 0
    readonly property int effectiveDuration: reducedMotion ? 0 : Math.max(0, transitionDuration)

    Behavior on slideProgress {
        enabled: root.autoHide && root.effectiveDuration > 0
        SmoothedAnimation {
            id: slide
            duration: root.effectiveDuration
            velocity: -1
            reversingMode: SmoothedAnimation.Eased
        }
    }
    readonly property Timer hideTimer: Timer {
        interval: root.hideDelay
        onTriggered: root.hide()
    }
    // Keep the full client area until the dock has moved completely offscreen.
    readonly property Timer closeTimer: Timer {
        interval: root.effectiveDuration
        onTriggered: {
            if (root.autoHide && !root.revealed) {
                if (root.boundedSlideProgress > 0) root.closeTimer.restart()
                else root.surfaceVisible = false
            }
        }
    }
    function reveal(): void {
        hideTimer.stop()
        closeTimer.stop()
        surfaceVisible = true
        revealed = true
        if (autoHide && !interacting) hideTimer.restart()
    }
    function hide(): void {
        if (!autoHide || interacting) return
        revealed = false
        closeTimer.restart()
    }
    onAutoHideChanged: {
        reveal()
        if (autoHide && !interacting) hideTimer.restart()
    }
    onInteractingChanged: {
        if (interacting) reveal()
        else if (autoHide) hideTimer.restart()
    }
    onEffectiveDurationChanged: {
        if (effectiveDuration === 0) slide.complete()
        if (autoHide && !revealed) closeTimer.restart()
    }
    Component.onCompleted: {
        if (autoHide && !interacting) hideTimer.restart()
    }
}
