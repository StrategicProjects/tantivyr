# Writing: add, commit, delete, update.

# Convert a value to epoch seconds for a date field.
tnt_to_epoch <- function(value) {
  if (inherits(value, "Date")) {
    as.numeric(value) * 86400
  } else if (inherits(value, "POSIXct")) {
    as.numeric(value)
  } else if (is.character(value)) {
    as.numeric(as.POSIXct(value, tz = "UTC"))
  } else {
    as.numeric(value)
  }
}

#' Add documents to an index
#'
#' Adds the rows of `data` as documents. Only columns whose names match a schema
#' field are used; other columns are ignored. Additions become searchable after
#' [tnt_commit()].
#'
#' @param idx A `tnt_index`.
#' @param data A data frame whose columns map to schema fields by name.
#'
#' @return The `tnt_index`, invisibly (so calls can be piped).
#' @seealso [tnt_commit()], [tnt_update()]
#' @examples
#' sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
#' idx <- tnt_index(schema = sch)
#' df <- data.frame(id = 1:2, body = c("the quick fox", "lazy dogs sleep"))
#' idx |> tnt_add(df) |> tnt_commit()
#' tnt_num_docs(idx)
#' @export
tnt_add <- function(idx, data) {
  tnt_check_index(idx)
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  info <- idx$schema_info
  present <- intersect(info$name, names(data))
  if (length(present) == 0L) {
    cli::cli_abort(c(
      "None of the columns in {.arg data} match schema fields.",
      i = "Schema fields: {.field {info$name}}."
    ))
  }
  cols <- lapply(present, function(nm) {
    kind <- info$kind[match(nm, info$name)]
    tnt_coerce_column(data[[nm]], kind)
  })
  tnt_add_(idx$ptr, present, cols)
  invisible(idx)
}

#' Commit pending changes
#'
#' Flushes buffered additions and deletions to the index and refreshes the
#' reader so they become visible to [tnt_search()].
#'
#' @param idx A `tnt_index`.
#' @return The `tnt_index`, invisibly.
#' @examples
#' sch <- tnt_schema(body = tnt_text(stemmer = "english"))
#' idx <- tnt_index(schema = sch)
#' tnt_add(idx, data.frame(body = "hello")) |> tnt_commit()
#' @export
tnt_commit <- function(idx) {
  tnt_check_index(idx)
  tnt_commit_(idx$ptr)
  invisible(idx)
}

# Delete documents matching field == value(s).
tnt_delete_one <- function(idx, field, values, info) {
  kind <- info$kind[match(field, info$name)]
  if (is.na(kind)) {
    cli::cli_abort("Unknown field {.field {field}}.")
  }
  if (kind == "text" || kind == "json") {
    for (v in as.character(values)) {
      tnt_delete_text_(idx$ptr, field, v)
    }
  } else if (kind == "date") {
    for (v in tnt_to_epoch(values)) {
      tnt_delete_numeric_(idx$ptr, field, v)
    }
  } else {
    for (v in as.numeric(values)) {
      tnt_delete_numeric_(idx$ptr, field, v)
    }
  }
}

#' Delete documents by field value
#'
#' Marks for deletion every document whose `field` equals the given value(s),
#' using a `field == value` expression. Deletions take effect after
#' [tnt_commit()]. For reliable deletion the field should be an exact field: a
#' numeric/date field, or a text field created with `stemmer = "raw"`.
#'
#' @param idx A `tnt_index`.
#' @param condition An expression of the form `field == value`. `value` may be a
#'   vector, deleting all matching documents.
#'
#' @return The `tnt_index`, invisibly.
#' @seealso [tnt_update()]
#' @examples
#' sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
#' idx <- tnt_index(schema = sch)
#' tnt_add(idx, data.frame(id = 1:3, body = c("a", "b", "c"))) |> tnt_commit()
#' tnt_delete(idx, id == 2) |> tnt_commit()
#' tnt_num_docs(idx)
#' @export
tnt_delete <- function(idx, condition) {
  tnt_check_index(idx)
  expr <- rlang::enexpr(condition)
  if (!rlang::is_call(expr, "==") || length(expr) != 3L) {
    cli::cli_abort("{.arg condition} must look like {.code field == value}.")
  }
  field <- rlang::as_name(expr[[2]])
  values <- rlang::eval_tidy(expr[[3]], env = rlang::caller_env())
  tnt_delete_one(idx, field, values, idx$schema_info)
  invisible(idx)
}

#' Update documents (delete then re-add)
#'
#' Replaces documents by deleting any existing document that shares a key value
#' (the `by` field) with a row of `data`, then adding the rows of `data`. The
#' `by` field must be an exact field (numeric/date, or text with
#' `stemmer = "raw"`). Call [tnt_commit()] afterwards.
#'
#' @param idx A `tnt_index`.
#' @param data A data frame of replacement documents.
#' @param by <[`tidy-select`][tidyselect::language]> A single key column present
#'   in both `data` and the schema.
#'
#' @return The `tnt_index`, invisibly.
#' @seealso [tnt_add()], [tnt_delete()]
#' @examples
#' sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
#' idx <- tnt_index(schema = sch)
#' tnt_add(idx, data.frame(id = 1:2, body = c("old one", "old two"))) |>
#'   tnt_commit()
#' tnt_update(idx, data.frame(id = 1L, body = "new one"), by = id) |>
#'   tnt_commit()
#' @export
tnt_update <- function(idx, data, by) {
  tnt_check_index(idx)
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  by_col <- names(tidyselect::eval_select(rlang::enquo(by), data))
  if (length(by_col) != 1L) {
    cli::cli_abort("{.arg by} must select exactly one column.")
  }
  tnt_delete_one(idx, by_col, data[[by_col]], idx$schema_info)
  tnt_add(idx, data)
  invisible(idx)
}
