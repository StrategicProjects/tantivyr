build_idx <- function() {
  df <- data.frame(
    id = 1:4,
    title = c(
      "Orçamento público aprovado pelo congresso",
      "Reforma tributária avança no senado",
      "Nova lei de licitações entra em vigor",
      "Congresso debate orçamentos municipais"
    ),
    year = c(2022L, 2023L, 2024L, 2024L),
    stringsAsFactors = FALSE
  )
  tnt_index_df(df, text = title, filters = year, stemmer = "portuguese",
               stopwords = TRUE)
}

test_that("BM25 search returns a scored tibble", {
  idx <- build_idx()
  res <- tnt_search(idx, "congresso")
  expect_s3_class(res, "tbl_df")
  expect_true("score" %in% names(res))
  expect_true(all(c("id", "title", "year") %in% names(res)))
  expect_equal(nrow(res), 2)
  expect_true(is.numeric(res$score))
})

test_that("Portuguese stemming matches inflected forms", {
  idx <- build_idx()
  # 'orçamento' should also match 'orçamentos'
  res <- tnt_search(idx, "orçamento")
  expect_equal(nrow(res), 2)
})

test_that("empty query matches everything", {
  idx <- build_idx()
  expect_equal(nrow(tnt_search(idx, "", limit = 100)), 4)
})

test_that("limit caps the number of results", {
  idx <- build_idx()
  expect_equal(nrow(tnt_search(idx, "", limit = 2)), 2)
})

test_that("numeric filters work as expressions and strings", {
  idx <- build_idx()
  expect_equal(nrow(tnt_search(idx, "", filter = year >= 2024)), 2)
  expect_equal(nrow(tnt_search(idx, "", filter = year == 2022)), 1)
  expect_equal(nrow(tnt_search(idx, "", filter = "year:[2023 TO *]")), 3)
  expect_equal(nrow(tnt_search(idx, "", filter = year %in% c(2022, 2023))), 2)
})

test_that("combined filters with & and | work", {
  idx <- build_idx()
  res <- tnt_search(idx, "", filter = year >= 2023 & year <= 2024, limit = 100)
  expect_equal(nrow(res), 3)
})

test_that("highlight adds a snippet column with <b> tags", {
  idx <- build_idx()
  res <- tnt_search(idx, "congresso", highlight = title)
  expect_true("title_snippet" %in% names(res))
  expect_true(any(grepl("<b>", res$title_snippet, fixed = TRUE)))
})

test_that("order_by uses a fast field and sets score to NA", {
  idx <- build_idx()
  res <- tnt_search(idx, "", order_by = year, desc = TRUE, limit = 100)
  expect_true(all(is.na(res$score)))
  expect_true(all(diff(res$year) <= 0))
})

test_that("tnt_count counts all matches regardless of limit", {
  idx <- build_idx()
  expect_equal(tnt_count(idx, "congresso"), 2)
  expect_equal(tnt_count(idx, "", filter = year >= 2024), 2)
})

test_that("date filters work on Date fields", {
  sch <- tnt_schema(id = tnt_i64(fast = TRUE), ts = tnt_date(fast = TRUE))
  idx <- tnt_index(schema = sch)
  tnt_add(idx, data.frame(id = 1:3,
                          ts = as.Date(c("2020-01-01", "2021-06-15", "2023-03-20")))) |>
    tnt_commit()
  res <- tnt_search(idx, "", filter = ts >= as.Date("2021-06-01"))
  expect_equal(nrow(res), 2)
  expect_s3_class(res$ts, "POSIXct")
})
