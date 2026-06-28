# Commit pending changes

Flushes buffered additions and deletions to the index and refreshes the
reader so they become visible to
[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md).

## Usage

``` r
tnt_commit(idx)
```

## Arguments

- idx:

  A `tnt_index`.

## Value

The `tnt_index`, invisibly.

## Examples

``` r
sch <- tnt_schema(body = tnt_text(stemmer = "english"))
idx <- tnt_index(schema = sch)
tnt_add(idx, data.frame(body = "hello")) |> tnt_commit()
```
