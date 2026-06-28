# Count matching documents

Returns the total number of documents matching a query and optional
filter, ignoring any result limit.

## Usage

``` r
tnt_count(idx, query = "", fields = NULL, filter = NULL)
```

## Arguments

- idx:

  A `tnt_index`.

- query:

  A query string in tantivy's [query
  syntax](https://docs.rs/tantivy/latest/tantivy/query/struct.QueryParser.html).
  The empty string `""` matches all documents (useful with `filter`).

- fields:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Text fields searched for bare (unqualified) query terms. Defaults to
  all indexed text fields.

- filter:

  Either a tantivy query string, or a comparison expression such as
  `year >= 2020 & source == "globo"`. Supported operators: `==`, `%in%`,
  `>`, `>=`, `<`, `<=`, combined with `&` and `|`.

## Value

A single numeric count.

## See also

[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)

## Examples

``` r
idx <- tnt_index_df(
  data.frame(t = c("apple pie", "apple tart", "banana bread")),
  text = t, stemmer = "english"
)
tnt_count(idx, "apple")
#> [1] 2
```
