# Index a data frame in one call

A convenience wrapper that infers a schema from `data`, creates an
index, adds every row and commits. Text columns are made searchable;
filter columns are indexed for filtering and ordering; all other columns
are stored so they are returned by
[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md).

## Usage

``` r
tnt_index_df(
  data,
  text,
  filters = NULL,
  stemmer = "none",
  stopwords = FALSE,
  stored = TRUE,
  path = NULL,
  overwrite = FALSE,
  heap_mb = 128
)
```

## Arguments

- data:

  A data frame.

- text:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to index as full-text fields.

- filters:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to index for filtering/ordering (their type is inferred).
  Optional.

- stemmer, stopwords:

  Stemming and stop-word options applied to all `text` columns. See
  [`tnt_text()`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md).

- stored:

  Logical. Store text columns so they are returned by searches.

- path, overwrite, heap_mb:

  Passed to
  [`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md).

## Value

A committed `tnt_index` object.

## See also

[`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md),
[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)

## Examples

``` r
df <- data.frame(
  id = 1:2,
  title = c("Orçamento público aprovado", "Reforma tributária avança"),
  year = c(2023L, 2024L)
)
idx <- tnt_index_df(df, text = title, filters = year, stemmer = "portuguese")
tnt_search(idx, "orcamento")
#> # A tibble: 0 × 4
#> # ℹ 4 variables: score <dbl>, id <dbl>, title <chr>, year <dbl>
```
