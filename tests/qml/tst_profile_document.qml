// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../config/DefaultProfile.js" as DefaultProfile
import "../../config/ProfileDocument.js" as ProfileDocument

TestCase {
    name: "ProfileDocument"

    function test_first_run_profile_is_a_valid_document() {
        const defaults = DefaultProfile.fresh()
        compare(defaults.version, 11)
        const parsed = ProfileDocument.parse(ProfileDocument.serialize(defaults))
        verify(parsed.ok)
        compare(parsed.profile.version, 11)
        compare(parsed.profile.pinnedIds.length, defaults.pinnedIds.length)
        compare(parsed.profile.containers.length, defaults.containers.length)
    }

    function test_fresh_profile_is_independent() {
        const first = DefaultProfile.fresh()
        first.pinnedIds.push("desktop:example.desktop")
        first.containers[0].title = "changed"
        const second = DefaultProfile.fresh()
        verify(second.pinnedIds.indexOf("desktop:example.desktop") < 0)
        compare(second.containers[0].title, "Downloads")
    }

    function test_raw_saved_profile_is_accepted() {
        const raw = JSON.stringify({version: 11, dockEdge: "left", sizePercent: 125})
        const parsed = ProfileDocument.parse(raw)
        verify(parsed.ok)
        compare(parsed.profile.dockEdge, "left")
        compare(parsed.profile.sizePercent, 125)
    }

    function test_roundtrip_preserves_a_complete_profile() {
        const profile = DefaultProfile.fresh()
        profile.dockEdge = "right"
        profile.panelMode = "autohide"
        profile.pinnedIds = ["files", "browser", "item:trash"]
        profile.containers = [{
            id: "downloads", path: "", title: "Downloads", icon: "folder-downloads",
            layout: "list", sortMode: "size", browseSubfolders: false, hiddenEntries: ["a.txt"]
        }]
        const parsed = ProfileDocument.parse(ProfileDocument.serialize(profile))
        verify(parsed.ok)
        verify(JSON.stringify(parsed.profile) === JSON.stringify(profile))
    }

    function test_rejects_malformed_documents() {
        compare(ProfileDocument.parse("").reason, "invalid-json")
        compare(ProfileDocument.parse("{").reason, "invalid-json")
        compare(ProfileDocument.parse("[]").reason, "not-profile")
        compare(ProfileDocument.parse(JSON.stringify({version: 0})).reason, "not-profile")
        compare(ProfileDocument.parse(JSON.stringify({version: 12})).reason, "newer")
        compare(ProfileDocument.parse(JSON.stringify({schema: "other", version: 1,
            profile: {version: 11}})).reason, "not-profile")
        compare(ProfileDocument.parse(JSON.stringify({schema: "punchi-dock-quickshell/profile",
            version: 2, profile: {version: 11}})).reason, "newer")
        compare(ProfileDocument.parse(JSON.stringify({schema: "punchi-dock-quickshell/profile",
            version: 1, profile: {version: 12}})).reason, "newer")
         compare(ProfileDocument.parse(" ".repeat(ProfileDocument.maximumBytes + 1)).reason,
            "too-large")
    }

    function test_rejects_invalid_fields() {
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            pinnedIds: ["files", "files"]})).reason, "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            pinnedIds: ["../outside"]})).reason, "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11, sizePercent: 10})).reason,
            "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11, popupScale: 2})).reason,
            "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11, dockEdge: "top"})).reason,
            "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            panelMode: "unknown"})).reason, "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            containers: [{id: "downloads", path: "relative", title: "Downloads",
                icon: "folder-downloads"}]})).reason, "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            containers: [{id: "downloads", path: "", title: "Downloads",
                icon: "folder-downloads", hiddenEntries: ["../escape"]}]})).reason,
            "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            iconOverrides: {"files": "../escape"}})).reason, "invalid-field")
        compare(ProfileDocument.parse(JSON.stringify({version: 11,
            recentApplicationsCount: true})).reason, "invalid-field")
    }

    function test_rejects_prototype_keys() {
        compare(ProfileDocument.parse('{"version":11,"__proto__":{"polluted":true}}').reason,
            "invalid-field")
        compare(ProfileDocument.parse('{"version":11,"constructor":{"prototype":{}}}').reason,
            "invalid-field")
    }
}
