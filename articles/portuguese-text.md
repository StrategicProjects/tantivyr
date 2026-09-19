# Searching Portuguese text

``` r

library(tantivyr)
```

Portuguese is a heavily inflected language: nouns and adjectives vary in
gender and number, and every verb has dozens of forms. A search engine
that only matches exact words misses most of what a reader would
consider a hit. This vignette shows how `tantivyr` handles that with
stemming and stop words, using the bundled `pt_news` dataset.

## The data

`pt_news` holds 36 short, fictional news stories in Brazilian
Portuguese, six for each of six sections.

``` r

pt_news
#> # A tibble: 36 × 5
#>       id section       date       title                                    body 
#>    <int> <chr>         <date>     <chr>                                    <chr>
#>  1     1 tecnologia    2024-01-09 Startup recifense cria aplicativo para … O ap…
#>  2     2 economia      2024-01-15 Inflação desacelera e fecha o ano abaix… Os p…
#>  3     3 saúde         2024-01-28 Campanha de vacinação contra a gripe co… Idos…
#>  4     4 economia      2024-02-03 Banco central reduz a taxa de juros pel… A de…
#>  5     5 meio ambiente 2024-02-14 Desmatamento na Amazônia cai pelo segun… A ár…
#>  6     6 educação      2024-02-19 Escolas públicas voltam às aulas com no… Os a…
#>  7     7 esporte       2024-03-05 Seleção feminina de futebol vence e gar… As j…
#>  8     8 tecnologia    2024-03-12 Operadoras ampliam a cobertura de inter… Mais…
#>  9     9 economia      2024-03-21 Exportações de café batem recorde no pr… Os p…
#> 10    10 saúde         2024-04-02 Casos de dengue aumentam e municípios d… Os h…
#> # ℹ 26 more rows
```

## Why stemming matters

Let us index the same data twice: once with the default tokenizer, which
only lower-cases words, and once with the Portuguese stemmer and
stop-word list.

``` r

plain <- tnt_index_df(
  pt_news,
  text    = c(title, body),
  filters = c(section, date)
)

idx <- tnt_index_df(
  pt_news,
  text      = c(title, body),
  filters   = c(section, date),
  stemmer   = "portuguese",
  stopwords = TRUE
)
```

The stemmer reduces each word to a root, both when indexing and when
parsing the query, so different forms of the same word meet in the
middle. Compare the number of matches for a few queries:

``` r

queries <- c("vacinas", "queimada", "pesquisa", "pesquisar")

data.frame(
  query   = queries,
  plain   = vapply(queries, \(q) tnt_count(plain, q), numeric(1)),
  stemmed = vapply(queries, \(q) tnt_count(idx, q), numeric(1)),
  row.names = NULL
)
#>       query plain stemmed
#> 1   vacinas     0       2
#> 2  queimada     0       2
#> 3  pesquisa     2       4
#> 4 pesquisar     1       4
```

No story contains the exact word *vacinas*, so the plain index finds
nothing, while the stemmed index finds the stories about *vacina* and
*vacinação*. Likewise *pesquisa*, *pesquisar* and *pesquisadores* all
lead to the same stories:

``` r

tnt_search(idx, "pesquisar")[, c("score", "section", "title")]
#> # A tibble: 4 × 3
#>   score section    title                                                        
#>   <dbl> <chr>      <chr>                                                        
#> 1  4.78 tecnologia Pesquisadores desenvolvem bateria que carrega em cinco minut…
#> 2  4.78 saúde      Pesquisadores testam nova vacina contra a dengue             
#> 3  2.15 tecnologia Satélite brasileiro de monitoramento é lançado com sucesso   
#> 4  2.15 educação   Biblioteca municipal digitaliza acervo de jornais antigos
```

Stemming is a heuristic, not a dictionary. Irregular plurals do not
always reduce to the same root: *hospital* and *hospitais*, for example,
are kept apart by the Snowball algorithm. When that matters, search for
both forms with `OR`.

## Stop words

Words such as *de*, *a*, *o* and *para* appear in nearly every document
and carry no meaning for retrieval. With `stopwords = TRUE` they are
dropped from both the index and the query:

``` r

tnt_count(plain, "de")
#> [1] 30
tnt_count(idx, "de")
#> [1] 0
```

This also keeps natural-language queries useful, because only the
meaningful words take part in the ranking:

``` r

tnt_search(idx, "a redução dos juros", limit = 3)[, c("score", "title")]
#> # A tibble: 3 × 2
#>   score title                                                          
#>   <dbl> <chr>                                                          
#> 1  6.50 Banco central reduz a taxa de juros pela quarta vez            
#> 2  2.58 Governo anuncia novo programa de crédito para pequenas empresas
#> 3  2.58 Inflação desacelera e fecha o ano abaixo da meta
```

## Accents

By default the analyzer lower-cases text but keeps diacritics, so
*orçamento* and *orcamento* are different words:

``` r

tnt_count(idx, "orçamento")
#> [1] 2
tnt_count(idx, "orcamento")
#> [1] 0
```

People often type queries without accents. Set `fold_accents = TRUE` to
remove diacritics from the indexed words and from the queries, so both
spellings meet. Stored text is untouched, so results and snippets still
show the accents.

``` r

folded <- tnt_index_df(
  pt_news,
  text         = c(title, body),
  filters      = c(section, date),
  stemmer      = "portuguese",
  stopwords    = TRUE,
  fold_accents = TRUE
)

tnt_count(folded, "orcamento")
#> [1] 2
tnt_search(folded, "saude agua", limit = 3)[, c("score", "title")]
#> # A tibble: 3 × 2
#>   score title                                                       
#>   <dbl> <chr>                                                       
#> 1  3.00 Projeto recupera nascentes e devolve água a um rio seco     
#> 2  2.75 Campanha de vacinação contra a gripe começa na segunda-feira
#> 3  2.58 Casos de dengue aumentam e municípios decretam emergência
tnt_search(folded, "orcamento", highlight = title)$title_snippet
#> [1] "<b>Orçamento</b> municipal prioriza obras de saneamento"
#> [2] NA
```

Folding runs *after* stop-word removal and stemming, because both rely
on correctly accented text. The consequence is that an unaccented query
is stemmed as typed. Most words are unaffected, but the Portuguese
stemmer only recognises some suffixes, such as *-ção*, when they carry
the accent:

``` r

tnt_count(folded, "vacinação")
#> [1] 2
tnt_count(folded, "vacinacao")
#> [1] 0
```

If you need unaccented queries to behave exactly like accented ones,
strip the accents yourself from both the text and the queries before
indexing, for example with `iconv(x, to = "ASCII//TRANSLIT")`, and keep
the original text in a separate stored column for display.

## Query syntax

The query string supports phrases, boolean operators and field prefixes.

``` r

# exact phrase
tnt_search(idx, '"banco central"')[, c("score", "title")]
#> # A tibble: 2 × 2
#>   score title                                              
#>   <dbl> <chr>                                              
#> 1  6.13 Inflação desacelera e fecha o ano abaixo da meta   
#> 2  6.00 Banco central reduz a taxa de juros pela quarta vez

# either word
tnt_search(idx, "enchentes OR queimadas")[, c("section", "title")]
#> # A tibble: 4 × 2
#>   section       title                                                     
#>   <chr>         <chr>                                                     
#> 1 meio ambiente Queimadas atingem áreas de preservação no cerrado         
#> 2 tecnologia    Satélite brasileiro de monitoramento é lançado com sucesso
#> 3 tecnologia    Startup recifense cria aplicativo para monitorar enchentes
#> 4 meio ambiente Chuvas fortes causam enchentes e deslizamentos no litoral

# required and excluded words
tnt_search(idx, "+juros -inflação")[, "title"]
#> # A tibble: 2 × 1
#>   title                                                          
#>   <chr>                                                          
#> 1 Banco central reduz a taxa de juros pela quarta vez            
#> 2 Governo anuncia novo programa de crédito para pequenas empresas

# restrict a word to one field
tnt_search(idx, "title:vacina")[, "title"]
#> # A tibble: 2 × 1
#>   title                                                       
#>   <chr>                                                       
#> 1 Pesquisadores testam nova vacina contra a dengue            
#> 2 Campanha de vacinação contra a gripe começa na segunda-feira
```

## Filters, ordering and highlights

Filters combine with the text query and are written as ordinary R
comparisons.

``` r

tnt_search(idx, "água", filter = date >= as.Date("2025-01-01"))[, c("date", "title")]
#> # A tibble: 2 × 2
#>   date                title                                                
#>   <dttm>              <chr>                                                
#> 1 2025-02-11 00:00:00 Orçamento municipal prioriza obras de saneamento     
#> 2 2025-04-22 00:00:00 Usina solar flutuante começa a operar em reservatório

tnt_search(idx, "", filter = section == "esporte", order_by = date, limit = 3)[
  , c("date", "title")
]
#> # A tibble: 3 × 2
#>   date                title                                                     
#>   <dttm>              <chr>                                                     
#> 1 2025-04-13 00:00:00 Corrida de rua reúne vinte mil atletas no centro da cidade
#> 2 2025-02-02 00:00:00 Nadador de dezessete anos vence campeonato sul-americano  
#> 3 2024-10-28 00:00:00 Clube centenário inaugura estádio reformado
```

`highlight` returns a snippet for each requested field, with the
matching words wrapped in `<b>` tags. Note that the snippet marks the
words as they appear in the text, not the stemmed query.

``` r

hits <- tnt_search(idx, "vacinas", highlight = c(title, body))
hits$title_snippet
#> [1] "Campanha de <b>vacinação</b> contra a gripe começa na segunda-feira"
#> [2] "Pesquisadores testam nova <b>vacina</b> contra a dengue"
hits$body_snippet
#> [1] "Idosos e crianças serão <b>vacinados</b> primeiro. A secretaria de saúde recebeu dois milhões de doses da <b>vacina</b>"
#> [2] NA
```

## Other languages

Portuguese is one of several Snowball stemmers bundled with the engine.
The same workflow applies to any of them:

``` r

tnt_stemmers()
#>  [1] "none"       "raw"        "portuguese" "english"    "spanish"   
#>  [6] "french"     "german"     "italian"    "dutch"      "russian"   
#> [11] "swedish"    "norwegian"  "danish"     "finnish"    "romanian"  
#> [16] "hungarian"  "turkish"    "arabic"     "greek"      "tamil"
```
