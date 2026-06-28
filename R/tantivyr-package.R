#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang abort warn inform enquo quo_is_null quo_get_expr := .data
#' @importFrom tibble as_tibble tibble
#' @importFrom cli cli_abort cli_warn cli_inform
## usethis namespace: end
NULL

# Quiet R CMD check notes about tidyselect data-masking pronouns.
utils::globalVariables(c("."))
