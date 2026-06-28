# Schema definition: field constructors and tnt_schema().

new_tnt_field <- function(kind, stored, indexed, fast, stemmer = "none",
                          stopwords = FALSE) {
  structure(
    list(
      kind = kind,
      stored = isTRUE(stored),
      indexed = isTRUE(indexed),
      fast = isTRUE(fast),
      stemmer = stemmer,
      stopwords = isTRUE(stopwords)
    ),
    class = "tnt_field"
  )
}

#' Define schema fields
#'
#' These constructors describe a single field in a [tnt_schema()]. Each returns
#' a lightweight `tnt_field` object.
#'
#' @param stored Logical. Keep the original value so it is returned by
#'   [tnt_search()]. Defaults to `TRUE`.
#' @param indexed Logical. Index the field so it can be searched or filtered.
#'   Defaults to `TRUE`.
#' @param fast Logical. Build a columnar "fast field" enabling fast filtering
#'   and ordering (required by `order_by` in [tnt_search()]). Defaults to
#'   `FALSE`, except `tnt_text(fast = ...)` which has no fast field by default.
#' @param stemmer Stemming/tokenization for a text field. One of `"none"` (plain
#'   tokenization, lower-cased), `"raw"` (exact, untokenized — ideal for ids and
#'   exact filters), or a Snowball language such as `"portuguese"` or
#'   `"english"`. See [tnt_stemmers()].
#' @param stopwords Logical. Remove stop words for the chosen language. Bundled
#'   for Portuguese and English. Defaults to `FALSE`.
#'
#' @return A `tnt_field` object.
#' @seealso [tnt_schema()]
#' @examples
#' tnt_schema(
#'   id    = tnt_i64(),
#'   title = tnt_text(stemmer = "portuguese", stopwords = TRUE),
#'   body  = tnt_text(stemmer = "portuguese"),
#'   date  = tnt_date()
#' )
#' @name tnt_field
NULL

#' @rdname tnt_field
#' @export
tnt_text <- function(stored = TRUE, indexed = TRUE, fast = FALSE,
                     stemmer = "none", stopwords = FALSE) {
  stemmer <- match.arg(stemmer, tnt_valid_stemmers)
  new_tnt_field("text", stored, indexed, fast, stemmer, stopwords)
}

#' @rdname tnt_field
#' @export
tnt_i64 <- function(stored = TRUE, indexed = TRUE, fast = FALSE) {
  new_tnt_field("i64", stored, indexed, fast)
}

#' @rdname tnt_field
#' @export
tnt_u64 <- function(stored = TRUE, indexed = TRUE, fast = FALSE) {
  new_tnt_field("u64", stored, indexed, fast)
}

#' @rdname tnt_field
#' @export
tnt_f64 <- function(stored = TRUE, indexed = TRUE, fast = FALSE) {
  new_tnt_field("f64", stored, indexed, fast)
}

#' @rdname tnt_field
#' @export
tnt_bool <- function(stored = TRUE, indexed = TRUE, fast = FALSE) {
  new_tnt_field("bool", stored, indexed, fast)
}

#' @rdname tnt_field
#' @export
tnt_date <- function(stored = TRUE, indexed = TRUE, fast = FALSE) {
  new_tnt_field("date", stored, indexed, fast)
}

#' @rdname tnt_field
#' @export
tnt_json <- function(stored = TRUE, indexed = TRUE) {
  new_tnt_field("json", stored, indexed, fast = FALSE)
}

#' Create a search schema
#'
#' Combine named [tnt_field] definitions into a schema that can be passed to
#' [tnt_index()].
#'
#' @param ... Named field definitions, e.g. `title = tnt_text()`.
#'
#' @return A `tnt_schema` object (a named list of `tnt_field`s).
#' @seealso [tnt_field], [tnt_index()]
#' @examples
#' tnt_schema(
#'   id    = tnt_i64(),
#'   title = tnt_text(stemmer = "english"),
#'   body  = tnt_text(stemmer = "english")
#' )
#' @export
tnt_schema <- function(...) {
  fields <- list(...)
  nms <- names(fields)
  if (length(fields) == 0L) {
    cli::cli_abort("A schema must contain at least one field.")
  }
  if (is.null(nms) || any(nms == "")) {
    cli::cli_abort("All fields in {.fn tnt_schema} must be named.")
  }
  if (anyDuplicated(nms)) {
    cli::cli_abort("Field names must be unique.")
  }
  is_field <- vapply(fields, inherits, logical(1), "tnt_field")
  if (!all(is_field)) {
    cli::cli_abort(c(
      "Every argument to {.fn tnt_schema} must be a {.cls tnt_field}.",
      x = "Problem with: {.field {nms[!is_field]}}."
    ))
  }
  structure(fields, class = "tnt_schema")
}

# Turn a tnt_schema into the parallel vectors the Rust constructor expects.
tnt_schema_vectors <- function(schema) {
  nms <- names(schema)
  kinds <- vapply(schema, function(f) f$kind, character(1))
  stored <- vapply(schema, function(f) f$stored, logical(1))
  indexed <- vapply(schema, function(f) f$indexed, logical(1))
  fast <- vapply(schema, function(f) f$fast, logical(1))
  tokenizers <- vapply(schema, function(f) {
    if (f$kind %in% c("text", "json")) {
      tnt_tokenizer_name(f$stemmer, f$stopwords)
    } else {
      ""
    }
  }, character(1))
  list(
    names = nms, kinds = kinds, stored = stored,
    indexed = indexed, fast = fast, tokenizers = tokenizers
  )
}

#' List supported stemmer languages
#'
#' @return A character vector of language names accepted by the `stemmer`
#'   argument of [tnt_text()].
#' @examples
#' tnt_stemmers()
#' @export
tnt_stemmers <- function() {
  c("none", "raw", names(tnt_lang_codes))
}

#' @export
print.tnt_field <- function(x, ...) {
  extra <- character(0)
  if (x$kind %in% c("text", "json") && !is.null(x$stemmer) && x$stemmer != "none") {
    extra <- c(extra, paste0("stemmer=", x$stemmer))
    if (isTRUE(x$stopwords)) extra <- c(extra, "stopwords")
  }
  flags <- c(
    if (x$stored) "stored",
    if (x$indexed) "indexed",
    if (x$fast) "fast"
  )
  cli::cli_text("<tnt_field {x$kind}> {paste(c(flags, extra), collapse = ', ')}")
  invisible(x)
}

#' @export
print.tnt_schema <- function(x, ...) {
  cli::cli_h3("tantivyr schema ({length(x)} field{?s})")
  for (nm in names(x)) {
    f <- x[[nm]]
    tok <- if (f$kind %in% c("text", "json")) {
      paste0(" [", tnt_tokenizer_name(f$stemmer, f$stopwords), "]")
    } else {
      ""
    }
    cli::cli_li("{.field {nm}}: {f$kind}{tok}")
  }
  invisible(x)
}
