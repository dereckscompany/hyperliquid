# HyperliquidMarketData: Public Market Data Retrieval

HyperliquidMarketData: Public Market Data Retrieval

HyperliquidMarketData: Public Market Data Retrieval

## Details

### Purpose

Retrieves all public market data from Hyperliquid's `/info` endpoint:
perp and spot metadata, asset contexts
(mark/mid/oracle/funding/open-interest), all mids, the L2 order book,
OHLCV candles, funding history and predicted fundings, builder-deployed
perp dexes, recent trades, and exchange status. Every method is
unauthenticated and needs no wallet key.

Inherits from
[HyperliquidBase](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction; in async mode each
returns a
[promises::promise](https://rstudio.github.io/promises/reference/promise.html)
resolving to the same
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

Methods take a `coin` as its canonical Hyperliquid symbol (`"BTC"`,
`"@107"`, `"PURR/USDC"`). To resolve a friendly name to its canonical
coin first, use the inherited `name_to_coin()`.

### Official Documentation

<https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint>

### Endpoints Covered

|                              |                      |      |
|------------------------------|----------------------|------|
| Method                       | type                 | Auth |
| get_meta                     | meta                 | No   |
| get_spot_meta                | spotMeta             | No   |
| get_spot_tokens              | spotMeta             | No   |
| get_meta_and_asset_ctxs      | metaAndAssetCtxs     | No   |
| get_spot_meta_and_asset_ctxs | spotMetaAndAssetCtxs | No   |
| get_all_mids                 | allMids              | No   |
| get_l2_book                  | l2Book               | No   |
| get_candles                  | candleSnapshot       | No   |
| get_funding_history          | fundingHistory       | No   |
| get_predicted_fundings       | predictedFundings    | No   |
| get_perp_dexs                | perpDexs             | No   |
| get_recent_trades            | recentTrades         | No   |
| get_exchange_status          | exchangeStatus       | No   |

## Super class

[`hyperliquid::HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
-\> `HyperliquidMarketData`

## Methods

### Public methods

- [`HyperliquidMarketData$get_meta()`](#method-HyperliquidMarketData-get_meta)

- [`HyperliquidMarketData$get_spot_meta()`](#method-HyperliquidMarketData-get_spot_meta)

- [`HyperliquidMarketData$get_spot_tokens()`](#method-HyperliquidMarketData-get_spot_tokens)

- [`HyperliquidMarketData$get_meta_and_asset_ctxs()`](#method-HyperliquidMarketData-get_meta_and_asset_ctxs)

- [`HyperliquidMarketData$get_spot_meta_and_asset_ctxs()`](#method-HyperliquidMarketData-get_spot_meta_and_asset_ctxs)

- [`HyperliquidMarketData$get_all_mids()`](#method-HyperliquidMarketData-get_all_mids)

- [`HyperliquidMarketData$get_l2_book()`](#method-HyperliquidMarketData-get_l2_book)

- [`HyperliquidMarketData$get_candles()`](#method-HyperliquidMarketData-get_candles)

- [`HyperliquidMarketData$get_funding_history()`](#method-HyperliquidMarketData-get_funding_history)

- [`HyperliquidMarketData$get_predicted_fundings()`](#method-HyperliquidMarketData-get_predicted_fundings)

- [`HyperliquidMarketData$get_perp_dexs()`](#method-HyperliquidMarketData-get_perp_dexs)

- [`HyperliquidMarketData$get_recent_trades()`](#method-HyperliquidMarketData-get_recent_trades)

- [`HyperliquidMarketData$get_exchange_status()`](#method-HyperliquidMarketData-get_exchange_status)

- [`HyperliquidMarketData$clone()`](#method-HyperliquidMarketData-clone)

Inherited methods

- [`hyperliquid::HyperliquidBase$initialize()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-initialize)
- [`hyperliquid::HyperliquidBase$name_to_asset()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_asset)
- [`hyperliquid::HyperliquidBase$name_to_coin()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_coin)
- [`hyperliquid::HyperliquidBase$refresh_meta()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-refresh_meta)
- [`hyperliquid::HyperliquidBase$sz_decimals()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-sz_decimals)

------------------------------------------------------------------------

### Method `get_meta()`

Retrieve perpetual exchange metadata: the perp universe. `marginTables`
and `collateralToken` top-level extras are not returned.

#### Usage

    HyperliquidMarketData$get_meta()

#### Returns

(promise\<PerpMeta\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `name`, `sz_decimals`, `max_leverage`, `margin_table_id`,
`only_isolated`, `is_delisted`, `margin_mode`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_spot_meta()`

Retrieve spot exchange metadata: the spot pair universe. Sibling of
get_spot_tokens(), which parses the token table from the same payload.

#### Usage

    HyperliquidMarketData$get_spot_meta()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `name`, `index`, `is_canonical`, `token_base`,
`token_quote`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_spot_tokens()`

Retrieve spot exchange metadata: the token table. Sibling of
get_spot_meta(), which parses the pair universe from the same payload.

#### Usage

    HyperliquidMarketData$get_spot_tokens()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `name`, `index`, `sz_decimals`, `wei_decimals`, `token_id`,
`is_canonical`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_meta_and_asset_ctxs()`

Retrieve the perp universe joined with per-asset contexts
(mark/mid/oracle prices, funding, open interest, impact prices) by
index, one row per perp coin.

#### Usage

    HyperliquidMarketData$get_meta_and_asset_ctxs()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `name`, `sz_decimals`, `max_leverage`, `day_ntl_vlm`,
`funding`, `mark_px`, `mid_px`, `oracle_px`, `open_interest`, `premium`,
`prev_day_px`, `impact_px_bid`, `impact_px_ask`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_spot_meta_and_asset_ctxs()`

Retrieve per-asset contexts for every spot coin, one row per spot coin.

#### Usage

    HyperliquidMarketData$get_spot_meta_and_asset_ctxs()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `coin`, `day_ntl_vlm`, `mark_px`, `mid_px`, `prev_day_px`,
`circulating_supply`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_all_mids()`

Retrieve mid prices for all actively traded coins, long: one row per
coin.

#### Usage

    HyperliquidMarketData$get_all_mids()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `coin`, `mid`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_l2_book()`

Retrieve the L2 order book for a coin, long: both sides stacked with a
`side` discriminator and a 1-indexed `level`.

#### Usage

    HyperliquidMarketData$get_l2_book(coin, n_sig_figs = NULL, mantissa = NULL)

#### Arguments

- `coin`:

  (scalar\<character\>) the canonical coin symbol, e.g. `"BTC"`.

- `n_sig_figs`:

  (scalar\<numeric\> \| NULL) aggregate levels to this many significant
  figures (2-5). `NULL` (default) returns full precision.

- `mantissa`:

  (scalar\<numeric\> \| NULL) mantissa for aggregation, paired with
  `n_sig_figs = 5`. Default `NULL`.

#### Returns

(promise\<L2Level\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `side`, `level`, `px`, `sz`, `n`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_candles()`

Retrieve OHLCV candles for a coin over a time range, sorted ascending by
open time. The endpoint returns at most ~5000 candles per call.

#### Usage

    HyperliquidMarketData$get_candles(coin, interval, start, end)

#### Arguments

- `coin`:

  (scalar\<character\>) the canonical coin symbol, e.g. `"BTC"`.

- `interval`:

  (scalar) one of
  [HYPERLIQUID_INTERVALS](https://dereckscompany.github.io/hyperliquid/reference/HYPERLIQUID_INTERVALS.md).

- `start`:

  (POSIXct \| numeric) range start (POSIXct or numeric
  epoch-milliseconds).

- `end`:

  (POSIXct \| numeric) range end (POSIXct or numeric
  epoch-milliseconds).

#### Returns

(promise\<Candles\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `datetime`, `open`, `high`, `low`, `close`, `volume`,
`trades`, `close_time`, `interval`, `coin`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_funding_history()`

Retrieve funding-rate history for a coin. History is complete and free
on Hyperliquid; 500 records are returned per call.

#### Usage

    HyperliquidMarketData$get_funding_history(coin, start, end = NULL)

#### Arguments

- `coin`:

  (scalar\<character\>) the canonical coin symbol, e.g. `"BTC"`.

- `start`:

  (POSIXct \| numeric) range start (POSIXct or numeric
  epoch-milliseconds).

- `end`:

  (POSIXct \| numeric \| NULL) range end (POSIXct, numeric
  epoch-milliseconds, or `NULL`). Default `NULL` (up to now).

#### Returns

(promise\<FundingHistory\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `coin`, `funding_rate`, `premium`, `time`, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_predicted_fundings()`

Retrieve predicted next-funding rates across venues, long: one row per
(coin, venue).

#### Usage

    HyperliquidMarketData$get_predicted_fundings()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `coin`, `venue`, `funding_rate`, `next_funding_time`,
`funding_interval_hours`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_perp_dexs()`

Retrieve builder-deployed (HIP-3) perp dexes. The `null` core-dex
sentinel is omitted.

#### Usage

    HyperliquidMarketData$get_perp_dexs()

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `name`, `full_name`, `deployer`, `oracle_updater`,
`fee_recipient`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_recent_trades()`

Retrieve the most recent trades for a coin (about 10 rows, both
counterparty addresses included).

#### Usage

    HyperliquidMarketData$get_recent_trades(coin)

#### Arguments

- `coin`:

  (scalar\<character\>) the canonical coin symbol, e.g. `"BTC"`.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `coin`, `side`, `px`, `sz`, `time`, `hash`, `tid`,
`user_buyer`, `user_seller`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_exchange_status()`

Retrieve the current exchange status.

#### Usage

    HyperliquidMarketData$get_exchange_status()

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with columns `time`, `special_statuses`, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidMarketData$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
market <- HyperliquidMarketData$new()
market$get_all_mids()
market$get_l2_book("BTC")
market$get_candles("BTC", interval = "1h",
  start = lubridate::now("UTC") - lubridate::days(1),
  end = lubridate::now("UTC"))

# Asynchronous
market_async <- HyperliquidMarketData$new(async = TRUE)
main <- coro::async(function() {
  book <- await(market_async$get_l2_book("BTC"))
  print(book)
})
main()
while (!later::loop_empty()) later::run_now()
} # }
```
