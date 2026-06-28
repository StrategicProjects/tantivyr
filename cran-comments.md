## R CMD check results

0 errors | 0 warnings | 2 notes

* This is a new release.
* Installed size (~10 MB, in `libs`) and source tarball size (~21 MB) come from
  the statically linked Rust search engine ('Tantivy') and its vendored crate
  sources, which are bundled so the package builds offline (see below). The Rust
  object code is compiled with `lto`, `opt-level = 2` and `strip = true` to keep
  the shared library as small as practical.

## SystemRequirements

This package compiles bundled Rust source via Cargo at install time, as declared
in `SystemRequirements: Cargo (Rust's package manager), rustc`. The Rust crate
dependencies are vendored under `src/rust/vendor/` and built offline
(`cargo build --offline`), so no network access is required during installation.

## Test environments

* local macOS (aarch64), R 4.6.0
* GitHub Actions: ubuntu-latest, macOS-latest, windows-latest (release)

## Notes

* Tantivy and all vendored crates are MIT/Apache-2.0 licensed; the package is
  MIT licensed.
