
# hyperliquid

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![R-CMD-check](https://github.com/dereckscompany/hyperliquid/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dereckscompany/hyperliquid/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

R API wrapper to the [Hyperliquid](https://hyperliquid.xyz)
decentralised exchange supporting both synchronous and asynchronous
(promise based) operations. Provides R6 classes for market data,
perpetual and spot trading, account management, transfers, and staking.
Every method returns a flat `data.table`. The `/exchange` endpoint is
authenticated by an Ethereum wallet signature, computed in **pure R**
via the companion [`ethsign`](https://github.com/dereckscompany/ethsign)
package (no compiled code) and verified byte-for-byte against the
official Hyperliquid SDKs.

## Disclaimer

This software is provided for educational and research purposes. Trading
cryptocurrency carries substantial risk, and you are solely responsible
for any orders, transfers, or withdrawals placed through this package.
Test against testnet (`testnet = TRUE`) before signing anything on
mainnet.

## Design

- **One method, one `data.table`, no list columns.** Every method
  returns a flat `data.table`; nested API objects are flattened into
  scalar columns, and heterogeneous rows are stacked with a
  discriminator column (`side`, `delta_type`, `status`, …).
- **Sync and async.** Every method works in both modes. `async = TRUE`
  returns a \[promise\]\[promises::promise\]; otherwise results are
  returned directly. There is a single sync/async branch point
  (\[hyperliquid_build_request()\]).
- **snake_case columns.** API `camelCase` fields become `snake_case`
  columns; prices and sizes are returned as numerics.
- **Pure-R Ethereum signing via
  [github.com/dereckscompany/ethsign](https://github.com/dereckscompany/ethsign).**
  secp256k1 ECDSA, Keccak-256, and EIP-712 come from our standalone
  pure-R `ethsign` package; the Hyperliquid-specific msgpack action hash
  lives here. No compiled code, and verified byte-identical to the test
  vectors of the official [Hyperliquid Python
  SDK](https://github.com/hyperliquid-dex/hyperliquid-python-sdk)
  (v0.24.0), which we used as the reference implementation.
- **One host, two paths.** The whole REST API lives behind one host:
  `/info` (public reads) and `/exchange` (signed writes). The network is
  chosen by an explicit `testnet` flag, never by URL sniffing, because
  the network changes the signature itself.

## Installation

``` r
renv::install("dereckscompany/hyperliquid")

# or, if you use remotes instead of renv:
# install.packages("remotes")
# remotes::install_github("dereckscompany/hyperliquid")
```

## Authentication

Public market-data and account reads (the `/info` endpoint) need no
credentials. Signed `/exchange` actions (trading, transfers, staking
writes) are authenticated by an **Ethereum wallet signature**:
Hyperliquid uses no API keys, only your wallet’s secp256k1 private key.

When you call a signed method, the package builds the action, hashes it,
and signs it **locally** with your key, then sends only the resulting
signature in the request body — your private key never leaves your
machine and is never transmitted to Hyperliquid. The low-level signing
primitives (secp256k1 ECDSA, Keccak-256, EIP-712) are factored into a
small standalone package,
[`ethsign`](https://github.com/dereckscompany/ethsign), which this
package builds on; read it if you want the mechanics or to reuse
Ethereum signing elsewhere. (This is not a cryptography library — it
just uses one.)

Store the key as an environment variable in `.Renviron`:

``` bash
HYPERLIQUID_PRIVATE_KEY="0x<64-hex-character-secp256k1-key>"
# Optional: the master account address when the key above is an AGENT (API)
# wallet approved to act on its behalf.
HYPERLIQUID_ACCOUNT_ADDRESS="0x<master-account-address>"
```

`get_api_keys()` reads those variables (and derives the wallet address
from the key):

``` r
box::use(hyperliquid[get_api_keys])

keys <- get_api_keys()
```

The **same key serves both networks**. The network is selected by the
explicit `testnet` flag at construction, not by the URL, because the
network changes the signature itself (the phantom-agent source and the
`hyperliquidChain` tag are part of what is signed):

``` r
# Sign and route against testnet
trading <- HyperliquidTrading$new(testnet = TRUE)
```

## Market Data (no auth)

`HyperliquidMarketData` covers every public `/info` read: perp and spot
metadata, asset contexts, mids, the L2 book, candles, funding, and
trades.

``` r
market <- HyperliquidMarketData$new()

# Perpetual universe metadata
market$get_meta()
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

``` r
# OHLCV candles over a time range (sorted ascending by open time)
market$get_candles(
  "BTC",
  interval = "1h",
  start = lubridate::now("UTC") - lubridate::days(1),
  end = lubridate::now("UTC")
)
```

    #>               datetime  open  high   low close   volume trades
    #>                 <POSc> <num> <num> <num> <num>    <num>  <num>
    #> 1: 2026-06-06 23:00:00 60516 60937 60511 60861 1167.722  15901
    #> 2: 2026-06-07 00:00:00 60860 60974 60714 60750 1293.435  15829
    #>             close_time interval   coin
    #>                 <POSc>   <char> <char>
    #> 1: 2026-06-06 23:59:59       1h    BTC
    #> 2: 2026-06-07 00:59:59       1h    BTC

``` r
# L2 order book: both sides stacked long, with a `side` discriminator
market$get_l2_book("BTC")
```

    #>      side level    px       sz     n
    #>    <char> <int> <num>    <num> <num>
    #> 1:    bid     1 61945  0.03164     3
    #> 2:    bid     2 61944  0.00085     4
    #> 3:    ask     1 61946 13.32523    39
    #> 4:    ask     2 61947  0.06724     6

## Account (no auth)

`HyperliquidAccount` reads the full state and history of any account
from `/info` by its address. No key is required; pass the address you
want to inspect (or let it default to your own wallet when a key is
set).

``` r
account <- HyperliquidAccount$new()
addr <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"
```

``` r
# Open perpetual positions, one row per position
account$get_positions(addr)
```

    #>      coin      szi entry_px position_value unrealized_pnl return_on_equity
    #>    <char>    <num>    <num>          <num>          <num>            <num>
    #> 1:    BTC  0.61148 61699.10     37899.5304       171.7548      0.091049531
    #> 2:    ETH -0.37080  1606.85       595.6902         0.1306      0.004383868
    #>    leverage_type leverage_value liquidation_px margin_used
    #>           <char>          <num>          <num>       <num>
    #> 1:         cross             20             NA  1894.97652
    #> 2:         cross             20        7863060    29.78451

``` r
# Most recent fills
account$get_user_fills(addr)[, .(coin, side, px, sz, dir, closed_pnl, fee)]
```

    #>      coin   side       px    sz        dir closed_pnl   fee
    #>    <char> <char>    <num> <num>     <char>      <num> <num>
    #> 1:   IOTA    buy 0.045274   371  Open Long          0     0
    #> 2: PENDLE   sell 1.245300   253 Open Short          0     0

## Trading (signed)

`HyperliquidTrading` places, modifies, and cancels orders. Every method
signs an `/exchange` action with your wallet key. The calls below run
against the mock; against the live API they would place and cancel real
orders.

``` r
trading <- HyperliquidTrading$new()
```

``` r
# A good-til-cancelled limit bid. Returns one row per resulting status.
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

``` r
# Cancel a resting order by its order id
trading$cancel_order("BTC", oid = 77738308)
```

    #>     status  error
    #>     <char> <char>
    #> 1: success   <NA>

## Transfers (signed)

`HyperliquidTransfers` moves collateral between the spot and perp
wallets, sends to other addresses, withdraws to the bridge, and moves
funds to sub-accounts and vaults.

``` r
transfers <- HyperliquidTransfers$new()
```

``` r
# Move $100 of USDC collateral from the spot wallet into the perp wallet
transfers$usd_class_transfer(100, to_perp = TRUE)
```

    #>    status response_type
    #>    <char>        <char>
    #> 1:     ok       default

## Staking (no auth to read)

`HyperliquidStaking` reads a delegator’s staking state and history, and
(with a key) delegates or undelegates the native token.

``` r
staking <- HyperliquidStaking$new()
staking$get_staking_summary("0x5ac99df645f3414876c816caa18b2d234024b487")
```

    #>    delegated undelegated total_pending_withdrawal n_pending_withdrawals
    #>        <num>       <num>                    <num>                 <int>
    #> 1:  70064.73           0                        0                     0

## Bulk Backfill

`hyperliquid_backfill_klines()` and `hyperliquid_backfill_funding()`
download history for many coins/intervals, writing to a CSV
incrementally so progress survives an interruption (re-running resumes
each series from its last stored row).

``` r
hyperliquid_backfill_klines(
  symbols = c("BTC", "ETH"),
  intervals = c("1d", "1h"),
  from = lubridate::as_datetime("2024-01-01", tz = "UTC"),
  file = "klines.csv"
)
```

A bundled sample dataset, `hyperliquid_ohlcv`, ships daily candles for
`"BTC"`, `"ETH"`, and `"SOL"` for examples:

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

## Asynchronous Use

The package is written around promises for non-blocking, event-loop use.
Pass `async = TRUE` to any class and its methods return a
\[promise\]\[promises::promise\] instead of a `data.table`. Resolve it
with `coro::async()` / `await()` for sequential-looking code, and drive
the event loop with [later](https://r-lib.github.io/later/).

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

## Available Classes

| Class | Purpose | Auth |
|----|----|----|
| `HyperliquidMarketData` | perp/spot meta, asset contexts, mids, L2 book, candles, funding, trades | No |
| `HyperliquidAccount` | positions, margin, spot balances, orders, fills, ledgers, portfolio, fees | No |
| `HyperliquidTrading` | place / modify / cancel orders, market open/close, leverage, margin, approvals | Yes |
| `HyperliquidTransfers` | collateral class transfer, sends, withdrawals, sub-account and vault transfers | Yes |
| `HyperliquidStaking` | delegator summary, delegations, rewards, history, delegate / undelegate | Mixed |

## Author

Dereck Mezquita — [ORCID:
0000-0002-9307-6762](https://orcid.org/0000-0002-9307-6762)

## License

MIT © Dereck Mezquita
