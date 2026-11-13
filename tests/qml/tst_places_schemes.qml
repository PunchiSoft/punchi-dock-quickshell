// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import Punchi.Kde as Native

TestCase {
    id: test
    name: "PlacesSchemes"

    Native.FilePlaces { id: places }

    function test_onlyLocalPlacesSchemesAreAccepted() {
        verify(places.acceptsUrl("file:///tmp/owned"))
        verify(places.acceptsUrl("trash:/"))
        verify(places.acceptsUrl("recentdocuments:/"))
        verify(places.acceptsUrl("activities:/"))
        verify(!places.acceptsUrl("file://remote/path"))
        verify(!places.acceptsUrl("smb://host/share"))
        verify(!places.acceptsUrl("sftp://host/share"))
        verify(!places.acceptsUrl("exec:/bin/sh"))
        verify(!places.acceptsUrl("applications:/"))
        verify(!places.acceptsUrl(""))
    }
}
