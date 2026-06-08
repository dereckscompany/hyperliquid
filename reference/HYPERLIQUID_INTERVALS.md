# Hyperliquid Candle Intervals

The 14 candle intervals accepted by Hyperliquid's `candleSnapshot`
endpoint, in ascending order. Unlike some other venues there is no `1s`
or `6h` interval.

## Usage

``` r
HYPERLIQUID_INTERVALS
```

## Format

A character vector of 14 interval codes.

## Examples

``` r
HYPERLIQUID_INTERVALS
#>  [1] "1m"  "3m"  "5m"  "15m" "30m" "1h"  "2h"  "4h"  "8h"  "12h" "1d"  "3d" 
#> [13] "1w"  "1M" 
```
