// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import org.kde.taskmanager as TaskManager

QtObject {
    id: root
    readonly property TaskManager.ActivityInfo activityInfo: TaskManager.ActivityInfo {}
    readonly property TaskManager.VirtualDesktopInfo virtualDesktopInfo: TaskManager.VirtualDesktopInfo {}
    // Running markers include minimized windows and other desktops/activities.
    readonly property TaskManager.TasksModel allTasks: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: false
        filterHidden: false
        filterByVirtualDesktop: false
        filterByActivity: false
    }
    // Running markers filtered to the active virtual desktop and activity.
    readonly property TaskManager.TasksModel currentDesktopTasks: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: false
        filterHidden: false
        // Follows the active desktop without Plasma 6.7's
        // filterByCurrentVirtualDesktop, which earlier releases lack.
        filterByVirtualDesktop: true
        virtualDesktop: root.virtualDesktopInfo.currentDesktop
        filterByActivity: true
        activity: root.activityInfo.currentActivity
    }
    // The visibility projection follows Plasma's panel model contract.
    readonly property TaskManager.TasksModel visibleTasks: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: true
        filterHidden: true
        filterByVirtualDesktop: true
        virtualDesktop: root.virtualDesktopInfo.currentDesktop
        filterByActivity: true
        activity: root.activityInfo.currentActivity
    }
}
