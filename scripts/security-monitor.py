"""Unprivileged advisory collection and graphical-session report delivery."""

import argparse
import fcntl
import hashlib
import html
import json
import math
import os
import pwd
import re
import subprocess
import tempfile
import time
from datetime import datetime
from pathlib import Path
from urllib.request import urlopen

KEV_URL = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
CVE = re.compile(r"CVE-\d{4}-\d{4,}\Z")
DAY = 86400


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return default


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as out:
        temporary = Path(out.name)
        try:
            json.dump(value, out, indent=2, sort_keys=True, allow_nan=False)
            out.write("\n")
            out.flush()
            os.fsync(out.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    temporary.replace(path)


def command(argv, timeout=1800):
    return subprocess.run(
        argv, capture_output=True, text=True, timeout=timeout, check=False
    )


def scan_profiles(home, extras):
    username = pwd.getpwuid(os.getuid()).pw_name
    candidates = [
        Path("/run/current-system"),
        Path("/run/booted-system"),
        Path("/nix/var/nix/profiles/system"),
        home / ".nix-profile",
        home / ".local/state/nix/profiles/profile",
        home / ".local/state/nix/profiles/home-manager",
        Path("/nix/var/nix/profiles/per-user") / username / "home-manager",
        Path("/etc/profiles/per-user") / username,
    ]
    required = {Path("/run/current-system"), *(Path(p).expanduser() for p in extras)}
    profiles = set()
    for path in [*candidates, *sorted(required)]:
        if path.exists():
            profiles.add(str(path.resolve()))
        elif path in required:
            raise ValueError(f"Missing required runtime profile: {path}")
    return sorted(profiles)


def parse_findings(records):
    if not isinstance(records, list):
        raise TypeError("vulnix did not return a JSON array")
    findings = {}
    for record in records:
        if not isinstance(record, dict):
            raise TypeError("Invalid vulnix package record")
        for key in ("pname", "version", "name"):
            if not isinstance(record.get(key), str):
                raise TypeError(f"Invalid vulnix field: {key}")
        affected = record.get("affected_by")
        scores = record.get("cvssv3_basescore", {})
        if not isinstance(affected, list) or not isinstance(scores, dict):
            raise TypeError("Invalid vulnix CVE/score fields")
        for cve in affected:
            if not isinstance(cve, str) or not CVE.fullmatch(cve):
                raise ValueError("Invalid CVE identifier")
            score = scores.get(cve)
            if score is not None and (
                isinstance(score, bool)
                or not isinstance(score, (int, float))
                or not math.isfinite(score)
                or not 0 <= score <= 10
            ):
                raise ValueError("Invalid CVSS score")
            key = (record["pname"], record["version"], cve)
            finding = {
                "package": record["pname"],
                "version": record["version"],
                "cve": cve,
                "score": score,
                "url": f"https://nvd.nist.gov/vuln/detail/{cve}",
            }
            if key not in findings or (
                score is not None
                and (findings[key]["score"] is None or score > findings[key]["score"])
            ):
                findings[key] = finding
    return [findings[key] for key in sorted(findings)]


def scan(config, state):
    profiles = scan_profiles(Path.home(), config["extra_profiles"])
    argv = [
        config["vulnix"],
        "--closure",
        "--json",
        "--cache-dir",
        str(state / "cache/vulnix"),
    ]
    if config["whitelist"]:
        argv.extend(["--whitelist", config["whitelist"]])
    result = command([*argv, *profiles])
    (state / "vulnix.log").write_text(result.stderr[-16384:])
    if (
        result.returncode not in (0, 2)
        or "Traceback (most recent call last)" in result.stderr
    ):
        raise ValueError(
            f"vulnix failed (exit {result.returncode}); see {state}/vulnix.log"
        )
    findings = parse_findings(json.loads(result.stdout))
    # vulnix also returns 2 on runtime errors; an empty/invalid result is not a clean scan.
    if (result.returncode == 2) != bool(findings):
        raise ValueError("vulnix exit status disagrees with its findings")
    write_json(state / "vulnix.json", json.loads(result.stdout))
    return findings, profiles


def kev_ids(catalog, now):
    released = datetime.fromisoformat(catalog["dateReleased"])
    if released.tzinfo is None:
        raise ValueError("CISA catalog has no timezone")
    age = now - released.timestamp()
    if age > 14 * DAY or age < -DAY:
        raise ValueError("CISA catalog is stale or has a future release date")
    entries = catalog["vulnerabilities"]
    if not isinstance(entries, list) or not entries:
        raise ValueError("CISA catalog is empty or invalid")
    ids = {entry["cveID"] for entry in entries}
    if any(not isinstance(cve, str) or not CVE.fullmatch(cve) for cve in ids):
        raise ValueError("Invalid CVE in CISA catalog")
    return ids


def fetch_kev(state, now):
    with urlopen(KEV_URL, timeout=60) as response:
        data = response.read(16 * 1024 * 1024 + 1)
    if len(data) > 16 * 1024 * 1024:
        raise ValueError("CISA catalog exceeded size limit")
    catalog = json.loads(data)
    ids = kev_ids(catalog, now)
    write_json(state / "kev.json", catalog)
    return ids


def locked_input(lock, name):
    def resolve(reference, seen):
        marker = json.dumps(reference)
        if marker in seen:
            raise ValueError("Cyclic flake input follows")
        seen = seen | {marker}
        if isinstance(reference, str):
            return lock["nodes"][reference]
        if not isinstance(reference, list) or not reference:
            raise ValueError("Invalid flake input reference")
        node = lock["nodes"][lock["root"]]
        for part in reference:
            node = resolve(node["inputs"][part], seen)
        return node

    root = lock["nodes"][lock["root"]]
    return resolve(root["inputs"][name], set())["locked"]


def check_updates(config, state):
    inputs = config["update_inputs"]
    if not inputs:
        return []
    source = Path(config["flake_path"]).expanduser().resolve()
    if source.is_relative_to("/nix/store"):
        raise ValueError("Update checks require a runtime checkout, not /nix/store")
    lock_path = source / "flake.lock"
    before = lock_path.read_bytes()
    old = json.loads(before)
    for name in inputs:
        locked_input(old, name)
    with tempfile.TemporaryDirectory(prefix="update-", dir=state) as temporary:
        candidate = Path(temporary) / "flake.lock"
        result = command(
            [
                config["nix"],
                "--extra-experimental-features",
                "nix-command flakes",
                "--option",
                "accept-flake-config",
                "false",
                "--option",
                "allow-import-from-derivation",
                "false",
                "flake",
                "update",
                "--flake",
                str(source),
                "--output-lock-file",
                str(candidate),
                *inputs,
            ],
            timeout=900,
        )
        (state / "updates.log").write_text(result.stderr[-16384:])
        if lock_path.read_bytes() != before:
            raise ValueError(
                "Checkout lock changed during update check; retry after editing/rebuilding"
            )
        if result.returncode:
            raise ValueError(
                f"Input check failed (exit {result.returncode}); see {state}/updates.log"
            )
        new = read_json(candidate)
        if new is None:
            raise ValueError("Nix did not produce a candidate lock file")
    return [
        {
            "input": name,
            "current": locked_input(old, name),
            "available": locked_input(new, name),
        }
        for name in inputs
        if locked_input(old, name) != locked_input(new, name)
    ]


def collect(config, now=None):
    now = time.time() if now is None else now
    state = Path(config["state_directory"])
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / "collect.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        errors = []
        try:
            previous = read_json(state / "report.json", {})
            if not isinstance(previous, dict):
                raise TypeError("Expected a report object")
        except (OSError, ValueError, TypeError) as error:
            previous = {}
            errors.append(f"Previous report could not be read: {error}")
        report = {
            "generated_at": now,
            "last_success": previous.get("last_success"),
            "findings": previous.get("findings", []),
            "profiles": previous.get("profiles", []),
            "updates": previous.get("updates", []),
            "errors": errors,
        }
        try:
            report["findings"], report["profiles"] = scan(config, state)
            report["last_success"] = now
        except (
            OSError,
            ValueError,
            KeyError,
            TypeError,
            subprocess.SubprocessError,
        ) as error:
            report["errors"].append(f"Advisory scan failed: {error}")
        known = set()
        if config["known_exploited"]:
            try:
                known = fetch_kev(state, now)
            except (OSError, ValueError, KeyError, TypeError) as error:
                report["errors"].append(f"CISA catalog check failed: {error}")
                # A failed refresh must not downgrade previously known exploited CVEs.
                known = {
                    f["cve"]
                    for f in previous.get("findings", [])
                    if f.get("known_exploited")
                }
                try:
                    cached = read_json(state / "kev.json", {})
                    known.update(
                        entry["cveID"] for entry in cached.get("vulnerabilities", [])
                    )
                except (
                    OSError,
                    ValueError,
                    KeyError,
                    TypeError,
                    AttributeError,
                ) as cache_error:
                    report["errors"].append(
                        f"Cached CISA catalog could not be read: {cache_error}"
                    )
        for finding in report["findings"]:
            finding["known_exploited"] = finding["cve"] in known
        try:
            report["updates"] = check_updates(config, state)
        except (
            OSError,
            ValueError,
            KeyError,
            TypeError,
            subprocess.SubprocessError,
        ) as error:
            report["errors"].append(f"Update check failed: {error}")
        write_json(state / "report.json", report)
        high = [finding for finding in report["findings"] if is_high(finding, config)]
        print(
            f"DashNix: {len(report['findings'])} possible package/CVE matches, "
            f"{len(high)} high-risk; {len(report['updates'])} input updates; "
            f"{len(report['errors'])} check errors. Report: {state}/report.json",
            flush=True,
        )
        for error in report["errors"]:
            print(error, flush=True)
        return 1 if report["errors"] else 0


def is_high(finding, config):
    return finding.get("known_exploited", False) or (
        finding["score"] is not None and finding["score"] >= config["cvss_threshold"]
    )


def notification_groups(report, config, now):
    findings = report["findings"]
    high = [finding for finding in findings if is_high(finding, config)]
    other = [finding for finding in findings if not is_high(finding, config)]
    groups = []
    if high:
        groups.append(
            (
                "advisories",
                "critical",
                "High-risk package advisories",
                high,
                [
                    f"{f['package']} {f['version']}: {f['cve']} "
                    f"(CVSS {f['score'] if f['score'] is not None else 'unknown'}"
                    f"{'; known exploited' if f.get('known_exploited') else ''})"
                    for f in high[:5]
                ]
                + [
                    "Possible matches: verify backports and exposure before remediation."
                ],
            )
        )
    if other:
        groups.append(
            (
                "review",
                "normal",
                "Package advisories need review",
                other,
                [
                    f"{len(other)} lower/unknown-severity package/CVE matches. Unknown scores are not safe scores."
                ],
            )
        )
    if report["updates"]:
        groups.append(
            (
                "updates",
                "normal",
                "Tracked flake inputs have updates",
                report["updates"],
                [
                    ", ".join(change["input"] for change in report["updates"]),
                    "Input revisions changed; not proof every installed package has an update. No changes applied.",
                ],
            )
        )
    errors = list(report["errors"])
    last_success = report.get("last_success")
    if last_success is None or now - last_success > 2 * DAY:
        errors.append(
            "No successful advisory scan within 48 hours; retained findings may be stale."
        )
    if now - report["generated_at"] > 2 * DAY:
        errors.append(
            "Security report is older than 48 hours; check the system timer/service."
        )
    if errors:
        groups.append(
            ("errors", "normal", "Security checks need attention", errors, errors[:5])
        )
    return groups


def notify(config, now=None):
    now = time.time() if now is None else now
    report_path = Path(config["state_directory"]) / "report.json"
    try:
        report = read_json(report_path)
        if report is None:
            raise ValueError(
                "No security report yet; check dashnix-security-monitor.service."
            )
        groups = notification_groups(report, config, now)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        report = {
            "generated_at": 0,
            "last_success": None,
            "findings": [],
            "updates": [],
            "errors": [f"Security report unavailable: {error}"],
        }
        groups = notification_groups(report, config, now)
    state = Path(config["notification_state"])
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state / "notify.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            sent = read_json(state / "sent.json", {})
            if not isinstance(sent, dict):
                sent = {}
        except (OSError, ValueError):
            sent = {}
        active = set()
        for name, urgency, title, payload, lines in groups:
            active.add(name)
            fingerprint = hashlib.sha256(
                json.dumps(payload, sort_keys=True).encode()
            ).hexdigest()
            old = sent.get(name, {})
            if old.get("fingerprint") == fingerprint and now - old.get("time", 0) < DAY:
                continue
            body = "\n".join(
                html.escape(str(line)) for line in [*lines, f"Report: {report_path}"]
            )
            result = command(
                [
                    config["notify_send"],
                    "--app-name=DashNix",
                    f"--urgency={urgency}",
                    *(["--expire-time=0"] if urgency == "critical" else []),
                    title,
                    body,
                ],
                timeout=30,
            )
            if result.returncode:
                raise RuntimeError(
                    "Desktop notification failed; report will be retried"
                )
            sent[name] = {"fingerprint": fingerprint, "time": now}
            write_json(state / "sent.json", sent)
        write_json(
            state / "sent.json",
            {key: value for key, value in sent.items() if key in active},
        )
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("collect", "notify"))
    parser.add_argument("--config", required=True)
    args = parser.parse_args()
    os.umask(0o077)
    config = read_json(args.config)
    return collect(config) if args.mode == "collect" else notify(config)


if __name__ == "__main__":
    raise SystemExit(main())
