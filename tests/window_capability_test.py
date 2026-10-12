#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Do not mistake missing window access for an empty or validated desktop."""

import importlib.util
from pathlib import Path
import unittest
import sys

sys.dont_write_bytecode = True

path = Path(__file__).resolve().parents[1] / 'scripts-dev/probe-kde-windows.py'
spec = importlib.util.spec_from_file_location('window_probe', path)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class CapabilityStates(unittest.TestCase):
    registry = "interface: 'org_kde_plasma_window_management', version: 18, name: 25"
    denied = "PlasmaWindowManagement protocol hasn't activated in time."

    def test_rejected_access_is_not_clear_region(self):
        result = probe.classify('', self.denied + '\nPUNCHI_WINDOW_MODEL_COUNT 0', 0)
        self.assertEqual(result['state'], 'access-unavailable')
        self.assertFalse(result['intersection_detection_validated'])

    def test_empty_model_is_unverified(self):
        result = probe.classify(self.registry, 'PUNCHI_WINDOW_MODEL_COUNT 0', 0)
        self.assertEqual(result['state'], 'empty-model-unverified')

    def test_observed_windows_do_not_prove_geometry(self):
        result = probe.classify(self.registry, 'PUNCHI_WINDOW_MODEL_COUNT 3', 0)
        self.assertEqual(result['state'], 'window-model-observed')
        self.assertEqual(result['task_model_count'], 3)
        self.assertFalse(result['intersection_detection_validated'])

    def test_advertised_but_not_activated_is_failure(self):
        result = probe.classify(self.registry, self.denied + '\nPUNCHI_WINDOW_MODEL_COUNT 0', 0)
        self.assertEqual(result['state'], 'activation-failed')

    def test_foreign_protocol_does_not_substitute_kde_access(self):
        registry = "interface: 'zwlr_foreign_toplevel_manager_v1', version: 3, name: 8"
        result = probe.classify(registry, 'PUNCHI_WINDOW_MODEL_COUNT 0', 0)
        self.assertTrue(result['foreign_toplevel_management_advertised'])
        self.assertEqual(result['state'], 'protocol-unavailable')

    def test_errors_and_missing_evidence_are_explicit(self):
        for log, code in [('PUNCHI_WINDOW_MODEL_COUNT 0', 1), ('', 0),
                          ('ERROR Type unavailable\nPUNCHI_WINDOW_MODEL_COUNT 0', 0)]:
            self.assertEqual(probe.classify(self.registry, log, code)['state'], 'probe-error')


if __name__ == '__main__':
    unittest.main()
