# Package index

## Create & open indexes

Build an index from a data frame, or from an explicit schema.

- [`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md)
  : Index a data frame in one call
- [`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md)
  : Create or open a search index
- [`tnt_index_info()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_info.md)
  : Index schema as a tibble
- [`tnt_num_docs()`](https://strategicprojects.github.io/tantivyr/reference/tnt_num_docs.md)
  : Number of searchable documents

## Define a schema

Field types and stemming options.

- [`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md)
  : Create a search schema
- [`tnt_text()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_i64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_u64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_f64()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_bool()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_date()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  [`tnt_json()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  : Define schema fields
- [`tnt_stemmers()`](https://strategicprojects.github.io/tantivyr/reference/tnt_stemmers.md)
  : List supported stemmer languages

## Write documents

Add, update, delete and commit.

- [`tnt_add()`](https://strategicprojects.github.io/tantivyr/reference/tnt_add.md)
  : Add documents to an index
- [`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md)
  : Commit pending changes
- [`tnt_update()`](https://strategicprojects.github.io/tantivyr/reference/tnt_update.md)
  : Update documents (delete then re-add)
- [`tnt_delete()`](https://strategicprojects.github.io/tantivyr/reference/tnt_delete.md)
  : Delete documents by field value

## Search

- [`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)
  : Search an index
- [`tnt_count()`](https://strategicprojects.github.io/tantivyr/reference/tnt_count.md)
  : Count matching documents

## Package

- [`tantivyr`](https://strategicprojects.github.io/tantivyr/reference/tantivyr-package.md)
  [`tantivyr-package`](https://strategicprojects.github.io/tantivyr/reference/tantivyr-package.md)
  : tantivyr: Fast Full-Text Search for R with 'Tantivy'
- [`tantivy_version()`](https://strategicprojects.github.io/tantivyr/reference/tantivy_version.md)
  : Tantivy version string.
