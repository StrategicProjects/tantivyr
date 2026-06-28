# Changelog

## tantivyr 0.1.0

- Initial release.
- [`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md)
  indexes a data frame in one call (auto-schema).
- Explicit schema API:
  [`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md)
  with
  [`tnt_text()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
  [`tnt_i64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
  [`tnt_u64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
  [`tnt_f64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
  [`tnt_bool()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
  [`tnt_date()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  and
  [`tnt_json()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md).
- [`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md)
  creates or opens on-disk and in-memory indexes.
- [`tnt_add()`](https://strategicprojects.github.io/tantivyr/reference/tnt_add.md),
  [`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md),
  [`tnt_delete()`](https://strategicprojects.github.io/tantivyr/reference/tnt_delete.md)
  and
  [`tnt_update()`](https://strategicprojects.github.io/tantivyr/reference/tnt_update.md)
  provide incremental updates.
- [`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)
  returns a tibble with BM25 scores, structured filters (comparison
  expressions or Tantivy query strings), snippet highlighting and
  fast-field ordering;
  [`tnt_count()`](https://strategicprojects.github.io/tantivyr/reference/tnt_count.md)
  returns total match counts.
- Portuguese and English stemming and stop words, plus other Snowball
  languages.
