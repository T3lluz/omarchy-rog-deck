"""bin/rog-deck-power's checks and bin/rog-deck's CPU limit maths.

Run with: python3 -B -m unittest discover tests
"""

import importlib.util
import os
import tempfile
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
                     ["panel-power"], ["panel-power", "5"], ["panel-power", "-1"], ["panel-power", "1", "2"],
                     ["epp"], ["epp", "turbo"], ["epp", "performance", "power"], ["epp", "../../etc/passwd"],
                     ["epp", "default"]):
            with self.assertRaises(helper.Failure, msg=argv):
                helper.main(argv)


class EnergyPreference(unittest.TestCase):
    def write_with(self, cores, value):
        """Run the helper's `epp <value>` on made-up cores; returns what each holds after.

        None is an offline core. Its file is there, as on real hardware, but
        can be neither read nor written: here it is a directory of that name.
        """
        real = helper.EPP_PATHS
        with tempfile.TemporaryDirectory() as folder:
            helper.EPP_PATHS = os.path.join(folder, "policy*", "energy_performance_preference")
            for index, current in enumerate(cores):
                path = os.path.join(folder, "policy%d" % index, "energy_performance_preference")
                if current is None:
                    os.makedirs(path)
                    continue
                os.makedirs(os.path.dirname(path))
                with open(path, "w") as f:
                    f.write(current + "\n")
            try:
                helper.epp([value])
                return [helper.read(os.path.join(folder, "policy%d" % index, "energy_performance_preference"))
                        for index in range(len(cores))]
            finally:
                helper.EPP_PATHS = real

    def test_every_core_is_written(self):
        self.assertEqual(self.write_with(["balance_power"] * 12, "performance"), ["performance"] * 12)

    def test_an_offline_core_does_not_stop_the_rest(self):
        # policy10 sorts before policy2, so stopping at it would leave policy11 and policy2-9 unwritten.
        cores = ["balance_power"] * 10 + [None, "balance_power"]
        self.assertEqual(self.write_with(cores, "performance"), ["performance"] * 10 + [None, "performance"])

    def test_a_core_that_refuses_the_write_fails(self):
        real = helper.write
        def refuse(path, value):
            raise helper.Failure("could not write %s: Device or resource busy" % path)
        helper.write = refuse
        try:
            with self.assertRaises(helper.Failure):
                self.write_with(["balance_power"], "performance")
        finally:
            helper.write = real

    def test_no_energy_preference_fails(self):
        with self.assertRaises(helper.Failure):
            self.write_with([], "performance")


class FullSpeed(unittest.TestCase):
    def test_handing_back_follows_power_profiles_daemon(self):
        self.assertEqual(backend.ppd_epp("performance", True), "performance")
        self.assertEqual(backend.ppd_epp("performance", False), "performance")
        self.assertEqual(backend.ppd_epp("balanced", True), "balance_performance")
        self.assertEqual(backend.ppd_epp("balanced", False), "balance_power")
        self.assertEqual(backend.ppd_epp("power-saver", True), "power")
        for value in ("performance", "balance_performance", "balance_power", "power"):
            self.assertIn(value, helper.EPP)

    def run_speed(self, command, epp, held, profile="balanced", ac=True, governor="powersave", helper="ok"):
        """Run `speed <command>` against a made-up machine; return the helper calls and whether it is held after."""
        calls = []
        names = ("power_helper", "cpu_setting", "ppd_props", "on_battery", "power_status", "SPEED_HELD")
        saved = {name: getattr(backend, name) for name in names}
        with tempfile.TemporaryDirectory() as folder:
            backend.SPEED_HELD = os.path.join(folder, "rog-deck", "speed-held")
            if held:
                os.makedirs(os.path.dirname(backend.SPEED_HELD))
                open(backend.SPEED_HELD, "w").close()
            backend.power_helper = lambda *args: calls.append(args)
            backend.cpu_setting = lambda name: epp if name == "energy_performance_preference" else governor
            backend.ppd_props = lambda: {"ActiveProfile": profile}
            backend.on_battery = lambda: not ac
            backend.power_status = lambda: {"helper": helper}
            try:
                backend.speed([command])
                return calls, os.path.exists(backend.SPEED_HELD)
            finally:
                for name, value in saved.items():
                    setattr(backend, name, value)

    def test_on_writes_performance_and_notes_it(self):
        self.assertEqual(self.run_speed("on", "balance_performance", False), ([("epp", "performance")], True))
        self.assertEqual(self.run_speed("on", "balance_power", True), ([("epp", "performance")], True))
        self.assertEqual(self.run_speed("on", "mixed", True), ([("epp", "performance")], True))
        # Already performance in Balanced (left by a logout): claimed, nothing written.
        self.assertEqual(self.run_speed("on", "performance", False), ([], True))

    def test_on_does_nothing_outside_balanced_on_the_charger(self):
        # The mode or charger changed while the command waited in the queue.
        self.assertEqual(self.run_speed("on", "power", False, profile="power-saver"), ([], False))
        self.assertEqual(self.run_speed("on", "performance", False, profile="performance"), ([], False))
        self.assertEqual(self.run_speed("on", "balance_power", False, ac=False), ([], False))
        # A CPU driver with no energy preference.
        self.assertEqual(self.run_speed("on", None, False), ([], False))

    def test_on_without_a_working_helper_claims_nothing(self):
        for state in ("missing", "outdated"):
            with self.assertRaises(backend.Failure):
                self.run_speed("on", "balance_performance", False, helper=state)

    def test_off_hands_back_only_what_it_set(self):
        self.assertEqual(self.run_speed("off", "performance", True), ([("epp", "balance_performance")], False))
        self.assertEqual(self.run_speed("off", "performance", True, ac=False), ([("epp", "balance_power")], False))
        self.assertEqual(self.run_speed("off", "mixed", True, ac=False), ([("epp", "balance_power")], False))
        self.assertEqual(self.run_speed("off", "performance", True, profile="power-saver"), ([("epp", "power")], False))
        # power-profiles-daemon already wrote its own, or Turbo wants performance anyway.
        self.assertEqual(self.run_speed("off", "balance_power", True, ac=False), ([], False))
        self.assertEqual(self.run_speed("off", "performance", True, profile="performance", governor="performance"), ([], False))
        # A performance preference someone else set stays.
        self.assertEqual(self.run_speed("off", "performance", False), ([], False))

    def test_off_waits_when_the_mode_cannot_be_read(self):
        # power-profiles-daemon didn't answer: guessing could overwrite Silent's value.
        self.assertEqual(self.run_speed("off", "performance", True, profile=None), ([], True))
        self.assertEqual(self.run_speed("on", "balance_performance", False, profile=None), ([], False))

    def test_off_waits_while_something_holds_the_performance_governor(self):
        # The kernel would refuse the write; the note stays for the next trigger.
        self.assertEqual(self.run_speed("off", "performance", True, ac=False, governor="performance"), ([], True))
        self.assertEqual(self.run_speed("off", "performance", True, ac=False, governor="mixed"), ([], True))

    def test_cpu_setting_reports_cores_that_disagree(self):
        real = backend.CPU_POLICIES
        with tempfile.TemporaryDirectory() as folder:
            backend.CPU_POLICIES = os.path.join(folder, "policy*")
            try:
                self.assertIsNone(backend.cpu_setting("energy_performance_preference"))
                for index, value in enumerate(("performance", "performance")):
                    os.makedirs(os.path.join(folder, "policy%d" % index))
                    with open(os.path.join(folder, "policy%d" % index, "energy_performance_preference"), "w") as f:
                        f.write(value + "\n")
                self.assertEqual(backend.cpu_setting("energy_performance_preference"), "performance")
                with open(os.path.join(folder, "policy1", "energy_performance_preference"), "w") as f:
                    f.write("balance_power\n")
                self.assertEqual(backend.cpu_setting("energy_performance_preference"), "mixed")
                self.assertIsNone(backend.cpu_setting("scaling_governor"))
            finally:
                backend.CPU_POLICIES = real


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
