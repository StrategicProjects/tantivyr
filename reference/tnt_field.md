# Define schema fields

These constructors describe a single field in a
[`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md).
Each returns a lightweight `tnt_field` object.

## Usage

``` r
tnt_text(
  stored = TRUE,
  indexed = TRUE,
  fast = FALSE,
  stemmer = "none",
  stopwords = FALSE
)

tnt_i64(stored = TRUE, indexed = TRUE, fast = FALSE)

tnt_u64(stored = TRUE, indexed = TRUE, fast = FALSE)

tnt_f64(stored = TRUE, indexed = TRUE, fast = FALSE)

tnt_bool(stored = TRUE, indexed = TRUE, fast = FALSE)

tnt_date(stored = TRUE, indexed = TRUE, fast = FALSE)

tnt_json(stored = TRUE, indexed = TRUE)
```

## Arguments

- stored:

  Logical. Keep the original value so it is returned by
  [`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md).
  Defaults to `TRUE`.

- indexed:

  Logical. Index the field so it can be searched or filtered. Defaults
  to `TRUE`.

- fast:

  Logical. Build a columnar "fast field" enabling fast filtering and
  ordering (required by `order_by` in
  [`tnt_search()`](https://strategicprojects.github.io/tantivyr/reference/tnt_search.md)).
  Defaults to `FALSE`, except `tnt_text(fast = ...)` which has no fast
  field by default.

- stemmer:

  Stemming/tokenization for a text field. One of `"none"` (plain
  tokenization, lower-cased), `"raw"` (exact, untokenized — ideal for
  ids and exact filters), or a Snowball language such as `"portuguese"`
  or `"english"`. See
  [`tnt_stemmers()`](https://strategicprojects.github.io/tantivyr/reference/tnt_stemmers.md).

- stopwords:

  Logical. Remove stop words for the chosen language. Bundled for
  Portuguese and English. Defaults to `FALSE`.

## Value

A `tnt_field` object.

## See also

[`tnt_schema()`](https://strategicprojects.github.io/tantivyr/reference/tnt_schema.md)

## Examples

``` r
tnt_schema(
  id    = tnt_i64(),
  title = tnt_text(stemmer = "portuguese", stopwords = TRUE),
  body  = tnt_text(stemmer = "portuguese"),
  date  = tnt_date()
)
#> 
#> ── tantivyr schema (4 fields) 
#> • id: i64
#> • title: text [tnt_pt_stop]
#> • body: text [tnt_pt]
#> • date: date
```
