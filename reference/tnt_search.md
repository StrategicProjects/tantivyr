# Search an index

Runs a BM25 full-text search and returns the top matches as a tibble.
Supports structured filters, result ordering and snippet highlighting.

## Usage

``` r
tnt_search(
  idx,
  query = "",
  limit = 10L,
  fields = NULL,
  filter = NULL,
  highlight = NULL,
  snippet_chars = 150L,
  order_by = NULL,
  desc = TRUE
)
```

## Arguments

- idx:

  A `tnt_index`.

- query:

  A query string in tantivy's [query
  syntax](https://docs.rs/tantivy/latest/tantivy/query/struct.QueryParser.html).
  The empty string `""` matches all documents (useful with `filter`).

- limit:

  Maximum number of results. Defaults to 10.

- fields:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Text fields searched for bare (unqualified) query terms. Defaults to
  all indexed text fields.

- filter:

  Either a tantivy query string, or a comparison expression such as
  `year >= 2020 & source == "globo"`. Supported operators: `==`, `%in%`,
  `>`, `>=`, `<`, `<=`, combined with `&` and `|`.

- highlight:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Stored text fields to return highlighted snippets for. One
  `<field>_snippet` column is added per selected field, with matches
  wrapped in `<b>` tags.

- snippet_chars:

  Maximum snippet length in characters. Defaults to 150.

- order_by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  A single numeric/date *fast* field to order by instead of BM25 score.
  When set, `score` is `NA`.

- desc:

  Logical. Order descending (the default) when `order_by` is set.

## Value

A tibble with a `score` column, every stored field, and any requested
`*_snippet` columns.

## See also

[`tnt_count()`](https://strategicprojects.github.io/tantivyr/reference/tnt_count.md),
[`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md)

## Examples

``` r
df <- data.frame(
  id = 1:3,
  title = c("Quick brown fox", "Lazy dog", "Brown bear"),
  year = c(2019L, 2021L, 2023L)
)
idx <- tnt_index_df(df, text = title, filters = year, stemmer = "english")
tnt_search(idx, "brown")
#> # A tibble: 2 × 4
#>   score    id title            year
#>   <dbl> <dbl> <chr>           <dbl>
#> 1 0.499     3 Brown bear       2023
#> 2 0.421     1 Quick brown fox  2019
tnt_search(idx, "brown", filter = year >= 2021)
#> # A tibble: 1 × 4
#>   score    id title       year
#>   <dbl> <dbl> <chr>      <dbl>
#> 1 0.499     3 Brown bear  2023
tnt_search(idx, "fox", highlight = title)
#> # A tibble: 1 × 5
#>   score    id title            year title_snippet         
#>   <dbl> <dbl> <chr>           <dbl> <chr>                 
#> 1 0.878     1 Quick brown fox  2019 Quick brown <b>fox</b>
```
