# Searching, counting, and the tidy filter translator.

# A zero-row data frame whose columns are the schema fields (drives tidyselect).
tnt_schema_frame <- function(info) {
  cols <- stats::setNames(rep(list(logical(0)), nrow(info)), info$name)
  as.data.frame(cols, check.names = FALSE, stringsAsFactors = FALSE)
}

# Resolve a tidyselect quosure of field names against the schema.
tnt_resolve_fields <- function(idx, quo) {
  if (rlang::quo_is_null(quo)) {
    return(NULL)
  }
  names(tidyselect::eval_select(quo, tnt_schema_frame(idx$schema_info)))
}

# Format a date value as unquoted RFC 3339 (tantivy's date range grammar).
tnt_fmt_date <- function(value) {
  v <- if (inherits(value, "Date")) {
    as.POSIXct(paste0(format(value), " 00:00:00"), tz = "UTC")
  } else {
    as.POSIXct(value, tz = "UTC")
  }
  strftime(v, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

# Format a value for the tantivy query grammar.
tnt_fmt_value <- function(field, value, info, quote_text = TRUE) {
  kind <- info$kind[match(field, info$name)]
  if (!is.na(kind) && kind == "date") {
    return(tnt_fmt_date(value))
  }
  if (is.character(value) || (!is.na(kind) && kind %in% c("text", "json"))) {
    if (quote_text) paste0("\"", value, "\"") else as.character(value)
  } else {
    format(value, scientific = FALSE, trim = TRUE)
  }
}

# Translate an R filter expression AST into a tantivy query string.
tnt_translate_filter <- function(expr, env, info) {
  node <- function(e) {
    if (!rlang::is_call(e)) {
      cli::cli_abort("Unsupported filter element: {.code {rlang::expr_text(e)}}.")
    }
    op <- rlang::call_name(e)
    args <- rlang::call_args(e)
    eq_value <- function() rlang::eval_tidy(args[[2]], env = env)
    field <- function() rlang::as_name(args[[1]])
    switch(op,
      "(" = node(args[[1]]),
      "&" = paste0("(", node(args[[1]]), ") AND (", node(args[[2]]), ")"),
      "|" = paste0("(", node(args[[1]]), ") OR (", node(args[[2]]), ")"),
      "==" = {
        fld <- field()
        kind <- info$kind[match(fld, info$name)]
        if (!is.na(kind) && kind == "date") {
          d <- tnt_fmt_date(eq_value())
          paste0(fld, ":[", d, " TO ", d, "]")
        } else {
          paste0(fld, ":", tnt_fmt_value(fld, eq_value(), info))
        }
      },
      "%in%" = {
        vals <- eq_value()
        terms <- vapply(vals, function(v) {
          paste0(field(), ":", tnt_fmt_value(field(), v, info))
        }, character(1))
        paste0("(", paste(terms, collapse = " OR "), ")")
      },
      ">=" = paste0(field(), ":[", tnt_fmt_value(field(), eq_value(), info, FALSE), " TO *]"),
      ">" = paste0(field(), ":{", tnt_fmt_value(field(), eq_value(), info, FALSE), " TO *}"),
      "<=" = paste0(field(), ":[* TO ", tnt_fmt_value(field(), eq_value(), info, FALSE), "]"),
      "<" = paste0(field(), ":[* TO ", tnt_fmt_value(field(), eq_value(), info, FALSE), "}"),
      cli::cli_abort("Unsupported operator {.code {op}} in filter.")
    )
  }
  node(expr)
}

# Resolve the `filter` argument (NULL, literal string, variable, or expression).
tnt_resolve_filter <- function(quo, info) {
  if (rlang::quo_is_null(quo)) {
    return("")
  }
  expr <- rlang::quo_get_expr(quo)
  env <- rlang::quo_get_env(quo)
  if (is.character(expr)) {
    return(expr)
  }
  if (rlang::is_call(expr) &&
    rlang::call_name(expr) %in% c("&", "|", "==", ">=", ">", "<=", "<", "%in%", "(")) {
    return(tnt_translate_filter(expr, env, info))
  }
  val <- rlang::eval_tidy(quo)
  if (!is.character(val) || length(val) != 1L) {
    cli::cli_abort("{.arg filter} must be a string or a comparison expression.")
  }
  val
}

#' Search an index
#'
#' Runs a BM25 full-text search and returns the top matches as a tibble. Supports
#' structured filters, result ordering and snippet highlighting.
#'
#' @param idx A `tnt_index`.
#' @param query A query string in tantivy's
#'   [query syntax](https://docs.rs/tantivy/latest/tantivy/query/struct.QueryParser.html).
#'   The empty string `""` matches all documents (useful with `filter`).
#' @param limit Maximum number of results. Defaults to 10.
#' @param fields <[`tidy-select`][tidyselect::language]> Text fields searched for
#'   bare (unqualified) query terms. Defaults to all indexed text fields.
#' @param filter Either a tantivy query string, or a comparison expression such
#'   as `year >= 2020 & source == "globo"`. Supported operators: `==`, `%in%`,
#'   `>`, `>=`, `<`, `<=`, combined with `&` and `|`.
#' @param highlight <[`tidy-select`][tidyselect::language]> Stored text fields to
#'   return highlighted snippets for. One `<field>_snippet` column is added per
#'   selected field, with matches wrapped in `<b>` tags.
#' @param snippet_chars Maximum snippet length in characters. Defaults to 150.
#' @param order_by <[`tidy-select`][tidyselect::language]> A single numeric/date
#'   *fast* field to order by instead of BM25 score. When set, `score` is `NA`.
#' @param desc Logical. Order descending (the default) when `order_by` is set.
#'
#' @return A tibble with a `score` column, every stored field, and any requested
#'   `*_snippet` columns.
#' @seealso [tnt_count()], [tnt_index_df()]
#' @examples
#' df <- data.frame(
#'   id = 1:3,
#'   title = c("Quick brown fox", "Lazy dog", "Brown bear"),
#'   year = c(2019L, 2021L, 2023L)
#' )
#' idx <- tnt_index_df(df, text = title, filters = year, stemmer = "english")
#' tnt_search(idx, "brown")
#' tnt_search(idx, "brown", filter = year >= 2021)
#' tnt_search(idx, "fox", highlight = title)
#' @export
tnt_search <- function(idx, query = "", limit = 10L, fields = NULL,
                       filter = NULL, highlight = NULL, snippet_chars = 150L,
                       order_by = NULL, desc = TRUE) {
  tnt_check_index(idx)
  info <- idx$schema_info

  default_fields <- tnt_resolve_fields(idx, rlang::enquo(fields))
  if (is.null(default_fields)) {
    default_fields <- tnt_default_fields(idx)
  }
  highlight_fields <- tnt_resolve_fields(idx, rlang::enquo(highlight))
  if (is.null(highlight_fields)) highlight_fields <- character(0)
  order_fields <- tnt_resolve_fields(idx, rlang::enquo(order_by))
  order_field <- if (length(order_fields)) order_fields[[1]] else ""
  filter_str <- tnt_resolve_filter(rlang::enquo(filter), info)

  res <- tnt_search_(
    idx$ptr,
    as.character(query %||% ""),
    as.numeric(limit),
    as.character(default_fields),
    as.character(filter_str),
    as.character(highlight_fields),
    as.numeric(snippet_chars),
    as.character(order_field),
    isTRUE(desc)
  )

  tnt_assemble_results(res, info)
}

# Build the result tibble: convert dates, rename snippet columns.
tnt_assemble_results <- function(res, info) {
  for (nm in names(res)) {
    kind <- info$kind[match(nm, info$name)]
    if (!is.na(kind) && kind == "date") {
      res[[nm]] <- .POSIXct(res[[nm]], tz = "UTC")
    }
  }
  hl <- grepl("^__hl_", names(res))
  names(res)[hl] <- paste0(sub("^__hl_", "", names(res)[hl]), "_snippet")
  as_tibble(res)
}

#' Count matching documents
#'
#' Returns the total number of documents matching a query and optional filter,
#' ignoring any result limit.
#'
#' @inheritParams tnt_search
#' @return A single numeric count.
#' @seealso [tnt_search()]
#' @examples
#' idx <- tnt_index_df(
#'   data.frame(t = c("apple pie", "apple tart", "banana bread")),
#'   text = t, stemmer = "english"
#' )
#' tnt_count(idx, "apple")
#' @export
tnt_count <- function(idx, query = "", fields = NULL, filter = NULL) {
  tnt_check_index(idx)
  info <- idx$schema_info
  default_fields <- tnt_resolve_fields(idx, rlang::enquo(fields))
  if (is.null(default_fields)) {
    default_fields <- tnt_default_fields(idx)
  }
  filter_str <- tnt_resolve_filter(rlang::enquo(filter), info)
  tnt_count_(
    idx$ptr,
    as.character(query %||% ""),
    as.character(default_fields),
    as.character(filter_str)
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
