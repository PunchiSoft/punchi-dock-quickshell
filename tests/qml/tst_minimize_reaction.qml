// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../../components"
TestCase {
    id: test
    name: "DockMinimizeReaction"
    when: windowShown
    width: 320
    height: 120

    Component {
        id: fixture
        PunchiDockMinimizeReaction {
            iconSize: 48
        }
    }

    function createReaction(mode, itemIndex, targetIndex, vertical) {
        const reaction = createTemporaryObject(fixture, test)
        reaction.mode = mode
        reaction.itemIndex = itemIndex
        reaction.targetIndex = targetIndex
        reaction.vertical = !!vertical
        return reaction
    }

    function test_slowBounceMovesOnlyTheTargetAndSettles() {
        const reaction = createReaction("slowBounce", 2, 2, false)
        reaction.revision = 1
        verify(reaction.running)
        tryVerify(function() { return Math.abs(reaction.verticalOffset) > 0 }, 1000)
        compare(reaction.horizontalOffset, 0)
        tryVerify(function() { return !reaction.running }, Kirigami.Units.longDuration * 6 + 1000)
        compare(reaction.displacement, 0)
    }

    function test_slowBounceSkipsNeighbours() {
        const reaction = createReaction("slowBounce", 1, 2, false)
        reaction.revision = 1
        verify(!reaction.running)
        compare(reaction.displacement, 0)
    }

    function test_lateralRippleReachesNearNeighboursOnly() {
        const near = createReaction("lateralRipple", 1, 2, false)
        near.revision = 1
        verify(near.running)
        const far = createReaction("lateralRipple", 4, 1, false)
        far.revision = 1
        verify(!far.running)
    }

    function test_verticalDockMovesAlongTheExpectedAxis() {
        const bounce = createReaction("slowBounce", 0, 0, true)
        bounce.revision = 1
        verify(bounce.running)
        tryVerify(function() { return Math.abs(bounce.horizontalOffset) > 0 }, 1000)
        compare(bounce.verticalOffset, 0)

        const ripple = createReaction("lateralRipple", 0, 0, true)
        ripple.revision = 1
        verify(ripple.running)
        tryVerify(function() { return Math.abs(ripple.verticalOffset) > 0 }, 1000)
        compare(ripple.horizontalOffset, 0)
    }

    function test_reducedMotionAndNoneStayStill() {
        const reduced = createReaction("slowBounce", 0, 0, false)
        reduced.motionEnabled = false
        reduced.revision = 1
        verify(!reduced.running)
        compare(reduced.displacement, 0)

        const none = createReaction("none", 0, 0, false)
        none.revision = 1
        verify(!none.running)
        compare(none.displacement, 0)
    }
}
