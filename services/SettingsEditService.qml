// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import "../config"

QtObject {
    id: root
    required property ShellSettings settings
    readonly property ShellSettings draft: ShellSettings {}
    property bool active: false
    property bool committing: false
    property var baseline: null
    readonly property bool dirty: active && baseline !== null
        && JSON.stringify(draft.snapshot()) !== JSON.stringify(baseline)

    function copy(data: var): var { return JSON.parse(JSON.stringify(data)) }
    function begin(): void {
        baseline = copy(settings.snapshot())
        draft.restore(baseline)
        active = true
    }
    function cancel(): void {
        active = false
        baseline = copy(settings.snapshot())
        draft.restore(baseline)
    }
    function synchronize(): void {
        if (!active || committing || settings.bulkChange) return
        const current = settings.snapshot()
        const edited = copy(draft.snapshot())
        const nextBaseline = copy(baseline)
        for (const key of Object.keys(current)) {
            // Follow external changes only where this editor has no conflicting edit.
            if (JSON.stringify(edited[key]) === JSON.stringify(baseline[key])
                || JSON.stringify(edited[key]) === JSON.stringify(current[key])) {
                edited[key] = current[key]
                nextBaseline[key] = current[key]
            }
        }
        draft.restore(edited)
        baseline = nextBaseline
    }
    function apply(): void {
        if (!active) return
        const merged = copy(settings.snapshot())
        const edited = draft.snapshot()
        for (const key of Object.keys(merged))
            if (JSON.stringify(edited[key]) !== JSON.stringify(baseline[key]))
                merged[key] = edited[key]
        committing = true
        settings.restore(merged)
        committing = false
        begin()
    }
    readonly property Connections changes: Connections {
        target: root.settings
        function onDownloadsViewChanged() { root.synchronize() }
        function onDockEdgeChanged() { root.synchronize() }
        function onPanelModeChanged() { root.synchronize() }
        function onSizePercentChanged() { root.synchronize() }
        function onMaximumIconScaleChanged() { root.synchronize() }
        function onMagnificationEnabledChanged() { root.synchronize() }
        function onReducedMotionChanged() { root.synchronize() }
        function onBounceEnabledChanged() { root.synchronize() }
        function onPinnedIdsChanged() { root.synchronize() }
        function onContainersChanged() { root.synchronize() }
        // A bulk restore emits one notification after every property settled.
        function onProfileApplied() { root.synchronize() }
    }
}
