# Delete documents by field value

Marks for deletion every document whose `field` equals the given
value(s), using a `field == value` expression. Deletions take effect
after
[`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md).
For reliable deletion the field should be an exact field: a numeric/date
field, or a text field created with `stemmer = "raw"`.

## Usage

``` r
tnt_delete(idx, condition)
```

## Arguments

- idx:

  A `tnt_index`.

- condition:

  An expression of the form `field == value`. `value` may be a vector,
  deleting all matching documents.

## Value

The `tnt_index`, invisibly.

## See also

[`tnt_update()`](https://strategicprojects.github.io/tantivyr/reference/tnt_update.md)

## Examples

``` r
sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
idx <- tnt_index(schema = sch)
tnt_add(idx, data.frame(id = 1:3, body = c("a", "b", "c"))) |> tnt_commit()
tnt_delete(idx, id == 2) |> tnt_commit()
tnt_num_docs(idx)
#> [1] 2
```
