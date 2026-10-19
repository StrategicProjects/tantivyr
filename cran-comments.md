## Update

This is a minor update (0.1.1 -> 0.1.2). It:

* updates the bundled 'Tantivy' engine to its 0.27.0 release and refreshes the
  vendored 'Rust' crates. The on-disk index format is unchanged, so indexes
  created with earlier versions keep working;
* the refreshed crates also remove the code affected by RUSTSEC-2026-0253
  (an unsoundness advisory in the `lru` crate; the affected function was never
  reachable from this package).

## R CMD check results

0 errors | 0 warnings | 1 note

* Installed size (~10 MB, in `libs`) and source tarball size (~20 MB) come from
  the statically linked Rust search engine ('Tantivy') and its vendored crate
  sources, which are bundled so the package builds offline (see below). The Rust
  object code is compiled with `lto`, `opt-level = 2` and `strip = true` to keep
  the shared library as small as practical.

## SystemRequirements

This package compiles bundled Rust source via Cargo at install time, as declared
in `SystemRequirements: Cargo (Rust's package manager), rustc (>= 1.88)`. The
Rust crate dependencies are vendored in `src/rust/vendor.tar.xz` and built
offline, so no network access is required during installation.

## Test environments

* local macOS (aarch64), R 4.6.0
* GitHub Actions: ubuntu-latest (devel, release, oldrel-1), macOS-latest and
  windows-latest (release)

## Reverse dependencies

There are currently no reverse dependencies.

## Notes

* Tantivy and all vendored crates are MIT/Apache-2.0 licensed; the package is
  MIT licensed.
