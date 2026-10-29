// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import QtQuick

QtObject {
    id: root
    property bool autoHide: false
    property bool dodgeWindows: false
    property bool overlapAvailable: false
    property bool overlapping: false
    property bool showingDesktop: false
    readonly property bool edgeMode: autoHide || dodgeWindows
    readonly property bool shouldHide: autoHide
        || (dodgeWindows && overlapAvailable && overlapping && !showingDesktop)
    property bool pointerInside: false
    property bool menuOpen: false
    property bool keyboardFocused: false
    property bool configuring: false
    property bool reducedMotion: false
    property int transitionDuration: 100
    property int hideDelay: 500
    signal hiding()
    signal revealing()
    readonly property bool interacting: pointerInside || menuOpen || keyboardFocused || configuring
    property bool revealed: true
    property bool surfaceVisible: true
    property real slideProgress: revealed || !edgeMode ? 1 : 0
    readonly property real boundedSlideProgress: Math.max(0, Math.min(1, slideProgress))
    readonly property real opacity: !edgeMode || boundedSlideProgress > 0 ? 1 : 0
    readonly property int effectiveDuration: reducedMotion ? 0 : Math.max(0, transitionDuration)

    Behavior on slideProgress {
        enabled: root.edgeMode && root.effectiveDuration > 0
        NumberAnimation {
            id: slide
            duration: root.effectiveDuration
            easing.type: root.revealed ? Easing.OutCubic : Easing.InCubic
            onRunningChanged: if (!running) Qt.callLater(root.settle)
        }
    }
    readonly property Timer hideTimer: Timer {
        interval: root.hideDelay
        onTriggered: root.hide()
    }
    function settle(): void {
        // The final state belongs to the current target, including instant mode
        // and interrupted closes. Never collapse while any content is moving.
        if (edgeMode && shouldHide && !revealed && boundedSlideProgress === 0)
            surfaceVisible = false
    }
    onSlideProgressChanged: if (boundedSlideProgress === 0) Qt.callLater(root.settle)
    function reveal(): void {
        hideTimer.stop()
        if (!revealed) revealing()
        surfaceVisible = true
        revealed = true
        if (shouldHide && !interacting) hideTimer.restart()
    }
    function hide(): void {
        if (!shouldHide || interacting) return
        if (!revealed) return
        hiding()
        revealed = false
        Qt.callLater(root.settle)
    }
    function evaluatePolicy(): void {
        if (dodgeWindows && !autoHide && shouldHide && !interacting) {
            // KDE has already settled the window geometry; react to overlap now.
            // The leave grace below belongs to pointer/menu interaction instead.
            hideTimer.stop()
            hide()
        } else reveal()
    }
    onAutoHideChanged: evaluatePolicy()
    onDodgeWindowsChanged: evaluatePolicy()
    onShouldHideChanged: evaluatePolicy()
    onInteractingChanged: {
        if (interacting) reveal()
        else if (shouldHide) hideTimer.restart()
    }
    onEffectiveDurationChanged: {
        if (effectiveDuration === 0) slide.complete()
        Qt.callLater(root.settle)
    }
    Component.onCompleted: {
        evaluatePolicy()
    }
}
