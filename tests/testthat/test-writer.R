test_that("add then commit makes documents searchable", {
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  out <- tnt_add(idx, data.frame(id = 1:2, body = c("the quick fox", "lazy dogs")))
  expect_s3_class(out, "tnt_index")
  # Not visible before commit.
  expect_equal(tnt_num_docs(idx), 0)
  tnt_commit(idx)
  expect_equal(tnt_num_docs(idx), 2)
})

test_that("add errors when no columns match the schema", {
  sch <- tnt_schema(body = tnt_text())
  idx <- tnt_index(schema = sch)
  expect_error(tnt_add(idx, data.frame(other = 1)), "match schema")
})

test_that("delete by numeric field removes documents", {
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  tnt_add(idx, data.frame(id = 1:3, body = c("a", "b", "c"))) |> tnt_commit()
  tnt_delete(idx, id == 2) |> tnt_commit()
  expect_equal(tnt_num_docs(idx), 2)
})

test_that("delete accepts a vector of values", {
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  tnt_add(idx, data.frame(id = 1:4, body = letters[1:4])) |> tnt_commit()
  tnt_delete(idx, id == c(1, 3)) |> tnt_commit()
  expect_equal(tnt_num_docs(idx), 2)
})

test_that("delete by raw text field works", {
  sch <- tnt_schema(slug = tnt_text(stemmer = "raw"),
                    body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  tnt_add(idx, data.frame(slug = c("a-1", "b-2"), body = c("x", "y"))) |>
    tnt_commit()
  tnt_delete(idx, slug == "a-1") |> tnt_commit()
  expect_equal(tnt_num_docs(idx), 1)
})

test_that("update replaces a document by key", {
  sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
  idx <- tnt_index(schema = sch)
  tnt_add(idx, data.frame(id = 1:2, body = c("old one", "old two"))) |>
    tnt_commit()
  tnt_update(idx, data.frame(id = 1L, body = "new one"), by = id) |>
    tnt_commit()
  expect_equal(tnt_num_docs(idx), 2)
  expect_equal(nrow(tnt_search(idx, "new")), 1)
  expect_equal(nrow(tnt_search(idx, "old")), 1)
})

test_that("delete rejects malformed conditions", {
  sch <- tnt_schema(id = tnt_i64())
  idx <- tnt_index(schema = sch)
  expect_error(tnt_delete(idx, id > 2), "field == value")
})

test_that("non-index objects are rejected", {
  expect_error(tnt_num_docs("nope"), "tnt_index")
  expect_error(tnt_search(42, "x"), "tnt_index")
})
