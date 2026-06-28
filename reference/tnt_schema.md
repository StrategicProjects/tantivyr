# Create a search schema

Combine named
[tnt_field](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md)
definitions into a schema that can be passed to
[`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md).

## Usage

``` r
tnt_schema(...)
```

## Arguments

- ...:

  Named field definitions, e.g. `title = tnt_text()`.

## Value

A `tnt_schema` object (a named list of `tnt_field`s).

## See also

[tnt_field](https://strategicprojects.github.io/tantivyr/reference/tnt_field.md),
[`tnt_index()`](https://strategicprojects.github.io/tantivyr/reference/tnt_index.md)

## Examples

``` r
tnt_schema(
  id    = tnt_i64(),
  title = tnt_text(stemmer = "english"),
  body  = tnt_text(stemmer = "english")
)
#> 
#> ── tantivyr schema (3 fields) 
#> • id: i64
#> • title: text [tnt_en]
#> • body: text [tnt_en]
```
