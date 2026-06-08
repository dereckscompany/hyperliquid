# Convert a Hyperliquid Timestamp to POSIXct

Hyperliquid returns every timestamp as epoch milliseconds. This converts
that form to a POSIXct in UTC.

## Usage

``` r
time_convert_from_hyperliquid(time_value)
```

## Arguments

- time_value:

  (numeric) epoch milliseconds.

## Value

(POSIXct) a vector in UTC.

## Examples

``` r
time_convert_from_hyperliquid(1700000000000)
#> [1] "2023-11-14 22:13:20 UTC"
```
