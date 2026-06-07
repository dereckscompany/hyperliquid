# File: R/HyperliquidMarketData.R
# Public market-data client for Hyperliquid. Every method is an unauthenticated
# POST to /info, discriminated by the body `type`; no signing is involved.

#' HyperliquidMarketData: Public Market Data Retrieval
#'
#' ### Purpose
#' Retrieves all public market data from Hyperliquid's `/info` endpoint: perp
#' and spot metadata, asset contexts (mark/mid/oracle/funding/open-interest),
#' all mids, the L2 order book, OHLCV candles, funding history and predicted
#' fundings, builder-deployed perp dexes, recent trades, and exchange status.
#' Every method is unauthenticated and needs no wallet key.
#'
#' Inherits from [HyperliquidBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction; in
#' async mode each returns a [promises::promise] resolving to the same
#' [data.table::data.table].
#'
#' Methods take a `coin` as its canonical Hyperliquid symbol (`"BTC"`, `"@107"`,
#' `"PURR/USDC"`). To resolve a friendly name to its canonical coin first, use
#' the inherited `name_to_coin()`.
#'
#' ### Official Documentation
#' <https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint>
#'
#' ### Endpoints Covered
#' | Method | type | Auth |
#' |--------|------|------|
#' | get_meta | meta | No |
#' | get_spot_meta | spotMeta | No |
#' | get_spot_tokens | spotMeta | No |
#' | get_meta_and_asset_ctxs | metaAndAssetCtxs | No |
#' | get_spot_meta_and_asset_ctxs | spotMetaAndAssetCtxs | No |
#' | get_all_mids | allMids | No |
#' | get_l2_book | l2Book | No |
#' | get_candles | candleSnapshot | No |
#' | get_funding_history | fundingHistory | No |
#' | get_predicted_fundings | predictedFundings | No |
#' | get_perp_dexs | perpDexs | No |
#' | get_recent_trades | recentTrades | No |
#' | get_exchange_status | exchangeStatus | No |
#'
#' @examples
#' \dontrun{
#' market <- HyperliquidMarketData$new()
#' market$get_all_mids()
#' market$get_l2_book("BTC")
#' market$get_candles("BTC", interval = "1h",
#'   start = lubridate::now("UTC") - lubridate::days(1),
#'   end = lubridate::now("UTC"))
#'
#' # Asynchronous
#' market_async <- HyperliquidMarketData$new(async = TRUE)
#' main <- coro::async(function() {
#'   book <- await(market_async$get_l2_book("BTC"))
#'   print(book)
#' })
#' main()
#' while (!later::loop_empty()) later::run_now()
#' }
#'
#' @import data.table
#' @export
HyperliquidMarketData <- R6::R6Class(
  "HyperliquidMarketData",
  inherit = HyperliquidBase,
  public = list(
    #' @description Retrieve perpetual exchange metadata: the perp universe.
    #'   `marginTables` and `collateralToken` top-level extras are not returned.
    #' @return (promise<PerpMeta>) a [data.table::data.table] with columns
    #'   `name`, `sz_decimals`, `max_leverage`, `margin_table_id`,
    #'   `only_isolated`, `is_delisted`, `margin_mode`, or a promise thereof.
    get_meta = function() {
      return(private$.info(
        list(type = "meta"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_meta(parse_meta(x))
      ))
    },

    #' @description Retrieve spot exchange metadata: the spot pair universe.
    #'   Sibling of [get_spot_tokens()][HyperliquidMarketData], which parses the token table from the
    #'   same payload.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `name`, `index`, `is_canonical`, `token_base`, `token_quote`, or a
    #'   promise thereof.
    get_spot_meta = function() {
      return(private$.info(
        list(type = "spotMeta"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_spot_meta(parse_spot_meta_universe(x))
      ))
    },

    #' @description Retrieve spot exchange metadata: the token table. Sibling of
    #'   [get_spot_meta()][HyperliquidMarketData], which parses the pair universe from the same payload.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `name`, `index`, `sz_decimals`, `wei_decimals`, `token_id`,
    #'   `is_canonical`, or a promise thereof.
    get_spot_tokens = function() {
      return(private$.info(
        list(type = "spotMeta"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_spot_tokens(parse_spot_tokens(x))
      ))
    },

    #' @description Retrieve the perp universe joined with per-asset contexts
    #'   (mark/mid/oracle prices, funding, open interest, impact prices) by index,
    #'   one row per perp coin.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `name`, `sz_decimals`, `max_leverage`, `day_ntl_vlm`, `funding`,
    #'   `mark_px`, `mid_px`, `oracle_px`, `open_interest`, `premium`,
    #'   `prev_day_px`, `impact_px_bid`, `impact_px_ask`, or a promise thereof.
    get_meta_and_asset_ctxs = function() {
      return(private$.info(
        list(type = "metaAndAssetCtxs"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_meta_and_asset_ctxs(parse_meta_and_asset_ctxs(x))
      ))
    },

    #' @description Retrieve per-asset contexts for every spot coin, one row per
    #'   spot coin.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `coin`, `day_ntl_vlm`, `mark_px`, `mid_px`, `prev_day_px`,
    #'   `circulating_supply`, or a promise thereof.
    get_spot_meta_and_asset_ctxs = function() {
      return(private$.info(
        list(type = "spotMetaAndAssetCtxs"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_spot_meta_and_asset_ctxs(parse_spot_meta_and_asset_ctxs(x))
      ))
    },

    #' @description Retrieve mid prices for all actively traded coins, long: one
    #'   row per coin.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `coin`, `mid`, or a promise thereof.
    get_all_mids = function() {
      return(private$.info(
        list(type = "allMids"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_all_mids(parse_all_mids(x))
      ))
    },

    #' @description Retrieve the L2 order book for a coin, long: both sides
    #'   stacked with a `side` discriminator and a 1-indexed `level`.
    #' @param coin (scalar<character>) the canonical coin symbol, e.g. `"BTC"`.
    #' @param n_sig_figs (scalar<numeric> | NULL) aggregate levels to this many
    #'   significant figures (2-5). `NULL` (default) returns full precision.
    #' @param mantissa (scalar<numeric> | NULL) mantissa for aggregation, paired
    #'   with `n_sig_figs = 5`. Default `NULL`.
    #' @return (promise<L2Level>) a [data.table::data.table] with columns `side`,
    #'   `level`, `px`, `sz`, `n`, or a promise thereof.
    get_l2_book = function(coin, n_sig_figs = NULL, mantissa = NULL) {
      assert_args_HyperliquidMarketData__get_l2_book(coin, n_sig_figs, mantissa)
      validate_coin(coin)
      payload <- list(type = "l2Book", coin = coin)
      if (!is.null(n_sig_figs)) {
        payload$nSigFigs <- n_sig_figs
      }
      if (!is.null(mantissa)) {
        payload$mantissa <- mantissa
      }
      return(private$.info(
        payload,
        .parser = function(x) assert_return_HyperliquidMarketData__get_l2_book(parse_l2_book(x))
      ))
    },

    #' @description Retrieve OHLCV candles for a coin over a time range, sorted
    #'   ascending by open time. The endpoint returns at most ~5000 candles per
    #'   call.
    #' @param coin (scalar<character>) the canonical coin symbol, e.g. `"BTC"`.
    #' @param interval (scalar<character in HYPERLIQUID_INTERVALS>) one of
    #'   [HYPERLIQUID_INTERVALS].
    #' @param start (POSIXct | numeric) range start (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @param end (POSIXct | numeric) range end (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @return (promise<Candles>) a [data.table::data.table] with columns
    #'   `datetime`, `open`, `high`, `low`, `close`, `volume`, `trades`,
    #'   `close_time`, `interval`, `coin`, or a promise thereof.
    get_candles = function(coin, interval, start, end) {
      assert_args_HyperliquidMarketData__get_candles(coin, interval, start, end)
      validate_coin(coin)
      validate_interval(interval)
      start_ms <- if (is.numeric(start)) floor(start) else datetime_to_ms(start)
      end_ms <- if (is.numeric(end)) floor(end) else datetime_to_ms(end)
      payload <- list(
        type = "candleSnapshot",
        req = list(
          coin = coin,
          interval = interval,
          startTime = start_ms,
          endTime = end_ms
        )
      )
      return(private$.info(
        payload,
        .parser = function(x) assert_return_HyperliquidMarketData__get_candles(parse_candles(x))
      ))
    },

    #' @description Retrieve funding-rate history for a coin. History is complete
    #'   and free on Hyperliquid; 500 records are returned per call.
    #' @param coin (scalar<character>) the canonical coin symbol, e.g. `"BTC"`.
    #' @param start (POSIXct | numeric) range start (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @param end (POSIXct | numeric | NULL) range end (POSIXct, numeric
    #'   epoch-milliseconds, or `NULL`). Default `NULL` (up to now).
    #' @return (promise<FundingHistory>) a [data.table::data.table] with columns
    #'   `coin`, `funding_rate`, `premium`, `time`, or a promise thereof.
    get_funding_history = function(coin, start, end = NULL) {
      assert_args_HyperliquidMarketData__get_funding_history(coin, start, end)
      validate_coin(coin)
      start_ms <- if (is.numeric(start)) floor(start) else datetime_to_ms(start)
      payload <- list(type = "fundingHistory", coin = coin, startTime = start_ms)
      if (!is.null(end)) {
        payload$endTime <- if (is.numeric(end)) floor(end) else datetime_to_ms(end)
      }
      return(private$.info(
        payload,
        .parser = function(x) assert_return_HyperliquidMarketData__get_funding_history(parse_funding_history(x))
      ))
    },

    #' @description Retrieve predicted next-funding rates across venues, long:
    #'   one row per (coin, venue).
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `coin`, `venue`, `funding_rate`, `next_funding_time`,
    #'   `funding_interval_hours`, or a promise thereof.
    get_predicted_fundings = function() {
      return(private$.info(
        list(type = "predictedFundings"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_predicted_fundings(parse_predicted_fundings(x))
      ))
    },

    #' @description Retrieve builder-deployed (HIP-3) perp dexes. The `null`
    #'   core-dex sentinel is omitted.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `name`, `full_name`, `deployer`, `oracle_updater`, `fee_recipient`, or a
    #'   promise thereof.
    get_perp_dexs = function() {
      return(private$.info(
        list(type = "perpDexs"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_perp_dexs(parse_perp_dexs(x))
      ))
    },

    #' @description Retrieve the most recent trades for a coin (about 10 rows,
    #'   both counterparty addresses included).
    #' @param coin (scalar<character>) the canonical coin symbol, e.g. `"BTC"`.
    #' @return (promise<data.table>) a [data.table::data.table] with columns
    #'   `coin`, `side`, `px`, `sz`, `time`, `hash`, `tid`, `user_buyer`,
    #'   `user_seller`, or a promise thereof.
    get_recent_trades = function(coin) {
      assert_args_HyperliquidMarketData__get_recent_trades(coin)
      validate_coin(coin)
      return(private$.info(
        list(type = "recentTrades", coin = coin),
        .parser = function(x) assert_return_HyperliquidMarketData__get_recent_trades(parse_recent_trades(x))
      ))
    },

    #' @description Retrieve the current exchange status.
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   columns `time`, `special_statuses`, or a promise thereof.
    get_exchange_status = function() {
      return(private$.info(
        list(type = "exchangeStatus"),
        .parser = function(x) assert_return_HyperliquidMarketData__get_exchange_status(parse_exchange_status(x))
      ))
    }
  )
)
