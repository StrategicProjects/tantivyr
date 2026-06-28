# tantivyr

**tantivyr** brings fast, local full-text search to R. It wraps the
[Tantivy](https://github.com/quickwit-oss/tantivy) search engine — a
Rust library inspired by Apache Lucene — to let you index a data frame
or a collection of documents and search it with **BM25 ranking**,
**structured filters**, **snippet highlighting** and **incremental
updates**, all on your own machine.

It is built for text in **Portuguese** and **English** (stemming and
stop words included), making it a good fit for public documents, news
clippings, extracted PDF text, transcripts and legal acts.

## Installation

You need a [Rust toolchain](https://www.rust-lang.org/tools/install)
(`cargo`) to build the package from source.

``` r

# install.packages("pak")
pak::pak("StrategicProjects/tantivyr")
```

## Quick start

The fastest way in is
[`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md):
point it at a data frame, say which columns are text and which are
filters, and search.

``` r

library(tantivyr)

news <- data.frame(
  id    = 1:4,
  title = c(
    "Orçamento público aprovado pelo congresso",
    "Reforma tributária avança no senado",
    "Nova lei de licitações entra em vigor",
    "Congresso debate orçamentos municipais"
  ),
  year  = c(2022L, 2023L, 2024L, 2024L)
)

idx <- tnt_index_df(
  news,
  text     = title,
  filters  = year,
  stemmer  = "portuguese",
  stopwords = TRUE
)

# BM25 search — note the Portuguese stemmer matches "orçamentos" too
tnt_search(idx, "orçamento")
#> # A tibble: 2 × 4
#>   score    id title                                      year
#>   <dbl> <dbl> <chr>                                     <dbl>
#> 1 0.710     4 Congresso debate orçamentos municipais     2024
#> 2 0.710     1 Orçamento público aprovado pelo congresso  2022
```

### Filters, ordering and highlighting

Filters can be written as plain comparisons (`year >= 2024`) or as
Tantivy query strings. Snippets come back as `<field>_snippet` columns.

``` r

# structured filter
tnt_search(idx, "", filter = year >= 2024)
#> # A tibble: 2 × 4
#>   score    id title                                   year
#>   <dbl> <dbl> <chr>                                  <dbl>
#> 1     1     4 Congresso debate orçamentos municipais  2024
#> 2     1     3 Nova lei de licitações entra em vigor   2024

# highlighted snippets
tnt_search(idx, "congresso", highlight = title)$title_snippet
#> [1] "<b>Congresso</b> debate orçamentos municipais"   
#> [2] "Orçamento público aprovado pelo <b>congresso</b>"

# order by a fast field instead of relevance
tnt_search(idx, "", order_by = year, desc = TRUE)[, c("title", "year")]
#> # A tibble: 4 × 2
#>   title                                      year
#>   <chr>                                     <dbl>
#> 1 Congresso debate orçamentos municipais     2024
#> 2 Nova lei de licitações entra em vigor      2024
#> 3 Reforma tributária avança no senado        2023
#> 4 Orçamento público aprovado pelo congresso  2022
```

## Explicit schema and incremental updates

For full control, declare a schema and manage the index yourself.
Indexes can live on disk (and be reopened later) or in memory.

``` r

sch <- tnt_schema(
  id    = tnt_i64(),
  title = tnt_text(stemmer = "portuguese", stored = TRUE),
  body  = tnt_text(stemmer = "portuguese")
)

idx <- tnt_index(path = tempfile(), schema = sch)

idx |>
  tnt_add(data.frame(id = 1L, title = "Edital de licitação", body = "...")) |>
  tnt_commit()

# update (replace by key) and delete, then commit
idx |>
  tnt_update(data.frame(id = 1L, title = "Edital retificado", body = "..."), by = id) |>
  tnt_commit()

tnt_count(idx, "edital")
#> [1] 1
```

## How it compares

`tantivyr` is for *retrieval*: ranked, filtered, highlighted search over
text you control, with an index that updates incrementally and persists
to disk. It is not a database and not an embeddings/semantic-search tool
— it is the local, dependency-light BM25 engine that R has been missing.

## License

MIT © tantivyr authors. Tantivy itself is MIT licensed.
