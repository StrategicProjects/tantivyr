# Number of searchable documents

Number of searchable documents

## Usage

``` r
tnt_num_docs(idx)
```

## Arguments

- idx:

  A `tnt_index`.

## Value

A single numeric value (committed document count).

## Examples

``` r
idx <- tnt_index_df(data.frame(t = "hello world"), text = t)
tnt_num_docs(idx)
#> [1] 1
```
