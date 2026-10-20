## Resubmission

This is a resubmission (0.1.2 -> 0.1.3): the 0.1.2 submission did not fix the
M1mac additional issue reported for 0.1.1, because it derived the macOS
deployment target from the host's OS version, which does not always match the
version R's final link step targets. In 0.1.3, unless
`MACOSX_DEPLOYMENT_TARGET` is already set in the environment, the Cargo build
pins it to rustc's own default minimum for the platform (11.0 on Apple
silicon), the same minimum the Rust-compiled objects in the static library
already carry. The C sources compiled by Cargo's `cc` crate (zstd) no longer
default to the SDK's version, and every object in the static library is
stamped with a minimum (11.0) that can never be newer than the version the
final link targets, on any macOS/SDK combination. Verified locally (Xcode SDK
27 on macOS 26, where the mismatch reproduced): the previously reported 33
ld warnings ("object file was built for newer 'macOS' version than being
linked") are gone and all objects in `libtantivyr.a` report `minos 11.0`.

This version also (carried over from the 0.1.2 submission):

* updates the bundled 'Tantivy' engine to its 0.27.0 release and refreshes the
  vendored 'Rust' crates. The on-disk index format is unchanged, so indexes
  created with earlier versions keep working;
* removes the code affected by RUSTSEC-2026-0253 (an unsoundness advisory in
  the `lru` crate; the affected function was never reachable from this
  package).

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
