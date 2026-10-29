"""bin/rog-deck-power's checks and bin/rog-deck's CPU limit maths.

Run with: python3 -B -m unittest discover tests
"""

import importlib.util
import os
import unittest
from importlib.machinery import SourceFileLoader

BIN = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "bin")


def load(name, filename):
    loader = SourceFileLoader(name, os.path.join(BIN, filename))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


helper = load("rog_deck_power", "rog-deck-power")
backend = load("rog_deck", "rog-deck")


class HelperChecks(unittest.TestCase):
    def table(self, ac):
        return helper.limits("GA402NV", ac=ac)

    def test_unknown_laptop_has_no_limits(self):
        self.assertIsNone(helper.limits("GA401QM", ac=True))
        with self.assertRaises(helper.Failure):
            helper.check({"spl": 15, "sppt": 25, "fppt": 35}, None)

    def test_battery_range(self):
        helper.check({"spl": 15, "sppt": 25, "fppt": 35}, self.table(False))
        helper.check({"spl": 35, "sppt": 35, "fppt": 65}, self.table(False))
        for bad in ({"spl": 14, "sppt": 25, "fppt": 35},   # below the sustained minimum
                    {"spl": 15, "sppt": 24, "fppt": 35},   # below the slow boost minimum
                    {"spl": 15, "sppt": 25, "fppt": 34},   # below the fast boost minimum
                    {"spl": 36, "sppt": 36, "fppt": 36},   # past the battery maximum
                    {"spl": 30, "sppt": 25, "fppt": 35}):  # sustained above slow boost
            with self.assertRaises(helper.Failure, msg=bad):
                helper.check(bad, self.table(False))

    def test_charger_range(self):
        helper.check({"spl": 80, "sppt": 80, "fppt": 80}, self.table(True))
        with self.assertRaises(helper.Failure):
            helper.check({"spl": 81, "sppt": 81, "fppt": 81}, self.table(True))

    def test_watts_are_plain_numbers(self):
        self.assertEqual(helper.parse_watts("15"), 15)
        for bad in ("", "-5", "15.5", "1e2", "15;reboot", "1000", None):
            with self.assertRaises(helper.Failure, msg=bad):
                helper.parse_watts(bad)

    def test_unknown_commands_fail(self):
        for argv in ([], ["ppt", "15"], ["wifi-powersave", "maybe"], ["write", "/etc/passwd"],
                     ["panel-power"], ["panel-power", "5"], ["panel-power", "-1"], ["panel-power", "1", "2"]):
            with self.assertRaises(helper.Failure, msg=argv):
                helper.main(argv)


class Triple(unittest.TestCase):
    def test_every_slider_value_passes_the_helper(self):
        for ac in (False, True):
            table = helper.limits("GA402NV", ac=ac)
            low, high = helper.LIMITS["GA402NV"]["dc"]["spl"]
            for watts in range(low, high + 1):
                spl, sppt, fppt = backend.ppt_triple(watts, table)
                helper.check({"spl": spl, "sppt": sppt, "fppt": fppt}, table)
                self.assertEqual(spl, watts)

    def test_boosts_raised_to_their_minimum(self):
        table = helper.limits("GA402NV", ac=False)
        self.assertEqual(backend.ppt_triple(15, table), (15, 25, 35))
        self.assertEqual(backend.ppt_triple(28, table), (28, 28, 35))
        self.assertEqual(backend.ppt_triple(35, table), (35, 35, 35))


if __name__ == "__main__":
    unittest.main()
