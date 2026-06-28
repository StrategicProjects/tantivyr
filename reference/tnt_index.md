# Create or open a search index

Opens an existing on-disk index, or creates a new one from a
[`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md).
With `path = NULL` an in-memory index is created (useful for tests and
transient work).

## Usage

``` r
tnt_index(path = NULL, schema = NULL, overwrite = FALSE, heap_mb = 128)
```

## Arguments

- path:

  Directory for an on-disk index, or `NULL` for an in-memory index. If
  the directory already contains an index it is opened (unless
  `overwrite = TRUE`).

- schema:

  A
  [`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md).
  Required when creating a new index; ignored when opening an existing
  one.

- overwrite:

  Logical. If `TRUE`, an existing index at `path` is deleted and
  recreated from `schema`. Defaults to `FALSE`.

- heap_mb:

  Indexing memory budget in MB (minimum 15). Defaults to 128.

## Value

A `tnt_index` object.

## See also

[`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md),
[`tnt_add()`](https://strategicprojects.github.io/tantivyr/reference/tnt_add.md),
[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)

## Examples

``` r
sch <- tnt_schema(
  id    = tnt_i64(),
  title = tnt_text(stemmer = "english"),
  body  = tnt_text(stemmer = "english")
)
idx <- tnt_index(schema = sch) # in-memory
idx
#> 
#> ── <tnt_index> (in-memory) 
#> 0 documents · 3 fields
#> • id: i64
#> • title: text [tnt_en]
#> • body: text [tnt_en]
```
