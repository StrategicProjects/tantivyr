# Internal helpers (not exported).

# Snowball languages with embedded stop-word lists in the Rust layer.
tnt_stopword_langs <- c("pt", "en")

# Map a user-facing stemmer name to a two-letter Snowball code.
tnt_lang_codes <- c(
  portuguese = "pt", english = "en", spanish = "es", french = "fr",
  german = "de", italian = "it", dutch = "nl", russian = "ru",
  swedish = "sv", norwegian = "no", danish = "da", finnish = "fi",
  romanian = "ro", hungarian = "hu", turkish = "tr", arabic = "ar",
  greek = "el", tamil = "ta"
)

# Valid `stemmer =` values for text fields.
tnt_valid_stemmers <- c("none", "raw", names(tnt_lang_codes), unname(tnt_lang_codes))

# Resolve a stemmer name to the tantivy tokenizer name used in the schema.
# Mirrors the decoding logic in `src/rust/src/analyzer.rs`.
tnt_tokenizer_name <- function(stemmer = "none", stopwords = FALSE) {
  stemmer <- match.arg(stemmer, tnt_valid_stemmers)
  if (stemmer == "none") {
    return("default")
  }
  if (stemmer == "raw") {
    return("raw")
  }
  code <- if (stemmer %in% names(tnt_lang_codes)) tnt_lang_codes[[stemmer]] else stemmer
  if (isTRUE(stopwords) && !code %in% tnt_stopword_langs) {
    cli::cli_warn(c(
      "Stop-word removal is not bundled for stemmer {.val {stemmer}}.",
      i = "Stemming is applied; stop words are kept. Bundled languages: {.val {tnt_stopword_langs}}."
    ))
    stopwords <- FALSE
  }
  if (isTRUE(stopwords)) paste0("tnt_", code, "_stop") else paste0("tnt_", code)
}

# Infer a tantivy field kind from an R column (used by tnt_index_df()).
tnt_infer_kind <- function(x) {
  if (inherits(x, c("Date", "POSIXct"))) {
    "date"
  } else if (is.logical(x)) {
    "bool"
  } else if (is.integer(x)) {
    "i64"
  } else if (is.numeric(x)) {
    "f64"
  } else {
    "text"
  }
}

# Coerce a single R column to the representation the Rust layer expects for a
# given field kind: numeric/date -> double, text -> character, bool -> logical.
tnt_coerce_column <- function(x, kind) {
  switch(kind,
    date = {
      if (inherits(x, "Date")) {
        as.numeric(x) * 86400
      } else if (inherits(x, "POSIXct")) {
        as.numeric(x)
      } else {
        as.numeric(x)
      }
    },
    i64 = ,
    u64 = ,
    f64 = as.numeric(x),
    bool = as.logical(x),
    text = ,
    json = as.character(x),
    as.character(x)
  )
}

# Is `x` a tantivy index object?
is_tnt_index <- function(x) inherits(x, "tnt_index")

tnt_check_index <- function(x, arg = "idx", call = rlang::caller_env()) {
  if (!is_tnt_index(x)) {
    cli::cli_abort("{.arg {arg}} must be a {.cls tnt_index} object.", call = call)
  }
  invisible(x)
}

# Default searchable fields: indexed text fields (analysed, not raw/exact).
tnt_default_fields <- function(idx) {
  info <- idx$schema_info
  info$name[info$kind == "text" & info$indexed]
}
