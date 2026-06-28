# Index schema as a tibble

Index schema as a tibble

## Usage

``` r
tnt_index_info(idx)
```

## Arguments

- idx:

  A `tnt_index`.

## Value

A tibble with one row per field: `name`, `kind`, `stored`, `indexed`,
`tokenizer`.

## Examples

``` r
idx <- tnt_index_df(data.frame(t = "hi"), text = t)
tnt_index_info(idx)
#> # A tibble: 1 × 5
#>   name  kind  stored indexed tokenizer
#>   <chr> <chr> <lgl>  <lgl>   <chr>    
#> 1 t     text  TRUE   TRUE    default  
```
