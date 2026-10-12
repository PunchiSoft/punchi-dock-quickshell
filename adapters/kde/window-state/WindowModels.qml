// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQml
import org.kde.taskmanager as TaskManager

QtObject {
    id: root
    readonly property TaskManager.ActivityInfo activityInfo: TaskManager.ActivityInfo {}
    // Running markers include minimized windows and other desktops/activities.
    readonly property TaskManager.TasksModel allTasks: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: false
        filterHidden: false
        filterByVirtualDesktop: false
        filterByActivity: false
    }
    // The visibility projection follows Plasma's panel model contract.
    readonly property TaskManager.TasksModel visibleTasks: TaskManager.TasksModel {
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: true
        filterHidden: true
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
        activity: root.activityInfo.currentActivity
    }
}
