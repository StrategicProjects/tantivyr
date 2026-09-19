#' Fictional Portuguese news stories
#'
#' A small collection of short news stories written in Brazilian Portuguese,
#' meant for trying out indexing, stemming, stop words, filters and highlights.
#' The stories are fictional and were written for this package, so they can be
#' used freely in examples and teaching material.
#'
#' @format A tibble with 36 rows and 5 columns:
#' \describe{
#'   \item{id}{Integer identifier, in date order.}
#'   \item{section}{News section: `"economia"`, `"saúde"`, `"educação"`,
#'     `"tecnologia"`, `"meio ambiente"` or `"esporte"` (six stories each).}
#'   \item{date}{Publication date (`Date`), from January 2024 to April 2025.}
#'   \item{title}{Headline.}
#'   \item{body}{Two-sentence body text.}
#' }
#' @source Written for 'tantivyr'; see `data-raw/pt_news.R` in the package
#'   sources.
#' @examples
#' idx <- tnt_index_df(
#'   pt_news,
#'   text      = c(title, body),
#'   filters   = c(section, date),
#'   stemmer   = "portuguese",
#'   stopwords = TRUE
#' )
#' tnt_search(idx, "vacinas", limit = 3)[, c("score", "section", "title")]
"pt_news"
