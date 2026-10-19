# Getting started with tantivyr

``` r

library(tantivyr)
```

`tantivyr` indexes text and searches it with BM25 ranking, structured
filters, highlighting and incremental updates — locally, with no server.
This vignette walks through the two ways of using it: the one-call
convenience wrapper and the explicit schema API.

## The convenience layer: `tnt_index_df()`

Most of the time you have a data frame and want to search some of its
columns.
[`tnt_index_df()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index_df.md)
infers a schema, indexes every row and commits in one call.

``` r

news <- data.frame(
  id     = 1:5,
  title  = c(
    "Orçamento público aprovado pelo congresso",
    "Reforma tributária avança no senado",
    "Nova lei de licitações entra em vigor",
    "Congresso debate orçamentos municipais",
    "Tribunal de contas analisa despesas"
  ),
  source = c("A", "B", "A", "C", "B"),
  year   = c(2022L, 2023L, 2024L, 2024L, 2023L)
)

idx <- tnt_index_df(
  news,
  text      = title,         # full-text column(s)
  filters   = c(source, year), # columns to filter / order on
  stemmer   = "portuguese",
  stopwords = TRUE
)
idx
#> 
#> ── <tnt_index> (in-memory)
#> 5 documents · 4 fields
#> • id: i64
#> • title: text [tnt_pt_stop]
#> • source: text [raw]
#> • year: i64
```

### Searching

[`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)
returns a tibble with a `score` column followed by every stored field.
Because we used the Portuguese stemmer, a search for *orçamento* also
matches *orçamentos*.

``` r

tnt_search(idx, "orçamento")
#> # A tibble: 2 × 5
#>   score    id title                                     source  year
#>   <dbl> <dbl> <chr>                                     <chr>  <dbl>
#> 1 0.893     1 Orçamento público aprovado pelo congresso A       2022
#> 2 0.893     4 Congresso debate orçamentos municipais    C       2024
```

### Filtering

Filters can be written as ordinary R comparisons. They are combined with
the text query.

``` r

tnt_search(idx, "", filter = year >= 2024)
#> # A tibble: 2 × 5
#>   score    id title                                  source  year
#>   <dbl> <dbl> <chr>                                  <chr>  <dbl>
#> 1     1     3 Nova lei de licitações entra em vigor  A       2024
#> 2     1     4 Congresso debate orçamentos municipais C       2024

tnt_search(idx, "congresso", filter = source == "A")
#> # A tibble: 1 × 5
#>   score    id title                                     source  year
#>   <dbl> <dbl> <chr>                                     <chr>  <dbl>
#> 1  1.77     1 Orçamento público aprovado pelo congresso A       2022

tnt_search(idx, "", filter = year %in% c(2022, 2024), limit = 10)
#> # A tibble: 3 × 5
#>   score    id title                                     source  year
#>   <dbl> <dbl> <chr>                                     <chr>  <dbl>
#> 1 1.39      1 Orçamento público aprovado pelo congresso A       2022
#> 2 0.875     3 Nova lei de licitações entra em vigor     A       2024
#> 3 0.875     4 Congresso debate orçamentos municipais    C       2024
```

You can also pass a raw [Tantivy query
string](https://docs.rs/tantivy/latest/tantivy/query/struct.QueryParser.html)
for anything the helpers do not cover:

``` r

tnt_search(idx, "", filter = "year:[2023 TO *] AND source:B")
#> # A tibble: 2 × 5
#>   score    id title                               source  year
#>   <dbl> <dbl> <chr>                               <chr>  <dbl>
#> 1 0.875     5 Tribunal de contas analisa despesas B       2023
#> 2 0.875     2 Reforma tributária avança no senado B       2023
```

### Highlighting and ordering

``` r

tnt_search(idx, "congresso", highlight = title)$title_snippet
#> [1] "Orçamento público aprovado pelo <b>congresso</b>"
#> [2] "<b>Congresso</b> debate orçamentos municipais"

tnt_search(idx, "", order_by = year, desc = TRUE)[, c("title", "year")]
#> # A tibble: 5 × 2
#>   title                                      year
#>   <chr>                                     <dbl>
#> 1 Nova lei de licitações entra em vigor      2024
#> 2 Congresso debate orçamentos municipais     2024
#> 3 Tribunal de contas analisa despesas        2023
#> 4 Reforma tributária avança no senado        2023
#> 5 Orçamento público aprovado pelo congresso  2022
```

### Counting

[`tnt_count()`](https://strategicprojects.github.io/tantivyr/reference/tnt_count.md)
returns the total number of matches, ignoring any limit.

``` r

tnt_count(idx, "congresso")
#> [1] 2
tnt_count(idx, "", filter = year == 2024)
#> [1] 2
```

## The explicit layer: schemas and persistence

For full control over how each field is stored, indexed and analysed,
build a schema with
[`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md)
and the `tnt_*()` field constructors, then manage the index yourself.

``` r

sch <- tnt_schema(
  id    = tnt_i64(),
  slug  = tnt_text(stemmer = "raw"),                 # exact key for updates
  title = tnt_text(stemmer = "portuguese", stored = TRUE),
  body  = tnt_text(stemmer = "portuguese"),
  date  = tnt_date(fast = TRUE)
)

path <- tempfile()
idx <- tnt_index(path, schema = sch)
```

Add documents and commit to make them searchable. Operations return the
index invisibly, so they pipe.

``` r

docs <- data.frame(
  id    = 1:2,
  slug  = c("edital-001", "edital-002"),
  title = c("Edital de licitação 001", "Edital de licitação 002"),
  body  = c("Aquisição de equipamentos de informática.",
            "Contratação de serviços de limpeza."),
  date  = as.Date(c("2024-02-01", "2024-03-15"))
)

idx |> tnt_add(docs) |> tnt_commit()
tnt_num_docs(idx)
#> [1] 2
```

### Incremental updates and deletes

[`tnt_update()`](https://strategicprojects.github.io/tantivyr/reference/tnt_update.md)
replaces documents by a key column;
[`tnt_delete()`](https://strategicprojects.github.io/tantivyr/reference/tnt_delete.md)
removes them. Both need a commit to take effect.

``` r

idx |>
  tnt_update(
    data.frame(id = 1L, slug = "edital-001",
               title = "Edital de licitação 001 (retificado)",
               body = "Aquisição de notebooks.",
               date = as.Date("2024-02-10")),
    by = slug
  ) |>
  tnt_commit()

tnt_search(idx, "notebooks")[, c("id", "title")]
#> # A tibble: 1 × 2
#>      id title                               
#>   <dbl> <chr>                               
#> 1     1 Edital de licitação 001 (retificado)

idx |> tnt_delete(slug == "edital-002") |> tnt_commit()
tnt_num_docs(idx)
#> [1] 1
```

### Reopening an index

On-disk indexes survive across sessions. Call
[`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md)
with just the path to reopen — the schema is restored automatically.

``` r

reopened <- tnt_index(path)
tnt_num_docs(reopened)
#> [1] 1
```

## Where to go next

- [`?tnt_search`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)
  documents every search option.
- [`?tnt_field`](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
  lists the field types and their stemming/stop-word options.
- [`tnt_stemmers()`](https://strategicprojects.github.io/tantivyr/reference/tnt_stemmers.md)
  returns the supported languages.
