test_that("field constructors carry their options", {
  f <- tnt_text(stored = TRUE, stemmer = "portuguese", stopwords = TRUE)
  expect_s3_class(f, "tnt_field")
  expect_equal(f$kind, "text")
  expect_true(f$stored)
  expect_equal(f$stemmer, "portuguese")
  expect_true(f$stopwords)

  expect_equal(tnt_i64()$kind, "i64")
  expect_equal(tnt_date()$kind, "date")
  expect_equal(tnt_bool()$kind, "bool")
})

test_that("tnt_schema validates its arguments", {
  expect_error(tnt_schema(), "at least one field")
  expect_error(tnt_schema(tnt_text()), "must be named")
  expect_error(tnt_schema(a = tnt_text(), a = tnt_i64()), "unique")
  expect_error(tnt_schema(a = 1), "must be a")

  sch <- tnt_schema(a = tnt_text(), b = tnt_i64())
  expect_s3_class(sch, "tnt_schema")
  expect_named(sch, c("a", "b"))
})

test_that("tokenizer names mirror the Rust decoder", {
  expect_equal(tnt_tokenizer_name("none"), "default")
  expect_equal(tnt_tokenizer_name("raw"), "raw")
  expect_equal(tnt_tokenizer_name("portuguese"), "tnt_pt")
  expect_equal(tnt_tokenizer_name("portuguese", stopwords = TRUE), "tnt_pt_stop")
  expect_equal(tnt_tokenizer_name("en", stopwords = TRUE), "tnt_en_stop")
})

test_that("stopwords for unsupported languages warn and fall back", {
  expect_warning(
    nm <- tnt_tokenizer_name("french", stopwords = TRUE),
    "not bundled"
  )
  expect_equal(nm, "tnt_fr")
})

test_that("tnt_stemmers lists the supported languages", {
  st <- tnt_stemmers()
  expect_true(all(c("none", "raw", "portuguese", "english") %in% st))
})
