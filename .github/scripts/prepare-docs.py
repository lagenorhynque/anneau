#!/usr/bin/env python3
"""Assemble the site published to GitHub Pages from the output of `flix doc`.

`flix doc` documents the standard library alongside the project, so its index is
the whole Flix prelude with Anneau as one entry among hundreds of pages. That
index is served under `api/` and the reader lands on a redirect instead, which
leaves the "back to Prelude" link on every generated page working; rewriting the
index in place would have broken all of them.

Every `Source` link on a page generated for a project other than Flix itself is
the Flix repository URL with the *absolute path* of the source file appended, so
it points nowhere and carries the path of the machine that ran `flix doc`. Those
links are repointed at this repository, at the commit they were generated from.
Links into the standard library are already correct and are left alone.

Run from the root of the repository; every default path is relative to it. Running
it by hand is the way to inspect the site before it is published:

    .github/scripts/prepare-docs.py \\
        --workspace "$PWD" --repository lagenorhynque/anneau --sha "$(git rev-parse HEAD)"
"""

import argparse
import pathlib
import shutil
import sys

# What `flix doc` prefixes a source path with, whatever project it is documenting.
FLIX_LIBRARY_URL = "https://github.com/flix/flix/blob/master/main/src/library/"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--doc-dir",
        type=pathlib.Path,
        default=pathlib.Path("build/doc"),
        help="where `flix doc` wrote its output (default: %(default)s)",
    )
    parser.add_argument(
        "--out",
        type=pathlib.Path,
        default=pathlib.Path("_site"),
        help="directory to assemble the site in, replaced if it exists "
        "(default: %(default)s)",
    )
    parser.add_argument(
        "--index",
        type=pathlib.Path,
        default=pathlib.Path(".github/pages/index.html"),
        help="landing page to copy to the root of the site (default: %(default)s)",
    )
    parser.add_argument(
        "--workspace",
        required=True,
        help="absolute path the documentation was generated from, which is what "
        "the broken Source links carry",
    )
    parser.add_argument(
        "--repository",
        required=True,
        help="owner/name to repoint the Source links at",
    )
    parser.add_argument(
        "--sha",
        required=True,
        help="commit the documentation was generated from",
    )
    return parser.parse_args(argv)


def assemble(doc_dir: pathlib.Path, out: pathlib.Path, index: pathlib.Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(doc_dir, out / "api")
    shutil.copy(index, out / "index.html")


def repoint_source_links(
    out: pathlib.Path, workspace: str, repository: str, sha: str
) -> int:
    old = f"{FLIX_LIBRARY_URL}{workspace.rstrip('/')}/"
    new = f"https://github.com/{repository}/blob/{sha}/"

    rewritten = 0
    for path in out.rglob("*.html"):
        text = path.read_text()
        if old in text:
            path.write_text(text.replace(old, new))
            rewritten += 1
    return rewritten


def find_leaked_paths(out: pathlib.Path, workspace: str) -> list[pathlib.Path]:
    return [p for p in out.rglob("*.html") if workspace.rstrip("/") in p.read_text()]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not args.doc_dir.is_dir():
        print(f"{args.doc_dir} does not exist; run `flix doc` first", file=sys.stderr)
        return 1

    assemble(args.doc_dir, args.out, args.index)
    pages = len(list((args.out / "api").glob("*.html")))
    rewritten = repoint_source_links(args.out, args.workspace, args.repository, args.sha)
    print(f"assembled {pages} pages into {args.out}")
    print(f"repointed the Source links in {rewritten} file(s)")

    # A build path left in the output would be published, so fail rather than
    # deploy one.
    leaked = find_leaked_paths(args.out, args.workspace)
    if leaked:
        print(f"build path still present in: {[str(p) for p in leaked]}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
