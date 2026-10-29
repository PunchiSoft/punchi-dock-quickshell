// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config"
import "../../config/PunchiDefaultProfile.js" as PunchiDefaultProfile
import "../../config/PunchiProfileDocument.js" as PunchiProfileDocument
import "../../services"

TestCase {
    name: "ProfileExchange"
    QtObject {
        id: fakeFile
        property var documents: ({})
        property string lastWritten: ""
        property string lastPath: ""
        property string readError: ""
        function read(url, maximumBytes) {
            if (readError.length > 0) return {ok: false, error: readError}
            const text = documents[String(url)]
            if (text === undefined) return {ok: false, error: "missing"}
            return {ok: true, text: text}
        }
        function write(url, text, maximumBytes) {
            if (readError.length > 0) return {ok: false, error: readError}
            lastPath = String(url)
            lastWritten = text
            return {ok: true}
        }
    }
    PunchiShellSettings { id: settings }
    PunchiProfileExchangeService { id: exchange; target: settings; file: fakeFile }

    function resetExchange() {
        settings.reset()
        fakeFile.documents = ({})
        fakeFile.lastWritten = ""
        fakeFile.lastPath = ""
        fakeFile.readError = ""
        exchange.cancelImport()
    }

    function test_shell_settings_start_from_the_first_run_profile() {
        resetExchange()
        const snapshot = settings.snapshot()
        const defaults = PunchiDefaultProfile.fresh()
        compare(snapshot.version, defaults.version)
        for (const key of Object.keys(defaults))
            compare(JSON.stringify(snapshot[key]), JSON.stringify(defaults[key]), key)
    }

    function test_import_waits_for_confirmation_and_cancel_keeps_values() {
        resetExchange()
        settings.panelMode = "autohide"
        settings.pinnedIds = ["files"]
        const imported = PunchiDefaultProfile.fresh()
        imported.panelMode = "reserve"
        imported.sizePercent = 80
        imported.pinnedIds = ["terminal", "item:trash"]
        fakeFile.documents = ({"file:///incoming.json": PunchiProfileDocument.serialize(imported)})

        verify(exchange.importFrom("file:///incoming.json"))
        verify(exchange.hasPending)
        compare(settings.panelMode, "autohide")
        verify(exchange.pendingSummary.indexOf("2 dock items") >= 0)
        verify(exchange.confirmImport())
        compare(settings.panelMode, "reserve")
        compare(settings.sizePercent, 80)
        compare(settings.pinnedIds.length, 2)
        compare(exchange.notice, "Profile loaded. Review the changes, then apply or accept them.")
        verify(!exchange.hasPending)

        fakeFile.documents = ({"file:///incoming.json": PunchiProfileDocument.serialize(imported)})
        verify(exchange.importFrom("file:///incoming.json"))
        exchange.cancelImport()
        compare(settings.panelMode, "reserve")
        verify(!exchange.hasPending)
    }

    function test_invalid_document_and_read_failure_leave_settings_untouched() {
        resetExchange()
        settings.panelMode = "autohide"
        fakeFile.documents = ({"file:///invalid.json": "{}"})
        verify(!exchange.importFrom("file:///invalid.json"))
        verify(exchange.noticeIsError)
        compare(exchange.notice, "The file is not a Punchi Dock Quickshell profile.")
        compare(settings.panelMode, "autohide")

        fakeFile.readError = "too-large"
        verify(!exchange.importFrom("file:///invalid.json"))
        compare(exchange.notice, "The file exceeds 256 KiB.")
        compare(settings.panelMode, "autohide")
    }

    function test_export_writes_a_portable_document() {
        resetExchange()
        settings.panelMode = "reserve"
        settings.sizePercent = 80
        verify(exchange.exportTo("file:///export.json"))
        compare(fakeFile.lastPath, "file:///export.json")
        const exported = PunchiProfileDocument.parse(fakeFile.lastWritten)
        verify(exported.ok)
        compare(exported.profile.panelMode, "reserve")
        compare(exported.profile.sizePercent, 80)
        compare(exchange.notice, "Profile exported.")
    }

    function test_export_refuses_an_invalid_target_snapshot() {
        resetExchange()
        settings.pinnedIds = ["files", "files"]
        verify(!exchange.exportTo("file:///export.json"))
        compare(exchange.notice, "The profile could not be prepared.")
        compare(fakeFile.lastWritten, "")
    }
}
