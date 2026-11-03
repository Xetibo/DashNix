import importlib.util
import json
import subprocess
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "monitor", Path(__file__).parents[1] / "scripts/security-monitor.py"
)
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


def finding(cve="CVE-2026-12345", score=8.1, **extra):
    return {"package": "example", "version": "1.0", "cve": cve, "score": score, **extra}


def record(score=8.1):
    return {
        "pname": "example",
        "name": "example-1.0",
        "version": "1.0",
        "affected_by": ["CVE-2026-12345"],
        "cvssv3_basescore": {"CVE-2026-12345": score},
    }


def lock(revision="old"):
    return {
        "root": "root",
        "nodes": {
            "root": {
                "inputs": {
                    "nixpkgs": "packages",
                    "followed": ["nixpkgs"],
                    "graphics": "graphics",
                }
            },
            "packages": {"locked": {"rev": revision}},
            "graphics": {"locked": {"rev": "pinned"}},
        },
    }


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = {
            "state_directory": str(self.root / "state"),
            "notification_state": str(self.root / "notifications"),
            "extra_profiles": [],
            "known_exploited": True,
            "whitelist": None,
            "update_inputs": [],
            "flake_path": None,
            "cvss_threshold": 7,
            "vulnix": "vulnix",
            "nix": "nix",
            "notify_send": "notify-send",
        }
        self.state = Path(self.config["state_directory"])
        self.state.mkdir()

    def report(self, now=1000000, findings=None, **extra):
        return {
            "generated_at": now,
            "last_success": now,
            "findings": findings or [],
            "updates": [],
            "errors": [],
            **extra,
        }

    def test_parse_pinned_vulnix_schema_deduplicates_and_preserves_unknown_scores(self):
        records = [record(), record(), record(None)]
        parsed = monitor.parse_findings(records)
        self.assertEqual(len(parsed), 1)
        self.assertEqual(parsed[0]["score"], 8.1)
        self.assertEqual(monitor.parse_findings([record(None)])[0]["score"], None)
        self.assertEqual(
            monitor.parse_findings([record(None), record(0)])[0]["score"], 0
        )
        self.assertEqual(monitor.parse_findings([]), [])

    def test_malformed_scan_output_never_counts_as_clean(self):
        for data in (
            {},
            [None],
            [{"affected_by": []}],
            [record(float("nan"))],
            [record(True)],
            [record(11)],
        ):
            with self.subTest(data=data), self.assertRaises((ValueError, TypeError)):
                monitor.parse_findings(data)

    def test_scan_exit_two_requires_valid_findings(self):
        with (
            patch.object(monitor, "scan_profiles", return_value=["/nix/store/system"]),
            patch.object(
                monitor,
                "command",
                return_value=subprocess.CompletedProcess([], 2, "[]", ""),
            ),
            self.assertRaisesRegex(ValueError, "exit status"),
        ):
            monitor.scan(self.config, self.state)

    def test_scan_uses_only_runtime_closures_and_supports_whitelist(self):
        self.config["whitelist"] = "/runtime/reviewed.toml"
        result = subprocess.CompletedProcess([], 2, json.dumps([record()]), "")
        with (
            patch.object(
                monitor,
                "scan_profiles",
                return_value=["/nix/store/system", "/nix/store/home"],
            ),
            patch.object(monitor, "command", return_value=result) as run,
        ):
            findings, profiles = monitor.scan(self.config, self.state)
        argv = run.call_args.args[0]
        self.assertIn("--closure", argv)
        self.assertNotIn("--kev", argv)
        self.assertIn("/runtime/reviewed.toml", argv)
        self.assertIn("/nix/store/home", profiles)
        self.assertEqual(len(findings), 1)

    def test_unused_dangling_user_profile_does_not_prevent_system_scan(self):
        home = self.root / "home"
        home.mkdir()
        (home / ".nix-profile").symlink_to(home / "missing")
        extra = self.root / "active profile"
        extra.mkdir()
        exists = Path.exists
        with patch.object(
            Path,
            "exists",
            lambda path: path == Path("/run/current-system") or exists(path),
        ):
            profiles = monitor.scan_profiles(home, [str(extra)])
            self.assertIn(str(extra), profiles)
            self.assertNotIn(str(home / "missing"), profiles)
            with self.assertRaisesRegex(ValueError, "Missing required"):
                monitor.scan_profiles(home, [str(home / "missing")])

    def test_failed_scan_retains_findings_and_reports_failure(self):
        previous = self.report(findings=[finding()], last_success=123)
        monitor.write_json(self.state / "report.json", previous)
        with (
            patch.object(monitor, "scan", side_effect=ValueError("unavailable")),
            patch.object(monitor, "fetch_kev", return_value=set()),
        ):
            self.assertEqual(monitor.collect(self.config, now=1000000), 1)
        report = monitor.read_json(self.state / "report.json")
        self.assertEqual(report["last_success"], 123)
        self.assertEqual(len(report["findings"]), 1)
        self.assertIn("unavailable", report["errors"][0])

    def test_failed_kev_refresh_does_not_downgrade_known_exploited(self):
        monitor.write_json(
            self.state / "kev.json", {"vulnerabilities": [{"cveID": "CVE-2026-12345"}]}
        )
        with (
            patch.object(
                monitor, "scan", return_value=([finding(score=None)], ["/system"])
            ),
            patch.object(monitor, "fetch_kev", side_effect=OSError("offline")),
        ):
            self.assertEqual(monitor.collect(self.config, now=1000000), 1)
        report = monitor.read_json(self.state / "report.json")
        self.assertTrue(monitor.is_high(report["findings"][0], self.config))
        self.assertIn("CISA", report["errors"][0])

    def test_successful_empty_scan_is_not_a_failure(self):
        with (
            patch.object(monitor, "scan", return_value=([], ["/system"])),
            patch.object(monitor, "fetch_kev", return_value=set()),
        ):
            self.assertEqual(monitor.collect(self.config, now=1000000), 0)
        report = monitor.read_json(self.state / "report.json")
        self.assertEqual(report["last_success"], 1000000)
        self.assertEqual(report["errors"], [])

    def test_kev_rejects_stale_and_malformed_catalog(self):
        catalog = {
            "dateReleased": "2026-11-01T00:00:00Z",
            "vulnerabilities": [{"cveID": "CVE-2026-12345"}],
        }
        now = datetime(2026, 11, 3, tzinfo=UTC).timestamp()
        self.assertEqual(monitor.kev_ids(catalog, now), {"CVE-2026-12345"})
        with self.assertRaisesRegex(ValueError, "stale"):
            monitor.kev_ids(catalog, now + 20 * monitor.DAY)
        catalog["vulnerabilities"] = []
        with self.assertRaises(ValueError):
            monitor.kev_ids(catalog, now)

    def test_lock_follows_resolved_and_pins_preserved(self):
        self.assertEqual(monitor.locked_input(lock(), "followed"), {"rev": "old"})
        cyclic = lock()
        cyclic["nodes"]["root"]["inputs"]["followed"] = ["followed"]
        with self.assertRaisesRegex(ValueError, "Cyclic"):
            monitor.locked_input(cyclic, "followed")

    def prepare_checkout(self):
        source = self.root / "dirty checkout"
        source.mkdir()
        (source / "flake.lock").write_text(json.dumps(lock()))
        (source / "flake.nix").write_text("local uncommitted work")
        self.config.update(flake_path=str(source), update_inputs=["nixpkgs"])
        return source

    def test_update_check_writes_only_temporary_candidate(self):
        source = self.prepare_checkout()
        original = (source / "flake.lock").read_bytes()

        def run(argv, **kwargs):
            self.assertNotIn("--accept-flake-config", argv)
            self.assertIn("allow-import-from-derivation", argv)
            self.assertEqual(argv[-1], "nixpkgs")
            candidate = Path(argv[argv.index("--output-lock-file") + 1])
            self.assertTrue(candidate.is_relative_to(self.state))
            candidate.write_text(json.dumps(lock("new")))
            return subprocess.CompletedProcess(argv, 0, "", "")

        with patch.object(monitor, "command", side_effect=run):
            changes = monitor.check_updates(self.config, self.state)
        self.assertEqual(changes[0]["input"], "nixpkgs")
        self.assertEqual((source / "flake.lock").read_bytes(), original)
        self.assertEqual((source / "flake.nix").read_text(), "local uncommitted work")
        self.assertEqual(list(self.state.glob("update-*")), [])

    def test_update_failure_does_not_become_no_updates(self):
        self.prepare_checkout()
        with (
            patch.object(
                monitor,
                "command",
                return_value=subprocess.CompletedProcess([], 1, "", "offline"),
            ),
            self.assertRaisesRegex(ValueError, "Input check failed"),
        ):
            monitor.check_updates(self.config, self.state)

    def test_missing_and_store_update_sources_are_rejected(self):
        self.config.update(
            flake_path="/nix/store/nonexistent", update_inputs=["nixpkgs"]
        )
        with self.assertRaisesRegex(ValueError, "runtime checkout"):
            monitor.check_updates(self.config, self.state)
        source = self.prepare_checkout()
        self.config["update_inputs"] = ["typo"]
        with self.assertRaises(KeyError):
            monitor.check_updates(self.config, self.state)
        self.assertTrue((source / "flake.lock").exists())

    def test_critical_normal_unknown_and_stale_classification(self):
        report = self.report(
            findings=[finding(score=7), finding(score=None, cve="CVE-2026-22222")]
        )
        report["updates"] = [{"input": "nixpkgs"}]
        groups = monitor.notification_groups(report, self.config, 1000000)
        self.assertEqual(
            [(g[0], g[1]) for g in groups],
            [("advisories", "critical"), ("review", "normal"), ("updates", "normal")],
        )
        stale = monitor.notification_groups(
            report, self.config, 1000000 + 3 * monitor.DAY
        )
        self.assertEqual(stale[-1][0], "errors")
        self.assertTrue(
            monitor.is_high(finding(score=1, known_exploited=True), self.config)
        )

    def test_notifications_deduplicate_remind_and_escape_markup(self):
        report = self.report(findings=[finding(package="<unsafe>&")])
        monitor.write_json(self.state / "report.json", report)
        with patch.object(
            monitor, "command", return_value=subprocess.CompletedProcess([], 0, "", "")
        ) as run:
            monitor.notify(self.config, now=1000000)
            monitor.notify(self.config, now=1000001)
            self.assertEqual(run.call_count, 1)
            argv = run.call_args.args[0]
            self.assertIn("--urgency=critical", argv)
            self.assertIn("&lt;unsafe&gt;&amp;", argv[-1])
            monitor.notify(self.config, now=1000000 + monitor.DAY)
            self.assertEqual(run.call_count, 2)

    def test_failed_delivery_is_retried_without_acknowledging(self):
        monitor.write_json(
            self.state / "report.json", self.report(findings=[finding()])
        )
        with (
            patch.object(
                monitor,
                "command",
                return_value=subprocess.CompletedProcess([], 1, "", "no bus"),
            ),
            self.assertRaises(RuntimeError),
        ):
            monitor.notify(self.config, now=1000000)
        self.assertFalse(
            (Path(self.config["notification_state"]) / "sent.json").exists()
        )

    def test_resolved_findings_are_forgotten_so_recurrence_alerts(self):
        with patch.object(
            monitor, "command", return_value=subprocess.CompletedProcess([], 0, "", "")
        ) as run:
            monitor.write_json(
                self.state / "report.json", self.report(findings=[finding()])
            )
            monitor.notify(self.config, now=1000000)
            monitor.write_json(self.state / "report.json", self.report())
            monitor.notify(self.config, now=1000001)
            monitor.write_json(
                self.state / "report.json", self.report(findings=[finding()])
            )
            monitor.notify(self.config, now=1000002)
            self.assertEqual(run.call_count, 2)

    def test_missing_corrupt_or_unreadable_report_is_a_visible_warning(self):
        for data in (None, "not JSON", "[]", "{}"):
            with self.subTest(data=data):
                if data is None:
                    (self.state / "report.json").unlink(missing_ok=True)
                else:
                    (self.state / "report.json").write_text(data)
                with patch.object(
                    monitor,
                    "command",
                    return_value=subprocess.CompletedProcess([], 0, "", ""),
                ) as run:
                    monitor.notify(self.config, now=1000000)
                self.assertEqual(run.call_count, 1)
                self.assertIn("--urgency=normal", run.call_args.args[0])
                self.assertIn("Security report unavailable", run.call_args.args[0][-1])
        with (
            patch.object(
                monitor, "read_json", side_effect=PermissionError("report inaccessible")
            ),
            patch.object(
                monitor,
                "command",
                return_value=subprocess.CompletedProcess([], 0, "", ""),
            ) as run,
        ):
            monitor.notify(self.config, now=1000000)
        self.assertIn("report inaccessible", run.call_args.args[0][-1])

    def test_cisa_refresh_and_corrupt_cache_failure_preserve_previous_kev(self):
        monitor.write_json(
            self.state / "report.json",
            self.report(findings=[finding(score=None, known_exploited=True)]),
        )
        (self.state / "kev.json").write_text("not JSON")
        with (
            patch.object(
                monitor, "scan", return_value=([finding(score=None)], ["/system"])
            ),
            patch.object(monitor, "fetch_kev", side_effect=OSError("offline")),
        ):
            self.assertEqual(monitor.collect(self.config, now=1000000), 1)
        report = monitor.read_json(self.state / "report.json")
        self.assertTrue(report["findings"][0]["known_exploited"])
        self.assertEqual(len(report["errors"]), 2)


if __name__ == "__main__":
    unittest.main()
