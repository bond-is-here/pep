#!/usr/bin/env python3
"""Write bounded, text-only diagnostics from a finished Pep UI test bundle.

Intended for the isolated, fictional data created by PepUITests. This reads test
outcomes before selecting attachments; XCTest's custom attachment failure flag
does not reliably identify failed cases. Requires Xcode's modern xcresulttool.
"""

from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


class ResultError(Exception):
    pass


class ResultTool:
    def __init__(self, executable: str | None, bundle: Path):
        self.command = [executable] if executable else ["xcrun", "xcresulttool"]
        self.bundle = bundle

    def run(self, *arguments: str) -> str:
        try:
            result = subprocess.run(
                [*self.command, *arguments, "--path", str(self.bundle)],
                check=True, capture_output=True, text=True, timeout=120,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ResultError(str(error)) from error
        except subprocess.CalledProcessError as error:
            message = error.stderr.strip() or error.stdout.strip() or str(error)
            raise ResultError(message[:1500]) from error
        return result.stdout

    def get(self, report: str, *arguments: str) -> dict:
        try:
            return json.loads(self.run("get", "test-results", report, "--compact", *arguments))
        except json.JSONDecodeError as error:
            raise ResultError(f"Invalid {report} JSON from xcresulttool") from error


def inline(value: object) -> str:
    value = html.escape(" ".join(str(value).split()))
    return re.sub(r"([\\`*_\[\]])", r"\\\1", value)


def nodes(items: list[dict]):
    for item in items:
        yield item
        yield from nodes(item.get("children", []))


def failed_cases(report: dict, summary: dict) -> list[dict]:
    cases = []
    for case in nodes(report.get("testNodes", [])):
        if case.get("nodeType") != "Test Case" or case.get("result") != "Failed":
            continue
        identifier = case.get("nodeIdentifier")
        url = case.get("nodeIdentifierURL")
        if not identifier and not url:
            continue
        messages = [
            child["name"] for child in nodes(case.get("children", []))
            if child.get("nodeType") == "Failure Message" and child.get("name")
        ]
        if not messages:
            messages = [
                failure["failureText"] for failure in summary.get("testFailures", [])
                if (failure.get("testIdentifierString") == identifier or failure.get("testIdentifierURL") == url)
                and failure.get("failureText")
            ]
        cases.append({"identifier": identifier, "url": url, "messages": list(dict.fromkeys(messages))})
    return cases


def failing_configurations(details: dict) -> set[tuple[str, str]]:
    pairs = set()
    for device in details.get("testRuns", []):
        if device.get("nodeType") != "Device":
            continue
        for configuration in device.get("children", []):
            if configuration.get("result") == "Failed":
                pairs.add((device.get("nodeIdentifier", ""), configuration.get("name", "")))
    return pairs


def bounded_hierarchy(text: str, max_lines: int, max_chars: int) -> str:
    lines = text.splitlines()
    if len(lines) > max_lines:
        head = max_lines // 2
        tail = max_lines - head
        lines = lines[:head] + [f"… {len(lines) - max_lines} middle lines omitted …"] + lines[-tail:]
    text = "\n".join(lines)
    if len(text) > max_chars:
        half = max_chars // 2
        text = text[:half] + "\n… middle text omitted at character limit …\n" + text[-half:]
    return text


def hierarchy_for_case(tool: ResultTool, case: dict, max_lines: int, max_chars: int) -> str:
    identifier = case["url"] or case["identifier"]
    details = tool.get("test-details", "--test-id", identifier)
    configurations = failing_configurations(details)
    if not configurations:
        return "Failure hierarchy unavailable: no failing device/configuration could be matched.\n"
    with tempfile.TemporaryDirectory(prefix="pep-ui-summary-") as temporary:
        output = Path(temporary)
        # Do not use --only-failures: custom teardown attachments can have that
        # flag unset. Export only this failed case, then map the manifest below.
        tool.run("export", "attachments", "--test-id", identifier, "--output-path", str(output))
        try:
            manifest = json.loads((output / "manifest.json").read_text())
        except (OSError, json.JSONDecodeError) as error:
            raise ResultError("Attachment manifest is unavailable or invalid") from error
        candidates = []
        for entry in manifest:
            if entry.get("testIdentifier") != case["identifier"] and entry.get("testIdentifierURL") != case["url"]:
                continue
            for attachment in entry.get("attachments", []):
                if not attachment.get("suggestedHumanReadableName", "").startswith("Native accessibility hierarchy"):
                    continue
                pair = (attachment.get("deviceId", ""), attachment.get("configurationName", ""))
                filename = attachment.get("exportedFileName", "")
                if pair in configurations and Path(filename).name == filename and Path(filename).suffix == ".txt":
                    candidates.append(attachment)
        if not candidates:
            return "No Native accessibility hierarchy attachment was captured for this failing test configuration.\n"
        latest = max(candidates, key=lambda attachment: attachment.get("timestamp", 0))
        # Binary media is never read or printed. Keep an explicit read ceiling
        # even though our own accessibility attachments are normally much smaller.
        with (output / latest["exportedFileName"]).open("rb") as source:
            raw = source.read(262145)
        if b"\x00" in raw:
            return "Failure hierarchy omitted: attachment was not plain text.\n"
        text = raw[:262144].decode("utf-8", errors="replace")
        if len(raw) > 262144:
            text += "\n… attachment read capped at 256 KiB …"
        text = bounded_hierarchy(text, max_lines, max_chars)
        longest_fence = max((len(match.group()) for match in re.finditer(r"`+", text)), default=0)
        fence = "`" * max(3, longest_fence + 1)
        label = html.escape(f"Native accessibility hierarchy — {latest.get('deviceName', 'unknown device')} (bounded)")
        return f"<details>\n<summary>{label}</summary>\n\n{fence}text\n{text}\n{fence}\n\n</details>\n"


def summarize(tool: ResultTool, max_failures: int, max_lines: int, max_chars: int) -> str:
    summary = tool.get("summary")
    if not summary.get("finishTime"):
        raise ResultError("This result bundle has no finish time; wait for the test run to finish")
    report = tool.get("tests")
    failures = failed_cases(report, summary)
    lines = [
        "### Native iOS UI results", "",
        f"**{inline(summary.get('result', 'Unknown'))}** — "
        f"{summary.get('passedTests', 'unknown')} passed, {summary.get('failedTests', 'unknown')} failed, "
        f"{summary.get('skippedTests', 'unknown')} skipped; {summary.get('totalTestCount', 'unknown')} tests total.",
    ]
    if summary.get("expectedFailures"):
        lines.append(f"Expected failures: {summary['expectedFailures']}.")
    devices = []
    for entry in summary.get("devicesAndConfigurations", []):
        device = entry.get("device", {})
        description = " · ".join(str(device[key]) for key in ("deviceName", "platform", "osVersion", "architecture") if device.get(key))
        if description and description not in devices:
            devices.append(description)
    if devices:
        lines.extend(["", f"Device: {inline('; '.join(devices))}."])
    if not failures:
        lines.extend(["", "No failed test cases were reported; passing-case attachments are omitted."])
        if summary.get("failedTests", 0):
            lines.append("The summary reports failures without identifiable failed test cases; consult the full result bundle.")
        return "\n".join(lines) + "\n"
    lines.extend(["", "Only failed test cases and their latest matching text hierarchy are included. Test data is generated by Pep's isolated UI test launch."])
    for case in failures[:max_failures]:
        lines.extend(["", f"**{inline(case['identifier'] or case['url'])}**", ""])
        for message in case["messages"][:5]:
            lines.append(f"- {inline(message[:3000])}")
        if not case["messages"]:
            lines.append("- No failure message was recorded.")
        if len(case["messages"]) > 5:
            lines.append(f"- {len(case['messages']) - 5} additional messages omitted.")
        lines.append("")
        try:
            lines.append(hierarchy_for_case(tool, case, max_lines, max_chars))
        except (OSError, ResultError) as error:
            lines.append(f"Failure hierarchy unavailable: {inline(error)}.\n")
    if len(failures) > max_failures:
        lines.extend(["", f"{len(failures) - max_failures} additional failed cases omitted at the configured limit."])
    return "\n".join(lines) + "\n"


def bounded_integer(minimum: int, maximum: int):
    def parse(value: str) -> int:
        number = int(value)
        if not minimum <= number <= maximum:
            raise argparse.ArgumentTypeError(f"must be between {minimum} and {maximum}")
        return number
    return parse


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path, help="Finished .xcresult bundle from Pep's isolated native UI tests")
    parser.add_argument("--xcresulttool", help="Explicit executable path; defaults to xcrun xcresulttool")
    parser.add_argument("--max-failures", type=bounded_integer(1, 20), default=5)
    parser.add_argument("--max-hierarchy-lines", type=bounded_integer(20, 500), default=200)
    parser.add_argument("--max-hierarchy-chars", type=bounded_integer(2000, 50000), default=20000)
    args = parser.parse_args()
    try:
        if not args.bundle.is_dir():
            raise ResultError("The finished .xcresult bundle does not exist")
        print(summarize(ResultTool(args.xcresulttool, args.bundle), args.max_failures, args.max_hierarchy_lines, args.max_hierarchy_chars), end="")
        return 0
    except (ResultError, OSError) as error:
        print(f"### Native iOS UI results\n\nSummary unavailable: {inline(error)}.")
        print(f"Native UI summary unavailable: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
