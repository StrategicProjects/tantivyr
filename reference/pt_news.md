# Fictional Portuguese news stories

A small collection of short news stories written in Brazilian
Portuguese, meant for trying out indexing, stemming, stop words, filters
and highlights. The stories are fictional and were written for this
package, so they can be used freely in examples and teaching material.

## Usage

``` r
pt_news
```

## Format

A tibble with 36 rows and 5 columns:

- id:

  Integer identifier, in date order.

- section:

  News section: `"economia"`, `"saúde"`, `"educação"`, `"tecnologia"`,
  `"meio ambiente"` or `"esporte"` (six stories each).

- date:

  Publication date (`Date`), from January 2024 to April 2025.

- title:

  Headline.

- body:

  Two-sentence body text.

## Source

Written for 'tantivyr'; see `data-raw/pt_news.R` in the package sources.

## Examples

``` r
idx <- tnt_index_df(
  pt_news,
  text      = c(title, body),
  filters   = c(section, date),
  stemmer   = "portuguese",
  stopwords = TRUE
)
tnt_search(idx, "vacinas", limit = 3)[, c("score", "section", "title")]
#> # A tibble: 2 × 3
#>   score section title                                                       
#>   <dbl> <chr>   <chr>                                                       
#> 1  6.99 saúde   Campanha de vacinação contra a gripe começa na segunda-feira
#> 2  2.69 saúde   Pesquisadores testam nova vacina contra a dengue            
```
