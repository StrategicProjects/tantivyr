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
