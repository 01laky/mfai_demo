#!/usr/bin/env python3
"""Validate ```mermaid fenced blocks in Markdown using @mermaid-js/mermaid-cli (mmdc).

Scans *.md under the repo root with the same directory exclusions as format-all-doc.sh.
Skips files that contain illustrative / non-renderable examples (see SKIP_FILES).

Env:
  MERMAID_CLI_VERSION — pinned npm dist-tag for @mermaid-js/mermaid-cli (default: 11.4.1).
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

SKIP_DIR_NAMES = frozenset(
    {
        ".git",
        "node_modules",
        ".yarn",
        ".venv",
        ".venv-ci-verify",
        "venv",
        "site-packages",
        "dist",
        "build",
        "coverage",
        ".turbo",
        ".pytest_cache",
    }
)

# Illustrative fenced mermaid in agent prompts is not valid diagram source.
SKIP_FILES = frozenset(
    {
        "docs/prompts/mermaid-documentation-diagrams-agent-prompt.md",
    }
)

DEFAULT_MERMAID_CLI_VERSION = "11.4.1"


def should_skip_path(path: Path, root: Path) -> bool:
    try:
        rel = path.relative_to(root)
    except ValueError:
        return True
    rel_posix = rel.as_posix()
    if rel_posix in SKIP_FILES:
        return True
    return any(part in SKIP_DIR_NAMES for part in rel.parts)


def iter_markdown_files(root: Path) -> list[Path]:
    out: list[Path] = []
    for pattern in ("*.md", "*.mdx"):
        for path in root.rglob(pattern):
            if path.is_file() and not should_skip_path(path, root):
                out.append(path)
    out.sort(key=lambda p: p.as_posix().lower())
    return out


def iter_mermaid_blocks(
    text: str,
) -> list[tuple[int, str]]:
    """Return (1-based start line of opening fence, inner content) for each block."""
    lines = text.splitlines()
    blocks: list[tuple[int, str]] = []
    i = 0
    n = len(lines)
    while i < n:
        stripped = lines[i].strip()
        if stripped == "```mermaid" or stripped.startswith("```mermaid "):
            start_line = i + 1
            i += 1
            buf: list[str] = []
            while i < n:
                if lines[i].strip() == "```":
                    content = "\n".join(buf).strip("\n")
                    if content.strip():
                        blocks.append((start_line, content))
                    i += 1
                    break
                buf.append(lines[i])
                i += 1
            else:
                raise ValueError(f"Unclosed ```mermaid fence starting at line {start_line}")
        else:
            i += 1
    return blocks


def run_mmdc(content: str, mmdc_version: str) -> tuple[int, str]:
    with tempfile.TemporaryDirectory(prefix="mermaid-doc-check-") as td:
        inp = Path(td) / "diagram.mmd"
        out = Path(td) / "diagram.svg"
        inp.write_text(content + "\n", encoding="utf-8")
        cmd = [
            "npx",
            "--yes",
            f"@mermaid-js/mermaid-cli@{mmdc_version}",
            "mmdc",
            "-i",
            str(inp),
            "-o",
            str(out),
            "-b",
            "transparent",
        ]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=td,
            timeout=120,
        )
        err = (proc.stderr or "") + (proc.stdout or "")
        return proc.returncode, err.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="Repository root (default: parent of scripts/)",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    ver = os.environ.get("MERMAID_CLI_VERSION", DEFAULT_MERMAID_CLI_VERSION)

    md_files = iter_markdown_files(root)
    failures: list[str] = []
    total_blocks = 0

    for md_path in md_files:
        rel = md_path.relative_to(root).as_posix()
        try:
            text = md_path.read_text(encoding="utf-8")
        except OSError as e:
            failures.append(f"{rel}: read error: {e}")
            continue
        try:
            blocks = iter_mermaid_blocks(text)
        except ValueError as e:
            failures.append(f"{rel}: {e}")
            continue
        for start_line, content in blocks:
            total_blocks += 1
            code, err = run_mmdc(content, ver)
            if code != 0:
                msg = f"{rel}:{start_line}: mmdc failed (exit {code})"
                if err:
                    msg += f"\n{err}"
                failures.append(msg)
            elif args.verbose:
                print(f"OK {rel}:{start_line} ({len(content)} chars)")

    print(
        f"Mermaid doc check: {len(md_files)} markdown files, {total_blocks} ```mermaid blocks, "
        f"mermaid-cli@{ver}"
    )
    if failures:
        print("\n--- failures ---\n", file=sys.stderr)
        for f in failures:
            print(f, file=sys.stderr)
            print(file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
