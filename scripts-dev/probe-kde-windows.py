#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Read-only standalone KDE window-access diagnostic; never hides the dock."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

PROTOCOL = 'org_kde_plasma_window_management'
FOREIGN_PROTOCOL = 'zwlr_foreign_toplevel_manager_v1'


def classify(registry, model_log, model_returncode):
    advertised = set(re.findall(r"interface:\s*'([^']+)'", registry))
    counts = re.findall(r'PUNCHI_WINDOW_MODEL_COUNT\s+(\d+)', model_log)
    denied = "PlasmaWindowManagement protocol hasn't activated in time" in model_log
    result = {
        'plasma_window_management_advertised': PROTOCOL in advertised,
        'foreign_toplevel_management_advertised': FOREIGN_PROTOCOL in advertised,
        'task_model_count': int(counts[-1]) if counts else None,
        'protocol_activation_failed': denied,
        'state': 'unknown',
        'intersection_detection_validated': False,
    }
    if model_returncode or not counts or re.search(r'\bERROR\b|TypeError|ReferenceError|Binding loop', model_log):
        result['state'] = 'probe-error'
    elif denied and PROTOCOL not in advertised:
        result['state'] = 'access-unavailable'
    elif PROTOCOL not in advertised:
        result['state'] = 'protocol-unavailable'
    elif denied:
        result['state'] = 'activation-failed'
    elif result['task_model_count'] > 0:
        result['state'] = 'window-model-observed'
    else:
        # An empty model cannot prove current-desktop filtering or geometry.
        result['state'] = 'empty-model-unverified'
    return result


def main():
    root = Path(__file__).resolve().parents[1]
    missing = [tool for tool in ('qs', 'wayland-info') if not shutil.which(tool)]
    if missing:
        print(json.dumps({'state': 'missing-tools', 'tools': missing}, indent=2))
        return 1
    registry = subprocess.run(['wayland-info'], capture_output=True, text=True, timeout=8)
    if registry.returncode:
        print(json.dumps({'state': 'registry-probe-error'}, indent=2))
        return 1
    with tempfile.TemporaryDirectory(prefix='punchi-shell-window-probe-') as temporary:
        config = Path(temporary)
        (config / 'shell.qml').write_text('''import QtQuick
import Quickshell
import org.kde.taskmanager as TaskManager
ShellRoot {
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterMinimized: true
        filterHidden: true
    }
    Timer {
        interval: 1000
        running: true
        onTriggered: {
            console.warn("PUNCHI_WINDOW_MODEL_COUNT", tasks.count)
            Qt.quit()
        }
    }
}
''')
        # The parent runner owns child groups and XDG state through all exits.
        model = subprocess.run([
            'python3', str(root / 'scripts-dev/run-isolated.py'), '--session', '--',
            'qs', '--path', str(config), '--no-color',
        ], capture_output=True, text=True)
    result = classify(registry.stdout, model.stdout + model.stderr, model.returncode)
    print(json.dumps(result, indent=2))
    return 1 if result['state'] == 'probe-error' else 0


if __name__ == '__main__':
    raise SystemExit(main())
