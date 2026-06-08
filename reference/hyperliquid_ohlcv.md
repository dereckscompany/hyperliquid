# Daily OHLCV Sample Data from Hyperliquid

Historical daily candlestick (OHLCV) data for three major perpetuals
(`"BTC"`, `"ETH"`, `"SOL"`) from Hyperliquid's `candleSnapshot` `/info`
endpoint, stacked into a single long table with a `symbol` column.
Roughly one year of daily candles per coin, included for demonstration
and examples. Produced with
[HyperliquidMarketData](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidMarketData.md)'s
candle method.

## Usage

``` r
hyperliquid_ohlcv
```

## Format

A
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with one row per (symbol, day) and 8 columns:

- `symbol` (Character): Coin symbol, e.g. `"BTC"`.

- `datetime` (POSIXct): Candle open time in UTC.

- `open` (Numeric): Opening price.

- `high` (Numeric): Highest price during the interval.

- `low` (Numeric): Lowest price during the interval.

- `close` (Numeric): Closing price.

- `volume` (Numeric): Trading volume in base currency.

- `trades` (Numeric): Number of trades in the interval.

## Source

Hyperliquid `/info` `candleSnapshot` via
[HyperliquidMarketData](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidMarketData.md)

## Examples

``` r
data(hyperliquid_ohlcv)
head(hyperliquid_ohlcv)
#>    symbol   datetime   open   high    low  close   volume trades
#>    <char>     <POSc>  <num>  <num>  <num>  <num>    <num>  <num>
#> 1:    BTC 2025-06-07 104245 105866 103792 105476 12188.04 150136
#> 2:    BTC 2025-06-08 105476 106431 105024 105659 12537.01 150508
#> 3:    BTC 2025-06-09 105659 111000 105269 110340 38937.19 365657
#> 4:    BTC 2025-06-10 110341 110500 108409 110373 28095.43 318756
#> 5:    BTC 2025-06-11 110373 110480 108069 108668 27049.51 308450
#> 6:    BTC 2025-06-12 108667 108817 105600 105627 39646.83 426870
```
