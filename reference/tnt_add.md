# Add documents to an index

Adds the rows of `data` as documents. Only columns whose names match a
schema field are used; other columns are ignored. Additions become
searchable after
[`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md).

## Usage

``` r
tnt_add(idx, data)
```

## Arguments

- idx:

  A `tnt_index`.

- data:

  A data frame whose columns map to schema fields by name.

## Value

The `tnt_index`, invisibly (so calls can be piped).

## See also

[`tnt_commit()`](https://strategicprojects.github.io/tantivyr/reference/tnt_commit.md),
[`tnt_update()`](https://strategicprojects.github.io/tantivyr/reference/tnt_update.md)

## Examples

``` r
sch <- tnt_schema(id = tnt_i64(), body = tnt_text(stemmer = "english"))
idx <- tnt_index(schema = sch)
df <- data.frame(id = 1:2, body = c("the quick fox", "lazy dogs sleep"))
idx |> tnt_add(df) |> tnt_commit()
tnt_num_docs(idx)
#> [1] 2
```
