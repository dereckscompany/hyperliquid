# Backfill Hyperliquid Candle (OHLCV) Data to CSV

Downloads historical OHLCV candles for one or more coins and intervals,
writing results incrementally to a CSV file. Supports resuming a
partially completed backfill by reading the existing file and continuing
each `(symbol, interval)` series from its last stored candle.

## Usage

``` r
hyperliquid_backfill_klines(
  symbols,
  intervals = "1d",
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file = "hyperliquid_klines.csv",
  testnet = FALSE,
  sleep = 0.3,
  verbose = TRUE
)
```

## Arguments

- symbols:

  (character) canonical coin symbols (e.g. `c("BTC", "ETH")`). Must not
  be NULL or empty.

- intervals:

  (character in HYPERLIQUID_INTERVALS) candle intervals (e.g.
  `c("1d", "1h")`). Each must be one of
  [HYPERLIQUID_INTERVALS](https://dereckscompany.github.io/hyperliquid/reference/HYPERLIQUID_INTERVALS.md).
  Default `"1d"`.

- from:

  (POSIXct \| numeric) start of the backfill window. Defaults to one
  year ago.

- to:

  (POSIXct \| numeric) end of the window. Defaults to the current time.

- file:

  (scalar\<character\>) path to the output CSV. Data is appended
  incrementally.

- testnet:

  (scalar\<logical\>) target testnet instead of mainnet. Default
  `FALSE`.

- sleep:

  (scalar\<numeric in \[0, Inf\[\>) seconds to sleep between each
  `(symbol, interval)` combination to respect rate limits. Default
  `0.3`.

- verbose:

  (scalar\<logical\>) if `TRUE`, prints progress via
  [`rlang::inform()`](https://rlang.r-lib.org/reference/abort.html).

## Value

(scalar\<character\>) the file path (invisibly). Output columns:
`symbol`, `interval`, `datetime`, `open`, `high`, `low`, `close`,
`volume`, `trades`.

Per-combo failures are surfaced as warnings during the run (one
[`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html) per
failed `(symbol, interval)` pair), followed by a final summary warning
if any failed. No failure data is hidden on the return value.

## Details

Hyperliquid's `candleSnapshot` returns only the ~5000 most recent
candles per interval, so deep intraday history is not available over
REST; coarse intervals (`"1d"`, `"1h"`) reach back furthest. Within that
cap `hyperliquid_fetch_klines()` segments the range automatically.

## Examples

``` r
if (FALSE) { # \dontrun{
hyperliquid_backfill_klines(
  symbols = c("BTC", "ETH"),
  intervals = c("1d", "1h"),
  from = lubridate::as_datetime("2024-01-01"),
  file = "hyperliquid_klines.csv"
)
} # }
```
