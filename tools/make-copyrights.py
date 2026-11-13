#!/usr/bin/env python3
"""Generate inst/AUTHORS and inst/COPYRIGHTS from the vendored Rust crates.

Run from the package root after refreshing src/rust/vendor.tar.xz:

    python3 tools/make-copyrights.py

The script only reads: it takes each crate's name, version, license
expression and authors from its Cargo.toml (in src/rust/vendor/ when that
directory exists, otherwise straight from src/rust/vendor.tar.xz), and copies
the notices of the primary upstream and of every crate that is not available
under the MIT license verbatim from the license files shipped with the crate.
"""
import hashlib
import os
import re
import sys
import tarfile
import tomllib

# --------------------------------------------------------------------------
# Package-specific configuration
# --------------------------------------------------------------------------
PACKAGE = "tantivyr"
PACKAGE_LICENSE = "MIT"

# Crates written by the package authors themselves (no third-party credit).
OWN_CRATES = {}

# Text placed before the crate table in inst/AUTHORS.
AUTHORS_INTRO = """\
The tantivyr R package (the R interface in R/ and the Rust bridge in
src/rust/src/) was written by the package authors listed in DESCRIPTION with
role "aut". It is distributed under the MIT license (see LICENSE).

The search engine itself is third-party work. tantivyr wraps and statically
links Tantivy (https://github.com/quickwit-oss/tantivy), a full-text search
engine library written in Rust by Paul Masurel and the Tantivy contributors and
maintained at Quickwit. Tantivy's LICENSE (MIT) attributes its copyright to
"the project authors, as listed in the AUTHORS file", which reads:

{primary_authors}

tantivyr is an independent R binding. It is not affiliated with, sponsored by
or endorsed by the Tantivy project or by Quickwit, Inc.

Tantivy and the crates it depends on are vendored in
src/rust/vendor.tar.xz so that the package builds offline. Each crate is the
copyright of its respective authors and is used under the terms of its
license, as listed below. The copyright holders are recorded collectively in
DESCRIPTION (role "cph").
"""

# Primary upstream: crate whose notices open inst/COPYRIGHTS.
PRIMARY = {
    "crate": "tantivy",
    "title": "Tantivy",
    "url": "https://github.com/quickwit-oss/tantivy",
    "files": ["LICENSE", "AUTHORS"],
    "also": ["tantivy-bitpacker", "tantivy-columnar", "tantivy-common",
             "tantivy-fst", "tantivy-query-grammar", "tantivy-sstable",
             "tantivy-stacker", "tantivy-tokenizer-api", "ownedbytes"],
}

# Files below the crate root that carry notices of code bundled inside a
# crate (crate directory name -> list of (path, description)).
NESTED_NOTICES = {
    "zstd-sys": [("zstd/LICENSE",
                  "Zstandard C library bundled in zstd-sys (dual BSD-3-Clause "
                  "OR GPL-2.0-only; used here under BSD-3-Clause)")],
}

# Remarks appended to a crate's entry in the "other licenses" section.
REMARKS = {}

# Holders for crates whose Cargo.toml has no `authors` and whose license
# files carry no usable copyright line.
HOLDER_FALLBACK = "The {name} contributors"

# Holders fixed by hand (crate name -> list), for crates that declare no
# `authors` and belong to a project whose license names its holders elsewhere.
HOLDER_OVERRIDES = {
    "tantivy": ["Paul Masurel and the Tantivy authors (see tantivy/AUTHORS in inst/COPYRIGHTS)"],
    "tantivy-columnar": ["The Tantivy authors"],
    "tantivy-sstable": ["The Tantivy authors"],
    "tantivy-stacker": ["The Tantivy authors"],
    "tantivy-tokenizer-api": ["The Tantivy authors"],
    "extendr-api": ["The extendr authors"],
    "extendr-ffi": ["The extendr authors"],
    "extendr-macros": ["The extendr authors"],
}

# --------------------------------------------------------------------------

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
VENDOR_DIR = os.path.join(ROOT, "src", "rust", "vendor")
VENDOR_TAR = os.path.join(ROOT, "src", "rust", "vendor.tar.xz")
OUT_AUTHORS = os.path.join(ROOT, "inst", "AUTHORS")
OUT_COPYRIGHTS = os.path.join(ROOT, "inst", "COPYRIGHTS")

NOTICE_RE = re.compile(
    r"^(Cargo\.toml|LICEN[CS]E[^/]*|COPYING[^/]*|COPYRIGHT[^/]*|NOTICE[^/]*|"
    r"UNLICENSE[^/]*|AUTHORS[^/]*)$", re.I)


def wanted(crate, rel):
    if "/" not in rel:
        return bool(NOTICE_RE.match(rel))
    return any(rel == p for p, _ in NESTED_NOTICES.get(crate, []))


def read_vendor():
    """Return {crate_dir: {relative_path: text}} for the notice files."""
    crates = {}
    if os.path.isdir(VENDOR_DIR):
        for crate in sorted(os.listdir(VENDOR_DIR)):
            base = os.path.join(VENDOR_DIR, crate)
            if not os.path.isdir(base):
                continue
            rels = [f for f in os.listdir(base) if wanted(crate, f)]
            rels += [p for p, _ in NESTED_NOTICES.get(crate, [])]
            for rel in rels:
                path = os.path.join(base, rel)
                if os.path.isfile(path):
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        crates.setdefault(crate, {})[rel] = fh.read()
        return crates
    if not os.path.exists(VENDOR_TAR):
        sys.exit("neither src/rust/vendor/ nor src/rust/vendor.tar.xz found")
    with tarfile.open(VENDOR_TAR, "r:xz") as tar:
        for member in tar:
            parts = member.name.lstrip("./").split("/", 2)
            if len(parts) < 3 or parts[0] != "vendor":
                continue
            crate, rel = parts[1], parts[2]
            if not wanted(crate, rel):
                continue
            if member.issym():
                # e.g. LICENSE -> ../LICENSE in a workspace member
                continue
            if not member.isfile():
                continue
            text = tar.extractfile(member).read().decode("utf-8", "replace")
            crates.setdefault(crate, {})[rel] = text
    return crates


def clean_author(a):
    a = re.sub(r"\s*<[^>]*>", "", a)
    return re.sub(r"\s*\S+@\S+", "", a).strip()  # bare e-mail: not a name


def copyright_lines(text):
    """Copyright holders named in a license file (boilerplate skipped)."""
    out = []
    for line in text.splitlines():
        m = re.match(r"^\s*Copyright\s+((?:\([cC]\)|©)\s*)?(.+?)\s*$", line)
        if not m:
            continue
        marker, rest = m.group(1), m.group(2)
        if not marker and not re.match(r"[\[\d]", rest):
            continue  # prose such as "Copyright license." or "Copyright and ..."
        if re.search(r"yyyy|name of copyright owner|<year>", rest, re.I):
            continue
        rest = re.sub(r"^[\[\]\d\s,\-–]+(?:present)?[\s,]*", "", rest)
        rest = re.sub(r"^by\s+", "", rest)
        rest = re.sub(r"\s*<[^>]*>", "", rest)
        rest = re.sub(r"\s*All rights reserved\.?$", "", rest, flags=re.I)
        rest = rest.replace("[", "").replace("]", "").strip(" ,")
        if rest.endswith(".") and not rest.endswith(("Inc.", "Ltd.")):
            rest = rest[:-1]
        if rest and rest not in out:
            out.append(rest)
    return out


def mit_available(expr):
    """True when the SPDX expression lets the crate be used under MIT alone."""
    if " AND " in expr:
        return False
    alts = re.split(r"\s+OR\s+|\s*/\s*", expr.strip("()"))
    return "MIT" in [a.strip() for a in alts]


def is_apache_text(text):
    return "Apache License" in text[:200] and "TERMS AND CONDITIONS" in text


def is_mit_text(text):
    return "Permission is hereby granted, free of charge" in text and \
        "sublicense, and/or sell" in " ".join(text.split())


def is_mpl_text(text):
    return text.lstrip().startswith("Mozilla Public License Version 2.0")


def indent(text):
    return "".join(("    " + ln).rstrip() + "\n" for ln in text.rstrip("\n").splitlines())


def rule(title, ch="-"):
    return f"{title}\n{ch * len(title)}\n"


def main():
    vendor = read_vendor()
    rows = []
    for crate, files in sorted(vendor.items(), key=lambda kv: kv[0].lower()):
        if "Cargo.toml" not in files:
            continue
        pkg = tomllib.loads(files["Cargo.toml"])["package"]
        name, version = pkg["name"], pkg["version"]
        lic = pkg.get("license") or f"see {pkg.get('license-file', 'crate')}"
        holders = [clean_author(a) for a in pkg.get("authors", []) if clean_author(a)]
        if name in OWN_CRATES:
            holders = [OWN_CRATES[name]]
        if name in HOLDER_OVERRIDES:
            holders = list(HOLDER_OVERRIDES[name])
        if holders and (not mit_available(lic) or crate in NESTED_NOTICES):
            # part of the crate is under another license: add those holders
            for rel in sorted(files):
                if rel != "Cargo.toml" and not is_mit_text(files[rel]) \
                        and not is_apache_text(files[rel]):
                    for h in copyright_lines(files[rel]):
                        if h not in holders:
                            holders.append(h)
        if not holders:
            for rel in sorted(files):
                if rel != "Cargo.toml" and "/" not in rel:
                    for h in copyright_lines(files[rel]):
                        if h not in holders:
                            holders.append(h)
        if not holders:
            holders = [HOLDER_FALLBACK.format(name=name)]
        rows.append({"dir": crate, "name": name, "version": version,
                     "license": lic, "holders": holders, "files": files,
                     "repo": pkg.get("repository") or pkg.get("homepage") or ""})

    by_dir = {r["dir"]: r for r in rows}
    primary = by_dir[PRIMARY["crate"]]

    # ---------------------------------------------------------------- AUTHORS
    w = [max(len(r[k]) for r in rows) for k in ("name", "version", "license")]
    w = [max(a, b) + 2 for a, b in zip(w, (5, 7, 7))]
    title = f"Authorship and copyright of the code bundled in {PACKAGE}"
    out = [rule(title, "="), "\n"]
    primary_authors = indent(primary["files"].get("AUTHORS", "")) \
        if "AUTHORS" in PRIMARY["files"] else ""
    out.append(AUTHORS_INTRO.format(primary_authors=primary_authors.rstrip("\n")))
    out.append("\n")
    out.append(f"{'crate':<{w[0]}}{'version':<{w[1]}}{'license':<{w[2]}}copyright holder(s)\n")
    out.append(f"{'-----':<{w[0]}}{'-------':<{w[1]}}{'-------':<{w[2]}}-------------------\n")
    for r in rows:
        out.append(f"{r['name']:<{w[0]}}{r['version']:<{w[1]}}{r['license']:<{w[2]}}"
                   f"{', '.join(r['holders'])}\n")
    out.append(f"""
{len(rows)} crates. Name, version and license are those declared in each crate's
Cargo.toml; the holders are the crate's declared `authors` or, when it declares
none, the names in the copyright lines of its license files ("The <crate>
contributors" when neither exists).

Crates offered under several licenses ("MIT OR Apache-2.0" and similar) are
used here under the MIT license, which is the license of {PACKAGE} itself.
The crates that are not available under MIT, with their notices and license
texts, are listed in inst/COPYRIGHTS.

The full license files of every crate are distributed, unmodified, with the
crate's source inside src/rust/vendor.tar.xz.
""")
    os.makedirs(os.path.dirname(OUT_AUTHORS), exist_ok=True)
    with open(OUT_AUTHORS, "w", encoding="utf-8") as fh:
        fh.write("".join(out))

    # ------------------------------------------------------------- COPYRIGHTS
    title = f"Copyright and license notices for the code bundled in {PACKAGE}"
    out = [rule(title, "="), f"""
The {PACKAGE} R package is distributed under the {PACKAGE_LICENSE} license (see the package
LICENSE file). Its source package bundles, in src/rust/vendor.tar.xz, the
source code of the Rust crates listed in inst/AUTHORS (crate, version,
license and copyright holders), and its compiled library statically links
them. This file reproduces the notices that those licenses require to
accompany redistributions.

"""]
    out.append(rule(f"1. {PRIMARY['title']}"))
    out.append(f"""
{PRIMARY['title']} {primary['version']}
  {PRIMARY['url']}
  License: {primary['license']}
""")
    if PRIMARY.get("also"):
        also = [f"{by_dir[c]['name']} {by_dir[c]['version']}"
                for c in PRIMARY["also"] if c in by_dir]
        if also:
            out.append("  Same project, same notice: " + ", ".join(also) + "\n")
    if PRIMARY.get("note"):
        out.append("\n" + PRIMARY["note"])
    shared = {}       # label -> (source, text), printed in section 4
    for rel in sorted(primary["files"]):
        if is_mpl_text(primary["files"][rel]):
            shared["Mozilla Public License, Version 2.0"] = (
                f"{PRIMARY['crate']}/{rel}", primary["files"][rel])
    for rel in PRIMARY["files"]:
        if rel in primary["files"]:
            out.append(f"\n  --- {PRIMARY['crate']}/{rel} (verbatim) ---\n\n")
            out.append(indent(primary["files"][rel]))
    out.append("\n")

    out.append(rule("2. Crates used under the MIT license"))
    n_mit = sum(1 for r in rows if mit_available(r["license"]))
    out.append(f"""
{n_mit} of the {len(rows)} vendored crates are licensed under MIT, alone or as one of
several alternatives; they are used under MIT. Their copyright holders are
listed in inst/AUTHORS and each crate's own copyright notice travels with its
source in src/rust/vendor.tar.xz. The permission notice common to all of them
is:

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to permit
    persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
    NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
    OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
    USE OR OTHER DEALINGS IN THE SOFTWARE.

""")

    out.append(rule("3. Crates under other licenses"))
    out.append("""
The crates below are not available under MIT alone. Their notices are
reproduced verbatim from the files shipped with each crate; a text that
several crates share is printed once.

""")
    printed = {}      # sha1 -> "crate/file" where the text was first printed
    for r in rows:
        if mit_available(r["license"]) or r["dir"] == PRIMARY["crate"]:
            continue
        out.append(f"{r['name']} {r['version']}\n")
        if r["repo"]:
            out.append(f"  {r['repo']}\n")
        out.append(f"  License: {r['license']}\n")
        out.append(f"  Copyright holder(s): {', '.join(r['holders'])}\n")
        if r["dir"] in REMARKS:
            out.append("".join("  " + ln + "\n" for ln in REMARKS[r["dir"]].splitlines()))
        nested = dict(NESTED_NOTICES.get(r["dir"], []))
        for rel in sorted(r["files"]):
            if rel == "Cargo.toml":
                continue
            text = r["files"][rel]
            where = f"{r['dir']}/{rel}"
            if re.fullmatch(r"\.\./\S+\s*", text):
                # cargo vendor keeps a workspace symlink as a one-line file
                out.append(f"  {where}: link to the {text.strip()} of the crate's "
                           f"workspace ({r['license']}; text in section 4)\n")
                continue
            if is_apache_text(text):
                first = shared.setdefault("Apache License, Version 2.0", (where, text))
                cl = copyright_lines(text)
                extra = f"; its appendix names: {', '.join(cl)}" if cl else ""
                same = "" if first[1] == text else " (the crate's own copy is in the tarball)"
                out.append(f"  {where}: Apache License 2.0, text in section 4{same}{extra}\n")
                continue
            if is_mpl_text(text):
                shared.setdefault("Mozilla Public License, Version 2.0", (where, text))
                out.append(f"  {where}: Mozilla Public License 2.0, text in section 4\n")
                continue
            if is_mit_text(text) and " AND " in r["license"]:
                out.append(f"  {where}: MIT license (see section 2)\n")
                continue
            key = hashlib.sha1(text.encode("utf-8")).hexdigest()
            if key in printed:
                out.append(f"  {where}: identical to {printed[key]}, above\n")
                continue
            printed[key] = where
            desc = f" - {nested[rel]}" if rel in nested else ""
            out.append(f"\n  --- {where} (verbatim){desc} ---\n\n")
            out.append(indent(text))
        out.append("\n")

    out.append(rule("4. Full texts of the shared licenses"))
    for label, (where, text) in shared.items():
        out.append(f"\n--- {label} (verbatim from {where}) ---\n\n")
        out.append(text.rstrip("\n") + "\n")
    out.append("""
Other license texts: every crate ships its license files next to its source
inside src/rust/vendor.tar.xz; the standard texts are also available at
https://spdx.org/licenses/ under each SPDX identifier used in inst/AUTHORS.
""")
    with open(OUT_COPYRIGHTS, "w", encoding="utf-8") as fh:
        fh.write("".join(out))
    print(f"wrote inst/AUTHORS and inst/COPYRIGHTS ({len(rows)} crates)")


if __name__ == "__main__":
    main()
