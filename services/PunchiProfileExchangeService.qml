// SPDX-License-Identifier: GPL-3.0-or-later
import QtQml
import Punchi.Kde as Native
import "../config"
import "../config/PunchiProfileDocument.js" as PunchiProfileDocument

// Reads and writes portable profiles. A read is validated and previewed on a
// separate settings object; nothing reaches the target until the caller
// confirms, and the caller still applies the result before it is saved.
QtObject {
    id: root
    required property PunchiShellSettings target
    property var file: Native.ProfileFile {}
    readonly property PunchiShellSettings preview: PunchiShellSettings {}
    property var pending: null
    property string pendingSummary: ""
    property string notice: ""
    property bool noticeIsError: false
    readonly property bool hasPending: pending !== null
    signal importReady()
    signal exportSucceeded(string url)

    function message(reason): string {
        switch (reason) {
        case "missing": return qsTr("The file does not exist.")
        case "not-regular": return qsTr("The path is not a regular file.")
        case "too-large": return qsTr("The file exceeds 256 KiB.")
        case "invalid-encoding": return qsTr("The file is not valid UTF-8 text.")
        case "read-failed": return qsTr("The file could not be read.")
        case "write-failed": return qsTr("The profile could not be written.")
        case "symlink": return qsTr("Symbolic links cannot be overwritten. Choose a new name.")
        case "not-local": return qsTr("Choose a local file.")
        case "invalid-json": return qsTr("The file is not valid JSON.")
        case "not-profile": return qsTr("The file is not a Punchi Dock Quickshell profile.")
        case "newer": return qsTr("The file uses a newer profile format.")
        case "invalid-field": return qsTr("The file contains an invalid value.")
        case "internal": return qsTr("The profile could not be prepared.")
        }
        return qsTr("The file could not be read.")
    }
    function clearNotice(): void {
        notice = ""
        noticeIsError = false
    }
    function fail(reason): bool {
        clearNotice()
        notice = message(reason)
        noticeIsError = true
        return false
    }
    function importFrom(url): bool {
        pending = null
        clearNotice()
        const result = file.read(url, PunchiProfileDocument.maximumBytes)
        if (!result || !result.ok) return fail(result && result.error ? result.error : "read-failed")
        const parsed = PunchiProfileDocument.parse(result.text)
        if (!parsed.ok) return fail(parsed.reason)
        preview.reset()
        if (!preview.restore(parsed.profile)) return fail("invalid-field")
        const snapshot = preview.snapshot()
        if (!PunchiProfileDocument.parse(PunchiProfileDocument.serialize(snapshot)).ok)
            return fail("invalid-field")
        pending = snapshot
        pendingSummary = qsTr("%1 dock items and %2 folder containers")
            .arg(snapshot.pinnedIds.length).arg(snapshot.containers.length)
        importReady()
        return true
    }
    function confirmImport(): bool {
        if (pending === null) return false
        const applied = target.restore(pending)
        pending = null
        if (!applied) return fail("invalid-field")
        clearNotice()
        notice = qsTr("Profile loaded. Review the changes, then apply or accept them.")
        return true
    }
    function cancelImport(): void {
        pending = null
        clearNotice()
    }
    function exportTo(url): bool {
        clearNotice()
        const document = PunchiProfileDocument.serialize(target.snapshot())
        if (!PunchiProfileDocument.parse(document).ok) return fail("internal")
        const result = file.write(url, document, PunchiProfileDocument.maximumBytes)
        if (!result || !result.ok) return fail(result && result.error ? result.error : "write-failed")
        notice = qsTr("Profile exported.")
        exportSucceeded(url)
        return true
    }
}
