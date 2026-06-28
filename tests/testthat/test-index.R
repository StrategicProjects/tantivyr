make_news <- function() {
  data.frame(
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
}

test_that("in-memory index can be created from a schema", {
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  expect_s3_class(idx, "tnt_index")
  expect_true(idx$in_memory)
  expect_equal(tnt_num_docs(idx), 0)
})

test_that("in-memory index requires a schema", {
  expect_error(tnt_index(), "requires a")
})

test_that("tnt_index_df infers a schema and indexes rows", {
  idx <- tnt_index_df(make_news(), text = title, filters = year,
                      stemmer = "portuguese")
  expect_equal(tnt_num_docs(idx), 4)
  info <- tnt_index_info(idx)
  expect_s3_class(info, "tbl_df")
  expect_setequal(info$name, c("id", "title", "year"))
  expect_equal(info$kind[info$name == "title"], "text")
  expect_equal(info$tokenizer[info$name == "title"], "tnt_pt")
})

test_that("on-disk index persists and can be reopened", {
  dir <- withr::local_tempdir()
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(dir, schema = sch)
  tnt_add(idx, data.frame(id = 1:2, body = c("hello world", "goodbye world"))) |>
    tnt_commit()
  expect_equal(tnt_num_docs(idx), 2)

  rm(idx)
  gc()
  idx2 <- tnt_index(dir)
  expect_false(idx2$in_memory)
  expect_equal(tnt_num_docs(idx2), 2)
  expect_equal(nrow(tnt_search(idx2, "world")), 2)
})

test_that("opening a missing index without schema errors", {
  dir <- withr::local_tempdir()
  expect_error(tnt_index(file.path(dir, "nope")), "no .*schema")
})

test_that("overwrite recreates the index", {
  dir <- withr::local_tempdir()
  sch <- tnt_schema(body = tnt_text(stemmer = "english"))
  idx <- tnt_index(dir, schema = sch)
  tnt_add(idx, data.frame(body = "first")) |> tnt_commit()
  expect_equal(tnt_num_docs(idx), 1)
  rm(idx); gc()

  idx2 <- tnt_index(dir, schema = sch, overwrite = TRUE)
  expect_equal(tnt_num_docs(idx2), 0)
})
