test_that("pt_news has the documented shape", {
  expect_s3_class(pt_news, "tbl_df")
  expect_named(pt_news, c("id", "section", "date", "title", "body"))
  expect_equal(nrow(pt_news), 36L)
  expect_s3_class(pt_news$date, "Date")
  expect_equal(as.integer(table(pt_news$section)), rep(6L, 6L))
  expect_true(all(validUTF8(pt_news$body)))
})

test_that("pt_news can be indexed and searched with Portuguese stemming", {
  idx <- tnt_index_df(
    pt_news,
    text = c(title, body), filters = c(section, date),
    stemmer = "portuguese", stopwords = TRUE
  )
  expect_equal(tnt_num_docs(idx), 36L)

  hits <- tnt_search(idx, "vacinas", limit = 36)
  expect_gte(nrow(hits), 2L)
  expect_true(all(hits$section == "saúde"))

  expect_equal(tnt_count(idx, "", filter = section == "esporte"), 6L)
})
