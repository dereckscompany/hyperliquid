# Convert a POSIXct to a Hyperliquid Timestamp

Formats a POSIXct as the timestamp form Hyperliquid expects:
whole-number epoch milliseconds.

## Usage

``` r
time_convert_to_hyperliquid(datetime)
```

## Arguments

- datetime:

  (POSIXct) object(s) to convert.

## Value

(numeric) whole-number epoch milliseconds.

## Examples

``` r
dt <- lubridate::as_datetime("2023-11-14 22:13:20", tz = "UTC")
time_convert_to_hyperliquid(dt)
#> [1] 1.7e+12
```
