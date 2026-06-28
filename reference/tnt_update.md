# Update documents (delete then re-add)

Replaces documents by deleting any existing document that shares a key
value (the `by` field) with a row of `data`, then adding the rows of
`data`. The `by` field must be an exact field (numeric/date, or text
with `stemmer = "raw"`). Call
[`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md)
afterwards.

## Usage

``` r
tnt_update(idx, data, by)
```

## Arguments

- idx:

  A `tnt_index`.

- data:

  A data frame of replacement documents.

- by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single key column present in both `data` and the schema.

## Value

The `tnt_index`, invisibly.

## See also

[`tnt_add()`](https://strategicprojects.github.io/tantivyr/reference/tnt_add.md),
[`tnt_delete()`](https://strategicprojects.github.io/tantivyr/reference/tnt_delete.md)

## Examples

``` r
sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
idx <- tnt_index(schema = sch)
tnt_add(idx, data.frame(id = 1:2, body = c("old one", "old two"))) |>
  tnt_commit()
tnt_update(idx, data.frame(id = 1L, body = "new one"), by = id) |>
  tnt_commit()
```
