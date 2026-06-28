# Offline tests for HyperliquidMarketData: every /info parser against its
# captured fixture (columns, types, no list columns, zero-row on empty), plus
# end-to-end reads through a mocked transport asserting the posted body carries
# the right `type` discriminator and that the parsed data.table is correct.
# MarketData is unauthenticated, so no signing is exercised here.

source(testthat::test_path("fixtures-marketdata.R"))

# ---- test helpers ------------------------------------------------------------

# Build an httr2 response from a fixture list (mirrors the live JSON body).
hl_md_response <- function(data, status = 200L) {
  body <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = status,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(body))
  ))
}

# Decode the JSON body of a built httr2 request back to an R list.
hl_md_req_body <- function(req) {
  data <- req$body$data
  if (is.raw(data)) {
    data <- rawToChar(data)
  }
  return(jsonlite::fromJSON(as.character(data), simplifyVector = FALSE))
}

no_list_cols <- function(dt) {
  return(!any(vapply(dt, is.list, logical(1))))
}

# A read-only client (no signing key, no env warning) -- MarketData never signs.
read_client <- function() {
  return(hyperliquid:::HyperliquidMarketData$new(
    keys = list(private_key = NULL, account_address = NULL, wallet_address = NULL)
  ))
}

# ---- parse_meta --------------------------------------------------------------

test_that("parse_meta returns the perp universe with sparse logical/string cols", {
  dt <- hyperliquid:::parse_meta(hl_md_meta())
  expect_s3_class(dt, "data.table")
  expect_equal(nrow(dt), 4L)
  expect_equal(
    names(dt),
    c("name", "sz_decimals", "max_leverage", "margin_table_id", "only_isolated", "is_delisted", "margin_mode")
  )
  expect_equal(dt$name, c("BTC", "ETH", "MATIC", "HOOD"))
  expect_equal(dt$sz_decimals, c(5, 4, 1, 3))
  expect_equal(dt$max_leverage, c(40, 25, 20, 10))
  expect_type(dt$sz_decimals, "double")
  # only_isolated: absent -> NA, present TRUE for HOOD.
  expect_type(dt$only_isolated, "logical")
  expect_true(all(is.na(dt$only_isolated[1:3])))
  expect_true(dt$only_isolated[4])
  # is_delisted: absent -> FALSE, TRUE for MATIC.
  expect_type(dt$is_delisted, "logical")
  expect_equal(dt$is_delisted, c(FALSE, FALSE, TRUE, FALSE))
  # margin_mode: absent -> NA, "noCross" for HOOD.
  expect_type(dt$margin_mode, "character")
  expect_true(all(is.na(dt$margin_mode[1:3])))
  expect_equal(dt$margin_mode[4], "noCross")
  expect_true(no_list_cols(dt))
})

test_that("parse_meta returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_meta(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_meta(list(universe = list()))), 0L)
})

# ---- parse_spot_meta_universe ------------------------------------------------

test_that("parse_spot_meta_universe splits the token pair into base/quote", {
  dt <- hyperliquid:::parse_spot_meta_universe(hl_md_spot_meta())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("name", "index", "is_canonical", "token_base", "token_quote"))
  expect_equal(dt$name, c("PURR/USDC", "@1"))
  expect_equal(dt$index, c(0, 1))
  expect_equal(dt$is_canonical, c(TRUE, FALSE))
  expect_equal(dt$token_base, c(1, 2))
  expect_equal(dt$token_quote, c(0, 0))
  expect_type(dt$token_base, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_spot_meta_universe returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_spot_meta_universe(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_spot_meta_universe(list(universe = list()))), 0L)
})

# ---- parse_spot_tokens -------------------------------------------------------

test_that("parse_spot_tokens returns the token table from the spotMeta payload", {
  dt <- hyperliquid:::parse_spot_tokens(hl_md_spot_meta())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c("name", "index", "sz_decimals", "wei_decimals", "token_id", "is_canonical")
  )
  expect_equal(dt$name, c("USDC", "PURR"))
  expect_equal(dt$index, c(0, 1))
  expect_equal(dt$sz_decimals, c(8, 0))
  expect_equal(dt$wei_decimals, c(8, 5))
  expect_equal(dt$token_id, c("0x6d1e7cde53ba9467b783cb7c530ce054", "0xc1fb593aeffbeb02f85e0308e9956a90"))
  expect_equal(dt$is_canonical, c(TRUE, TRUE))
  expect_type(dt$token_id, "character")
  expect_true(no_list_cols(dt))
})

test_that("parse_spot_tokens returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_spot_tokens(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_spot_tokens(list(tokens = list()))), 0L)
})

# ---- parse_meta_and_asset_ctxs -----------------------------------------------

test_that("parse_meta_and_asset_ctxs joins universe[i] with ctx[i] by index", {
  dt <- hyperliquid:::parse_meta_and_asset_ctxs(hl_md_meta_and_asset_ctxs())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c(
      "name",
      "sz_decimals",
      "max_leverage",
      "day_ntl_vlm",
      "funding",
      "mark_px",
      "mid_px",
      "oracle_px",
      "open_interest",
      "premium",
      "prev_day_px",
      "impact_px_bid",
      "impact_px_ask"
    )
  )
  expect_equal(dt$name, c("BTC", "ETH"))
  expect_equal(dt$mark_px, c(61964, 1606.2))
  expect_equal(dt$mid_px, c(61966.5, 1606.15))
  expect_equal(dt$oracle_px, c(61986, 1607))
  expect_equal(dt$funding, c(0.0000125, 0.0000064122))
  expect_equal(dt$open_interest, c(33122.6367, 685018.9388))
  # impactPxs is a [bid, ask] 2-array.
  expect_equal(dt$impact_px_bid, c(61966, 1606.1))
  expect_equal(dt$impact_px_ask, c(61967, 1606.26))
  expect_type(dt$mark_px, "double")
  expect_type(dt$day_ntl_vlm, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_meta_and_asset_ctxs returns a zero-row data.table when empty", {
  empty <- list(list(universe = list()), list())
  expect_equal(nrow(hyperliquid:::parse_meta_and_asset_ctxs(empty)), 0L)
})

# ---- parse_spot_meta_and_asset_ctxs ------------------------------------------

test_that("parse_spot_meta_and_asset_ctxs returns one row per spot coin", {
  dt <- hyperliquid:::parse_spot_meta_and_asset_ctxs(hl_md_spot_meta_and_asset_ctxs())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c("coin", "day_ntl_vlm", "mark_px", "mid_px", "prev_day_px", "circulating_supply")
  )
  expect_equal(dt$coin, c("PURR/USDC", "@1"))
  expect_equal(dt$mark_px, c(0.090784, 9.6794))
  expect_equal(dt$prev_day_px, c(0.08889, 9.7168))
  expect_equal(dt$circulating_supply, c(595295911.3807499409, 995906.4607351))
  expect_type(dt$mark_px, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_spot_meta_and_asset_ctxs returns a zero-row data.table when empty", {
  empty <- list(list(universe = list(), tokens = list()), list())
  expect_equal(nrow(hyperliquid:::parse_spot_meta_and_asset_ctxs(empty)), 0L)
})

# ---- parse_all_mids ----------------------------------------------------------

test_that("parse_all_mids turns the {coin: mid} dict into a long table", {
  dt <- hyperliquid:::parse_all_mids(hl_md_all_mids())
  expect_equal(nrow(dt), 3L)
  expect_equal(names(dt), c("coin", "mid"))
  expect_equal(dt$coin, c("BTC", "ETH", "@1"))
  expect_equal(dt$mid, c(61958.5, 1605.45, 9.6738))
  expect_type(dt$coin, "character")
  expect_type(dt$mid, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_all_mids returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_all_mids(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_all_mids(list())), 0L)
})

# ---- parse_l2_book -----------------------------------------------------------

test_that("parse_l2_book stacks bids then asks long with a 1-indexed level", {
  dt <- hyperliquid:::parse_l2_book(hl_md_l2_book())
  expect_equal(nrow(dt), 4L)
  expect_equal(names(dt), c("side", "level", "px", "sz", "n"))
  expect_equal(dt$side, c("bid", "bid", "ask", "ask"))
  expect_equal(dt$level, c(1L, 2L, 1L, 2L))
  expect_equal(dt$px, c(61945, 61944, 61946, 61947))
  expect_equal(dt$sz, c(0.03164, 0.00085, 13.32523, 0.06724))
  expect_equal(dt$n, c(3, 4, 39, 6))
  expect_type(dt$px, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_l2_book returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_l2_book(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_l2_book(list(levels = list()))), 0L)
})

# ---- parse_candles -----------------------------------------------------------

test_that("parse_candles emits canonical OHLCV sorted ascending by open time", {
  dt <- hyperliquid:::parse_candles(hl_md_candles())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c("datetime", "open", "high", "low", "close", "volume", "trades", "close_time", "interval", "coin")
  )
  expect_s3_class(dt$datetime, "POSIXct")
  expect_s3_class(dt$close_time, "POSIXct")
  # Fixture is supplied out of order; the earlier candle must come first.
  expect_true(dt$datetime[1] < dt$datetime[2])
  expect_equal(dt$open, c(60516, 60860))
  expect_equal(dt$close, c(60861, 60750))
  expect_equal(dt$trades, c(15901, 15829))
  expect_equal(dt$interval, c("1h", "1h"))
  expect_equal(dt$coin, c("BTC", "BTC"))
  expect_type(dt$open, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_candles returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_candles(NULL)), 0L)
  # An empty candle window is a routine live response: the typed zero-row
  # schema must still satisfy the @return contract.
  empty <- hyperliquid:::parse_candles(list())
  expect_equal(nrow(empty), 0L)
  expect_silent(hyperliquid:::assert_return_HyperliquidMarketData__get_candles(empty))
})

# ---- parse_funding_history ---------------------------------------------------

test_that("parse_funding_history returns coin/rate/premium/time rows", {
  dt <- hyperliquid:::parse_funding_history(hl_md_funding_history())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("coin", "funding_rate", "premium", "time"))
  expect_equal(dt$coin, c("BTC", "BTC"))
  expect_equal(dt$funding_rate, c(0.0000034197, 0.000010114))
  expect_s3_class(dt$time, "POSIXct")
  expect_type(dt$funding_rate, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_funding_history returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_funding_history(NULL)), 0L)
  # A coin/window with no funding events is a routine live response: the typed
  # zero-row schema must still satisfy the @return contract.
  empty <- hyperliquid:::parse_funding_history(list())
  expect_equal(nrow(empty), 0L)
  expect_silent(hyperliquid:::assert_return_HyperliquidMarketData__get_funding_history(empty))
})

# ---- parse_predicted_fundings ------------------------------------------------

test_that("parse_predicted_fundings flattens [coin,[[venue,{...}]]] long", {
  dt <- hyperliquid:::parse_predicted_fundings(hl_md_predicted_fundings())
  expect_equal(nrow(dt), 4L)
  expect_equal(
    names(dt),
    c("coin", "venue", "funding_rate", "next_funding_time", "funding_interval_hours")
  )
  expect_equal(dt$coin, c("BTC", "BTC", "AI", "AI"))
  expect_equal(dt$venue, c("BinPerp", "HlPerp", "BinPerp", "BybitPerp"))
  expect_s3_class(dt$next_funding_time, "POSIXct")
  # AI/BinPerp omits fundingIntervalHours; AI/BybitPerp has a null body.
  expect_true(is.na(dt$funding_interval_hours[3]))
  expect_true(is.na(dt$funding_rate[4]))
  expect_true(is.na(dt$next_funding_time[4]))
  expect_true(is.na(dt$funding_interval_hours[4]))
  expect_equal(dt$funding_interval_hours[1:2], c(4, 1))
  expect_type(dt$funding_rate, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_predicted_fundings returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_predicted_fundings(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_predicted_fundings(list())), 0L)
})

# ---- parse_perp_dexs ---------------------------------------------------------

test_that("parse_perp_dexs skips the null core-dex sentinel", {
  dt <- hyperliquid:::parse_perp_dexs(hl_md_perp_dexs())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("name", "full_name", "deployer", "oracle_updater", "fee_recipient"))
  expect_equal(dt$name, "xyz")
  expect_equal(dt$full_name, "XYZ")
  expect_equal(dt$deployer, "0x88806a71d74ad0a510b350545c9ae490912f0888")
  # oracleUpdater is null in the fixture -> NA.
  expect_true(is.na(dt$oracle_updater))
  expect_equal(dt$fee_recipient, "0x9cd0a696c7cbb9d44de99268194cb08e5684e5fe")
  expect_type(dt$name, "character")
  expect_true(no_list_cols(dt))
})

test_that("parse_perp_dexs returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_perp_dexs(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_perp_dexs(list())), 0L)
  # A payload of only the null sentinel yields no rows.
  expect_equal(nrow(hyperliquid:::parse_perp_dexs(list(NULL))), 0L)
})

# ---- parse_recent_trades -----------------------------------------------------

test_that("parse_recent_trades maps B/A sides and splits the [buyer, seller] users", {
  dt <- hyperliquid:::parse_recent_trades(hl_md_recent_trades())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c("coin", "side", "px", "sz", "time", "hash", "tid", "user_buyer", "user_seller")
  )
  expect_equal(dt$side, c("buy", "sell"))
  expect_equal(dt$px, c(61917, 61916))
  expect_equal(dt$sz, c(0.00032, 0.001))
  expect_s3_class(dt$time, "POSIXct")
  expect_equal(dt$user_buyer[1], "0x28f0233472b6a44e170e002a72845ca100be4a7e")
  expect_equal(dt$user_seller[1], "0x1c1c270b573d55b68b3d14722b5d5d401511bed0")
  expect_type(dt$tid, "double")
  expect_type(dt$user_buyer, "character")
  expect_true(no_list_cols(dt))
})

test_that("parse_recent_trades returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_recent_trades(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_recent_trades(list())), 0L)
})

# ---- parse_exchange_status ---------------------------------------------------

test_that("parse_exchange_status returns one row with time and special_statuses", {
  dt <- hyperliquid:::parse_exchange_status(hl_md_exchange_status())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("time", "special_statuses"))
  expect_s3_class(dt$time, "POSIXct")
  # specialStatuses is null in practice -> NA character.
  expect_true(is.na(dt$special_statuses))
  expect_type(dt$special_statuses, "character")
  expect_true(no_list_cols(dt))
})

test_that("parse_exchange_status returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_exchange_status(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_exchange_status(list())), 0L)
})

# ---- end-to-end reads through a mocked transport -----------------------------

test_that("get_meta posts the meta type and parses the perp universe", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    seen$url <- req$url
    return(hl_md_response(hl_md_meta()))
  })

  client <- read_client()
  dt <- client$get_meta()

  expect_match(seen$url, "/info", fixed = TRUE)
  expect_equal(seen$body$type, "meta")
  expect_equal(nrow(dt), 4L)
  expect_equal(dt$name, c("BTC", "ETH", "MATIC", "HOOD"))
  expect_true(no_list_cols(dt))
})

test_that("get_all_mids posts the allMids type and parses the long table", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_all_mids()))
  })

  client <- read_client()
  dt <- client$get_all_mids()

  expect_equal(seen$body$type, "allMids")
  expect_equal(nrow(dt), 3L)
  expect_equal(dt$mid, c(61958.5, 1605.45, 9.6738))
  expect_true(no_list_cols(dt))
})

test_that("get_l2_book posts l2Book with the coin and aggregation params", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_l2_book()))
  })

  client <- read_client()
  dt <- client$get_l2_book("BTC", n_sig_figs = 5, mantissa = 2)

  expect_equal(seen$body$type, "l2Book")
  expect_equal(seen$body$coin, "BTC")
  expect_equal(seen$body$nSigFigs, 5)
  expect_equal(seen$body$mantissa, 2)
  expect_equal(nrow(dt), 4L)
  expect_equal(dt$side, c("bid", "bid", "ask", "ask"))
  expect_true(no_list_cols(dt))
})

test_that("get_l2_book omits aggregation params when not supplied", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_l2_book()))
  })

  client <- read_client()
  client$get_l2_book("BTC")

  expect_equal(seen$body$coin, "BTC")
  expect_null(seen$body$nSigFigs)
  expect_null(seen$body$mantissa)
})

test_that("get_candles nests params under req and returns ascending OHLCV", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_candles()))
  })

  client <- read_client()
  dt <- client$get_candles(
    "BTC",
    interval = "1h",
    start = lubridate::as_datetime("2026-06-06 00:00:00", tz = "UTC"),
    end = lubridate::as_datetime("2026-06-06 02:00:00", tz = "UTC")
  )

  expect_equal(seen$body$type, "candleSnapshot")
  expect_equal(seen$body$req$coin, "BTC")
  expect_equal(seen$body$req$interval, "1h")
  expect_true(is.numeric(seen$body$req$startTime))
  expect_true(is.numeric(seen$body$req$endTime))
  expect_equal(nrow(dt), 2L)
  expect_true(dt$datetime[1] < dt$datetime[2])
  expect_true(no_list_cols(dt))
})

test_that("get_candles accepts raw epoch-ms bounds", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_candles()))
  })

  client <- read_client()
  client$get_candles("BTC", interval = "1h", start = 1780786800000, end = 1780793999999)

  expect_equal(seen$body$req$startTime, 1780786800000)
  expect_equal(seen$body$req$endTime, 1780793999999)
})

test_that("get_recent_trades posts recentTrades with the coin", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_md_req_body(req)
    return(hl_md_response(hl_md_recent_trades()))
  })

  client <- read_client()
  dt <- client$get_recent_trades("BTC")

  expect_equal(seen$body$type, "recentTrades")
  expect_equal(seen$body$coin, "BTC")
  expect_equal(dt$side, c("buy", "sell"))
  expect_true(no_list_cols(dt))
})

# ---- input validation --------------------------------------------------------

test_that("market-data reads validate the coin and interval", {
  client <- read_client()
  expect_error(client$get_l2_book(""))
  expect_error(client$get_recent_trades(""))
  expect_error(client$get_candles("BTC", interval = "6h", start = 0, end = 1))
})
