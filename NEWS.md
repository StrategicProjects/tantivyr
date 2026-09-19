# tantivyr 0.1.1

* New `fold_accents` argument in `tnt_text()` and `tnt_index_df()`: removes
  diacritics from indexed words and queries (ASCII folding), so a query typed
  without accents, such as `"orcamento"`, finds `"orçamento"`. Stored text and
  snippets keep their accents.
* New `pt_news` dataset: 36 short, fictional news stories in Brazilian
  Portuguese for trying out stemming, stop words, filters and highlights.
* New vignette "Searching Portuguese text" covering stemming, stop words,
  accents and the query syntax.
* Updated the bundled 'Tantivy' engine to 0.26.2 (bug-fix release; no API
  changes) and refreshed the vendored 'Rust' crates.
* `SystemRequirements` now states the minimum supported 'Rust' version
  (`rustc >= 1.88`), so an outdated toolchain is reported clearly at configure
  time instead of failing during compilation.
* Corrected the example return value in the `tantivy_version()` documentation.

# tantivyr 0.1.0

* Initial release.
* `tnt_index_df()` indexes a data frame in one call (auto-schema).
* Explicit schema API: `tnt_schema()` with `tnt_text()`, `tnt_i64()`,
  `tnt_u64()`, `tnt_f64()`, `tnt_bool()`, `tnt_date()` and `tnt_json()`.
* `tnt_index()` creates or opens on-disk and in-memory indexes.
* `tnt_add()`, `tnt_commit()`, `tnt_delete()` and `tnt_update()` provide
  incremental updates.
* `tnt_search()` returns a tibble with BM25 scores, structured filters
  (comparison expressions or Tantivy query strings), snippet highlighting and
  fast-field ordering; `tnt_count()` returns total match counts.
* Portuguese and English stemming and stop words, plus other Snowball languages.
