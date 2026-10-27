// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../modules/settings"

TestCase {
    id: test
    name: "ProfileSettingsPage"
    when: windowShown
    width: 640
    height: 480

    QtObject {
        id: fakeExchange
        property string notice: ""
        property bool noticeIsError: false
        property string pendingSummary: ""
        property bool hasPending: false
        property bool confirmed: false
        property bool cancelled: false
        signal importReady()
        function importFrom(url) { return false }
        function confirmImport() {
            confirmed = true
            hasPending = false
            notice = "Profile loaded. Review the changes, then apply or accept them."
            return true
        }
        function cancelImport() {
            cancelled = true
            hasPending = false
            notice = ""
        }
        function exportTo(url) { return true }
    }

    Component {
        id: fixture
        SettingsProfilePage { exchange: fakeExchange }
    }

    function resetFake() {
        fakeExchange.notice = ""
        fakeExchange.noticeIsError = false
        fakeExchange.pendingSummary = ""
        fakeExchange.hasPending = false
        fakeExchange.confirmed = false
        fakeExchange.cancelled = false
    }

    function test_approvedCopyAndFocus() {
        resetFake()
        const page = createTemporaryObject(fixture, test)
        verify(page !== null)
        const description = findChild(page, "dockProfileDescription")
        const includesLabel = findChild(page, "dockProfileIncludesLabel")
        const includes = findChild(page, "dockProfileIncludes")
        const excludesLabel = findChild(page, "dockProfileExcludesLabel")
        const excludes = findChild(page, "dockProfileExcludes")
        const note = findChild(page, "dockProfileExportNote")
        const importButton = findChild(page, "importDockProfile")
        const exportButton = findChild(page, "exportDockProfile")
        verify(description !== null && includesLabel !== null && includes !== null
            && excludesLabel !== null && excludes !== null && note !== null
            && importButton !== null && exportButton !== null)
        compare(description.text, "A profile is a portable JSON file.")
        compare(includesLabel.text, "Includes:")
        compare(includes.text, "dock items and their order, folder containers and dock preferences.")
        compare(excludesLabel.text, "Does not include:")
        compare(excludes.text, "autostart, KDE settings, files on disk or live state such as open windows and update counts.")
        compare(note.text, "Export includes pending changes.")
        compare(importButton.text, "Import…")
        compare(exportButton.text, "Export…")
        compare(importButton.Accessible.name, "Import profile")
        compare(exportButton.Accessible.name, "Export profile")
        page.focusFirst()
        tryCompare(importButton, "activeFocus", true)
    }

    function test_scopeCopyWrapsAtNarrowWidth() {
        resetFake()
        const page = createTemporaryObject(fixture, test)
        page.width = 280
        const includes = findChild(page, "dockProfileIncludes")
        const excludes = findChild(page, "dockProfileExcludes")
        verify(includes !== null && excludes !== null)
        tryVerify(() => includes.width > 0 && excludes.width > 0)
        tryVerify(() => includes.lineCount > 1 && excludes.lineCount > 1)
        verify(!includes.truncated)
        verify(!excludes.truncated)
    }

    function test_confirmationRequestsAndCancelKeepsControl() {
        resetFake()
        const page = createTemporaryObject(fixture, test)
        const dialog = findChild(page, "dockProfileImportConfirmation")
        verify(dialog !== null)
        fakeExchange.pendingSummary = "12 dock items and 2 folder containers"
        fakeExchange.hasPending = true
        fakeExchange.importReady()
        tryCompare(dialog, "visible", true)
        compare(dialog.title, "Replace profile?")
        compare(dialog.subtitle, "The file contains 12 dock items and 2 folder containers. Current values will be replaced. Changes remain pending until you apply or accept them.")
        const cancel = dialog.standardButton(Kirigami.Dialog.Cancel)
        verify(cancel !== null)
        tryCompare(cancel, "activeFocus", true)
        keyClick(Qt.Key_Escape)
        tryCompare(dialog, "visible", false)
        verify(fakeExchange.cancelled)
        verify(!fakeExchange.confirmed)
    }

    function test_replaceActionConfirms() {
        resetFake()
        const page = createTemporaryObject(fixture, test)
        const dialog = findChild(page, "dockProfileImportConfirmation")
        fakeExchange.pendingSummary = "2 dock items and 1 folder containers"
        fakeExchange.hasPending = true
        fakeExchange.importReady()
        tryCompare(dialog, "visible", true)
        compare(dialog.customFooterActions.length, 1)
        compare(dialog.customFooterActions[0].text, "Replace")
        dialog.customFooterActions[0].trigger()
        tryCompare(dialog, "visible", false)
        verify(fakeExchange.confirmed)
    }
}
