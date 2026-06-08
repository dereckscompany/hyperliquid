# Getting Started with hyperliquid

This vignette walks through `hyperliquid` in **synchronous** mode:
constructing a client, fetching public market data, reading account
state, and safely signing a `/exchange` order against a mock so nothing
leaves your machine.

## Disclaimer

This software is provided for educational and research purposes. Trading
cryptocurrency carries substantial risk, and you are solely responsible
for any orders, transfers, or withdrawals placed through this package.
Every signed call in this vignette runs against a mock; against the live
API it would move real funds. Test against testnet (`testnet = TRUE`)
before signing anything on mainnet.

## Installation

``` r

# install.packages("remotes")
remotes::install_github("dereckscompany/hyperliquid")
```

## Authentication

Public `/info` reads (market data, account state, staking reads) need no
credentials. Signed `/exchange` actions (trading, transfers, staking
writes) are authenticated by an **Ethereum wallet signature**:
Hyperliquid uses no API keys, only your wallet’s secp256k1 private key.

Store the key as an environment variable in `.Renviron`:

``` bash
HYPERLIQUID_PRIVATE_KEY="0x<64-hex-character-secp256k1-key>"
# Optional: the master account address when the key above is an AGENT (API)
# wallet approved to act on its behalf.
HYPERLIQUID_ACCOUNT_ADDRESS="0x<master-account-address>"
```

[`get_api_keys()`](https://dereckscompany.github.io/hyperliquid/reference/get_api_keys.md)
reads those variables (and derives the wallet address from the key), so
in practice you simply call `HyperliquidTrading$new()` and the
credentials are picked up automatically.

``` r

box::use(
  hyperliquid[
    HyperliquidMarketData, HyperliquidAccount, HyperliquidTrading, get_api_keys
  ]
)

keys <- get_api_keys(
  private_key = "0x<64-hex-character-secp256k1-key>"
)
```

> **One key, one flag for the network.** The same key serves both
> mainnet and testnet. The network is selected by the explicit `testnet`
> argument at construction, never by the URL, because the network
> changes the signature itself (the phantom-agent source and the
> `hyperliquidChain` tag are part of what is signed). Pass
> `testnet = TRUE` to sign and route against testnet.

------------------------------------------------------------------------

## Market Data

`HyperliquidMarketData` covers every public (no auth) `/info` read. It
needs no key.

``` r

market <- HyperliquidMarketData$new()
```

### Perpetual Metadata

The perpetual universe: every listed coin with its size decimals and max
leverage.

``` r

meta <- market$get_meta()
meta[]
```

    #>      name sz_decimals max_leverage margin_table_id only_isolated is_delisted
    #>    <char>       <num>        <num>           <num>        <lgcl>      <lgcl>
    #> 1:    BTC           5           40              56            NA       FALSE
    #> 2:    ETH           4           25              55            NA       FALSE
    #> 3:  MATIC           1           20              20            NA        TRUE
    #> 4:   HOOD           3           10              10          TRUE       FALSE
    #>    margin_mode
    #>         <char>
    #> 1:        <NA>
    #> 2:        <NA>
    #> 3:        <NA>
    #> 4:     noCross

### Mid Prices

`get_all_mids()` returns the mid price for every actively traded coin,
long: one row per coin.

``` r

mids <- market$get_all_mids()
mids[]
```

    #>      coin        mid
    #>    <char>      <num>
    #> 1:    BTC 61958.5000
    #> 2:    ETH  1605.4500
    #> 3:     @1     9.6738

### OHLCV Candles

`get_candles()` returns OHLCV bars for a coin over a time range, sorted
ascending by open time. Valid intervals are in `HYPERLIQUID_INTERVALS`
(`"1m"` … `"1M"`). Time bounds accept a POSIXct or epoch-milliseconds.

``` r

candles <- market$get_candles(
  "BTC",
  interval = "1h",
  start = lubridate::now("UTC") - lubridate::days(1),
  end = lubridate::now("UTC")
)
candles[]
```

    #>               datetime  open  high   low close   volume trades
    #>                 <POSc> <num> <num> <num> <num>    <num>  <num>
    #> 1: 2026-06-06 23:00:00 60516 60937 60511 60861 1167.722  15901
    #> 2: 2026-06-07 00:00:00 60860 60974 60714 60750 1293.435  15829
    #>             close_time interval   coin
    #>                 <POSc>   <char> <char>
    #> 1: 2026-06-06 23:59:59       1h    BTC
    #> 2: 2026-06-07 00:59:59       1h    BTC

### Order Book

`get_l2_book()` returns both sides of the L2 book stacked into one long
table with a `side` discriminator and a 1-indexed `level`.

``` r

book <- market$get_l2_book("BTC")
book[]
```

    #>      side level    px       sz     n
    #>    <char> <int> <num>    <num> <num>
    #> 1:    bid     1 61945  0.03164     3
    #> 2:    bid     2 61944  0.00085     4
    #> 3:    ask     1 61946 13.32523    39
    #> 4:    ask     2 61947  0.06724     6

### Recent Trades

``` r

market$get_recent_trades("BTC")[, .(coin, side, px, sz, time)]
```

    #>      coin   side    px      sz                time
    #>    <char> <char> <num>   <num>              <POSc>
    #> 1:    BTC    buy 61917 0.00032 2026-06-07 05:20:32
    #> 2:    BTC   sell 61916 0.00100 2026-06-07 05:20:31

------------------------------------------------------------------------

## Account State

`HyperliquidAccount` reads the full state and history of any account
from `/info` by its address. The reads are unauthenticated, so pass the
address you want to inspect (when a signing key is set, `address`
defaults to your own wallet).

``` r

account <- HyperliquidAccount$new()
addr <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"
```

### Positions and Margin

`get_positions()` returns one row per open perpetual position; the
cross-margin summary is a sibling method (`get_margin_summary()`)
reading the same payload.

``` r

account$get_positions(addr)[, .(coin, szi, entry_px, unrealized_pnl, leverage_value)]
```

    #>      coin      szi entry_px unrealized_pnl leverage_value
    #>    <char>    <num>    <num>          <num>          <num>
    #> 1:    BTC  0.61148 61699.10       171.7548             20
    #> 2:    ETH -0.37080  1606.85         0.1306             20

``` r

account$get_margin_summary(addr)[, .(account_value, total_ntl_pos, withdrawable)]
```

    #>    account_value total_ntl_pos withdrawable
    #>            <num>         <num>        <num>
    #> 1:       2976575       3239785      2652596

### Fills

``` r

fills <- account$get_user_fills(addr)
fills[, .(coin, side, px, sz, dir, closed_pnl, fee)]
```

    #>      coin   side       px    sz        dir closed_pnl   fee
    #>    <char> <char>    <num> <num>     <char>      <num> <num>
    #> 1:   IOTA    buy 0.045274   371  Open Long          0     0
    #> 2: PENDLE   sell 1.245300   253 Open Short          0     0

------------------------------------------------------------------------

## Trading

`HyperliquidTrading` places, modifies, and cancels orders. Every method
signs an `/exchange` action with your wallet key. The calls below run
against the mock; against the live API they would place and cancel real
orders.

``` r

trading <- HyperliquidTrading$new()
```

### Place an Order

An order’s `order_type` is either a limit
(`list(limit = list(tif = "Gtc"|"Ioc"|"Alo"))`) or a trigger order. The
result is one row per resulting status (`resting`, `filled`, or
`error`):

``` r

order <- trading$place_order(
  "BTC",
  is_buy = TRUE,
  sz = 0.001,
  limit_px = 50000,
  order_type = list(limit = list(tif = "Gtc"))
)
order[]
```

    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

### Cancel an Order

`cancel_order()` cancels one resting order by its order id, returning
one row per cancel:

``` r

trading$cancel_order("BTC", oid = order$oid[order$status == "resting"][1])
```

    #>     status  error
    #>     <char> <char>
    #> 1: success   <NA>

------------------------------------------------------------------------

## Staking

`HyperliquidStaking` reads a delegator’s staking state from `/info` (no
key), and delegates / undelegates the native token with a key.

``` r

staking <- HyperliquidStaking$new()
staking$get_staking_summary("0x5ac99df645f3414876c816caa18b2d234024b487")
```

    #>    delegated undelegated total_pending_withdrawal n_pending_withdrawals
    #>        <num>       <num>                    <num>                 <int>
    #> 1:  70064.73           0                        0                     0

------------------------------------------------------------------------

## The Data-Shape Policy

Every method returns a single flat `data.table` with **no list
columns**:

- Nested API objects are flattened into scalar `snake_case` columns
  (e.g. a position’s `leverage` becomes `leverage_type` and
  `leverage_value`).
- Endpoints that bundle two things are split into sibling methods over
  the same payload (`get_positions()` / `get_margin_summary()`).
- Heterogeneous rows are stacked with a discriminator column: the L2
  book’s `side`, an order action’s `status`, a ledger’s `delta_type`.
- Prices, sizes, and amounts are parsed to numeric; timestamps are
  `POSIXct` in UTC (via `lubridate`).

This means the result of any call drops straight into `data.table`
joins, `rbindlist()`, or a database write with no further unnesting.

------------------------------------------------------------------------

## Bulk Backfill and Bundled Data

For historical collection,
[`hyperliquid_backfill_klines()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_klines.md)
downloads candles for many coins and intervals to a CSV, appending
incrementally so progress survives an interruption (re-running resumes
each series from its last stored row). It writes a file, so it is shown
but not executed here:

``` r

hyperliquid_backfill_klines(
  symbols = c("BTC", "ETH"),
  intervals = c("1d", "1h"),
  from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
  file = "klines.csv"
)
```

A bundled sample dataset, `hyperliquid_ohlcv`, ships daily candles for
`"BTC"`, `"ETH"`, and `"SOL"`:

``` r

head(hyperliquid_ohlcv)
```

    #>    symbol   datetime   open   high    low  close   volume trades
    #>    <char>     <POSc>  <num>  <num>  <num>  <num>    <num>  <num>
    #> 1:    BTC 2025-06-07 104245 105866 103792 105476 12188.04 150136
    #> 2:    BTC 2025-06-08 105476 106431 105024 105659 12537.01 150508
    #> 3:    BTC 2025-06-09 105659 111000 105269 110340 38937.19 365657
    #> 4:    BTC 2025-06-10 110341 110500 108409 110373 28095.43 318756
    #> 5:    BTC 2025-06-11 110373 110480 108069 108668 27049.51 308450
    #> 6:    BTC 2025-06-12 108667 108817 105600 105627 39646.83 426870

------------------------------------------------------------------------

## Asynchronous Use

Every class works in async mode. Pass `async = TRUE` and each method
returns a [promise](https://rstudio.github.io/promises/) instead of a
`data.table`. The recommended idiom is
[`coro::async()`](https://coro.r-lib.org/reference/async.html) /
`await()` for sequential-looking code, driving the event loop with
[later](https://r-lib.github.io/later/):

``` r

market_async <- HyperliquidMarketData$new(async = TRUE)

main <- coro$async(function() {
  mids <- await(market_async$get_all_mids())
  book <- await(market_async$get_l2_book("BTC"))

  print(mids)
  print(book)
  return(invisible(NULL))
})

main()

# Drain the event loop until every promise has resolved.
while (!later$loop_empty()) {
  later$run_now()
}
```

    #>      coin        mid
    #>    <char>      <num>
    #> 1:    BTC 61958.5000
    #> 2:    ETH  1605.4500
    #> 3:     @1     9.6738
    #>      side level    px       sz     n
    #>    <char> <int> <num>    <num> <num>
    #> 1:    bid     1 61945  0.03164     3
    #> 2:    bid     2 61944  0.00085     4
    #> 3:    ask     1 61946 13.32523    39
    #> 4:    ask     2 61947  0.06724     6

------------------------------------------------------------------------

## Next Steps

- Browse the [pkgdown
  site](https://dereckscompany.github.io/hyperliquid/) for full method
  documentation.
- For bulk historical data collection, see
  [`?hyperliquid_backfill_klines`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_klines.md)
  and
  [`?hyperliquid_backfill_funding`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_funding.md).
