# Index creation / opening and introspection.

new_tnt_index <- function(ptr, path, in_memory) {
  info <- as_tibble(tnt_schema_info_(ptr))
  structure(
    list(ptr = ptr, path = path, in_memory = in_memory, schema_info = info),
    class = "tnt_index"
  )
}

# A directory holds a tantivy index if it contains a meta.json file.
tnt_dir_has_index <- function(path) {
  file.exists(file.path(path, "meta.json"))
}

#' Create or open a search index
#'
#' Opens an existing on-disk index, or creates a new one from a [tnt_schema()].
#' With `path = NULL` an in-memory index is created (useful for tests and
#' transient work).
#'
#' @param path Directory for an on-disk index, or `NULL` for an in-memory index.
#'   If the directory already contains an index it is opened (unless
#'   `overwrite = TRUE`).
#' @param schema A [tnt_schema()]. Required when creating a new index; ignored
#'   when opening an existing one.
#' @param overwrite Logical. If `TRUE`, an existing index at `path` is deleted
#'   and recreated from `schema`. Defaults to `FALSE`.
#' @param heap_mb Indexing memory budget in MB (minimum 15). Defaults to 128.
#'
#' @return A `tnt_index` object.
#' @seealso [tnt_index_df()], [tnt_add()], [tnt_search()]
#' @examples
#' sch <- tnt_schema(
#'   id    = tnt_i64(),
#'   title = tnt_text(stemmer = "english"),
#'   body  = tnt_text(stemmer = "english")
#' )
#' idx <- tnt_index(schema = sch) # in-memory
#' idx
#' @export
tnt_index <- function(path = NULL, schema = NULL, overwrite = FALSE,
                      heap_mb = 128) {
  if (!is.null(schema) && !inherits(schema, "tnt_schema")) {
    cli::cli_abort("{.arg schema} must be created with {.fn tnt_schema}.")
  }

  # In-memory index.
  if (is.null(path)) {
    if (is.null(schema)) {
      cli::cli_abort("An in-memory index requires a {.arg schema}.")
    }
    v <- tnt_schema_vectors(schema)
    ptr <- tnt_create_in_ram(
      v$names, v$kinds, v$stored, v$indexed, v$fast, v$tokenizers, heap_mb
    )
    return(new_tnt_index(ptr, path = NULL, in_memory = TRUE))
  }

  path <- path.expand(path)
  exists_index <- dir.exists(path) && tnt_dir_has_index(path)

  if (exists_index && !overwrite) {
    if (!is.null(schema)) {
      cli::cli_warn("Opening an existing index; {.arg schema} is ignored.")
    }
    ptr <- tnt_open_in_dir(path, heap_mb)
    return(new_tnt_index(ptr, path = path, in_memory = FALSE))
  }

  if (is.null(schema)) {
    cli::cli_abort(c(
      "No index found at {.path {path}} and no {.arg schema} supplied.",
      i = "Pass a {.fn tnt_schema} to create a new index."
    ))
  }
  if (dir.exists(path) && overwrite) {
    unlink(path, recursive = TRUE, force = TRUE)
  }
  v <- tnt_schema_vectors(schema)
  ptr <- tnt_create_in_dir(
    path, v$names, v$kinds, v$stored, v$indexed, v$fast, v$tokenizers, heap_mb
  )
  new_tnt_index(ptr, path = path, in_memory = FALSE)
}

#' Index a data frame in one call
#'
#' A convenience wrapper that infers a schema from `data`, creates an index,
#' adds every row and commits. Text columns are made searchable; filter columns
#' are indexed for filtering and ordering; all other columns are stored so they
#' are returned by [tnt_search()].
#'
#' @param data A data frame.
#' @param text <[`tidy-select`][tidyselect::language]> Columns to index as
#'   full-text fields.
#' @param filters <[`tidy-select`][tidyselect::language]> Columns to index for
#'   filtering/ordering (their type is inferred). Optional.
#' @param stemmer,stopwords Stemming and stop-word options applied to all `text`
#'   columns. See [tnt_text()].
#' @param stored Logical. Store text columns so they are returned by searches.
#' @param path,overwrite,heap_mb Passed to [tnt_index()].
#'
#' @return A committed `tnt_index` object.
#' @seealso [tnt_index()], [tnt_search()]
#' @examples
#' df <- data.frame(
#'   id = 1:2,
#'   title = c("Orçamento público aprovado", "Reforma tributária avança"),
#'   year = c(2023L, 2024L)
#' )
#' idx <- tnt_index_df(df, text = title, filters = year, stemmer = "portuguese")
#' tnt_search(idx, "orcamento")
#' @export
tnt_index_df <- function(data, text, filters = NULL, stemmer = "none",
                         stopwords = FALSE, stored = TRUE, path = NULL,
                         overwrite = FALSE, heap_mb = 128) {
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  text_cols <- names(tidyselect::eval_select(rlang::enquo(text), data))
  filter_cols <- names(tidyselect::eval_select(rlang::enquo(filters), data))
  if (length(text_cols) == 0L) {
    cli::cli_abort("Select at least one column in {.arg text}.")
  }
  filter_cols <- setdiff(filter_cols, text_cols)
  other_cols <- setdiff(names(data), c(text_cols, filter_cols))

  fields <- list()
  for (nm in text_cols) {
    fields[[nm]] <- tnt_text(stored = stored, stemmer = stemmer, stopwords = stopwords)
  }
  for (nm in filter_cols) {
    kind <- tnt_infer_kind(data[[nm]])
    fields[[nm]] <- if (kind == "text") {
      tnt_text(stored = TRUE, stemmer = "raw")
    } else {
      new_tnt_field(kind, stored = TRUE, indexed = TRUE, fast = TRUE)
    }
  }
  for (nm in other_cols) {
    kind <- tnt_infer_kind(data[[nm]])
    fields[[nm]] <- if (kind == "text") {
      tnt_text(stored = TRUE, indexed = FALSE)
    } else {
      new_tnt_field(kind, stored = TRUE, indexed = FALSE, fast = FALSE)
    }
  }
  schema <- do.call(tnt_schema, fields[names(data)])

  idx <- tnt_index(path = path, schema = schema, overwrite = overwrite, heap_mb = heap_mb)
  idx <- tnt_add(idx, data)
  tnt_commit(idx)
}

#' Number of searchable documents
#'
#' @param idx A `tnt_index`.
#' @return A single numeric value (committed document count).
#' @examples
#' idx <- tnt_index_df(data.frame(t = "hello world"), text = t)
#' tnt_num_docs(idx)
#' @export
tnt_num_docs <- function(idx) {
  tnt_check_index(idx)
  tnt_num_docs_(idx$ptr)
}

#' Index schema as a tibble
#'
#' @param idx A `tnt_index`.
#' @return A tibble with one row per field: `name`, `kind`, `stored`,
#'   `indexed`, `tokenizer`.
#' @examples
#' idx <- tnt_index_df(data.frame(t = "hi"), text = t)
#' tnt_index_info(idx)
#' @export
tnt_index_info <- function(idx) {
  tnt_check_index(idx)
  idx$schema_info
}

#' @export
print.tnt_index <- function(x, ...) {
  loc <- if (x$in_memory) "in-memory" else paste0("on-disk: ", x$path)
  n <- tryCatch(tnt_num_docs_(x$ptr), error = function(e) NA_real_)
  cli::cli_h3("<tnt_index> ({loc})")
  cli::cli_text("{.strong {n}} document{?s} \u00b7 {nrow(x$schema_info)} field{?s}")
  info <- x$schema_info
  for (i in seq_len(nrow(info))) {
    tok <- if (nzchar(info$tokenizer[i])) paste0(" [", info$tokenizer[i], "]") else ""
    cli::cli_li("{.field {info$name[i]}}: {info$kind[i]}{tok}")
  }
  invisible(x)
}
