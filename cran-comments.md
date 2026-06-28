## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

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
