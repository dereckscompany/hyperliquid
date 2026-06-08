# Backfill Hyperliquid Funding-Rate History to CSV

Downloads the funding-rate history for one or more coins, writing
results incrementally to a CSV file. Unlike candles, Hyperliquid's
`fundingHistory` is complete and free, so this walks the full window in
`page_limit`-sized time steps. Supports resuming by reading the existing
file and continuing each coin from its last stored funding record.

## Usage

``` r
hyperliquid_backfill_funding(
  symbols,
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file = "hyperliquid_funding.csv",
  testnet = FALSE,
  sleep = 0.3,
  verbose = TRUE
)
```

## Arguments

- symbols:

  (character) canonical coin symbols (e.g. `c("BTC", "ETH")`). Must not
  be NULL or empty.

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

  (scalar\<numeric in \[0, Inf\[\>) seconds to sleep between pages and
  between coins to respect rate limits. Default `0.3`.

- verbose:

  (scalar\<logical\>) if `TRUE`, prints progress via
  [`rlang::inform()`](https://rlang.r-lib.org/reference/abort.html).

## Value

(scalar\<character\>) the file path (invisibly). Output columns: `coin`,
`funding_rate`, `premium`, `time`.

Per-coin failures are surfaced as warnings during the run, followed by a
final summary warning if any failed. No failure data is hidden on the
return value.

## Examples

``` r
if (FALSE) { # \dontrun{
hyperliquid_backfill_funding(
  symbols = c("BTC", "ETH"),
  from = lubridate::as_datetime("2024-01-01"),
  file = "hyperliquid_funding.csv"
)
} # }
```
