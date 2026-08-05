"""Check active documentation references against the supported DX surface."""

from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
JUSTFILE = PROJECT_ROOT / "Justfile"
RECIPE_PATTERN = re.compile(r"^([A-Za-z0-9_-]+)(?:\s+[^:]*)?:\s*$")
JUST_REFERENCE_PATTERN = re.compile(r"\bjust\s+(?!-)([A-Za-z0-9_-]+)\b")


def supported_recipes() -> set[str]:
    recipes = set()
    for line in JUSTFILE.read_text(encoding="utf-8").splitlines():
        match = RECIPE_PATTERN.match(line)
        if match:
            recipes.add(match.group(1))
    return recipes


def active_documentation() -> list[Path]:
    documents = [PROJECT_ROOT / "README.md", PROJECT_ROOT / "CONTRIBUTING.md"]
    documents.extend(sorted((PROJECT_ROOT / "docs").rglob("*.md")))
    documents.append(PROJECT_ROOT / "kubernetes" / "README.md")
    return [document for document in documents if ".plans" not in document.parts]


def main() -> int:
    recipes = supported_recipes()
    failures: list[str] = []

    for document in active_documentation():
        text = document.read_text(encoding="utf-8")
        unknown = sorted(set(JUST_REFERENCE_PATTERN.findall(text)) - recipes)
        for recipe in unknown:
            failures.append(
                f"{document.relative_to(PROJECT_ROOT)}: unknown Just recipe `{recipe}`"
            )

    for path in sorted((PROJECT_ROOT / "kubernetes").rglob("*")):
        if path.is_file() and "data-zoo" in path.read_text(encoding="utf-8"):
            failures.append(
                f"{path.relative_to(PROJECT_ROOT)}: contains retired `data-zoo` namespace"
            )

    if failures:
        print("Documentation command/reference check failed:", file=sys.stderr)
        print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
        return 1

    print("Documentation command/reference check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
