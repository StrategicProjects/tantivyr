## Update

This is a minor update (0.1.0 -> 0.1.1). It:

* adds a small example dataset (`pt_news`) and a second vignette;
* updates the bundled 'Tantivy' engine to its 0.26.2 bug-fix release and
  refreshes the vendored 'Rust' crates;
* declares the minimum supported 'Rust' version in `SystemRequirements`
  (`rustc >= 1.88`), which `configure` checks before compiling.

## R CMD check results

0 errors | 0 warnings | 1 note

* Installed size (~10 MB, in `libs`) and source tarball size (~21 MB) come from
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
* The `pt_news` dataset was written for this package and contains UTF-8
  (Portuguese) strings by design.
