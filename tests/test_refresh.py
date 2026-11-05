"""bin/rog-deck's refresh rate switch.

Run with: python3 -B -m unittest discover tests
"""

import importlib.util
import os
import unittest
from importlib.machinery import SourceFileLoader
from unittest import mock

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")

loader = SourceFileLoader("rog_deck_refresh", os.path.join(BIN, "rog-deck"))
spec = importlib.util.spec_from_loader("rog_deck_refresh", loader)
backend = importlib.util.module_from_spec(spec)
loader.exec_module(backend)

PANEL = {
    "name": "eDP-2",
    "description": "Thermotrex Corporation TL140ADXP02-0",
    "width": 2560,
    "height": 1600,
    "refreshRate": 60.002,
    "availableModes": ["2560x1600@60.00Hz", "2560x1600@165.00Hz"],
    "x": 2150,
    "y": 145,
    "scale": 2.0,
}


class MonitorOutput(unittest.TestCase):
    def test_uses_the_description_hyprmoncfg_writes_its_rule_for(self):
        self.assertEqual(backend.monitor_output(PANEL), "desc:Thermotrex Corporation TL140ADXP02-0")

    def test_falls_back_to_the_connector_without_a_description(self):
        self.assertEqual(backend.monitor_output({"name": "eDP-1", "description": ""}), "eDP-1")

    def test_a_description_that_could_break_out_of_the_lua_string_is_not_used(self):
        evil = 'Panel" }) os.execute("reboot") hl.monitor({ output = "'
        self.assertEqual(backend.monitor_output({"name": "eDP-1", "description": evil}), "eDP-1")


class Refresh(unittest.TestCase):
    def test_never_sends_a_rule_for_the_connector_name(self):
        # Omarchy's clamshell flag is `hl.monitor({ output = "eDP-2", disabled = true })`.
        # A rule for the same output keeps that `disabled`, which blanks the panel.
        with mock.patch.object(backend, "panel_monitor", return_value=PANEL), \
                mock.patch.object(backend, "hold_rate") as hold, \
                mock.patch.object(backend, "act") as act:
            backend.refresh("165")
        code = act.call_args[0][0][2]
        self.assertEqual(code, 'hl.monitor({ output = "desc:Thermotrex Corporation TL140ADXP02-0", '
                               'mode = "2560x1600@165.00", position = "2150x145", scale = 2 })')
        hold.assert_called_once_with(165)

    def test_leaves_the_panel_alone_when_it_already_runs_the_rate(self):
        with mock.patch.object(backend, "panel_monitor", return_value=dict(PANEL, refreshRate=165.002)), \
                mock.patch.object(backend, "act") as act:
            backend.refresh("165")
        act.assert_not_called()


if __name__ == "__main__":
    unittest.main()
