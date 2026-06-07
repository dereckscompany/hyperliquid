# End-to-end tests: drive every public R6 client method through the shared
# mock_router (the same fixtures the README and vignettes render against). The
# domain unit tests exercise the parsers in isolation; these cover the wiring
# around them -- the request funnel, the /info-vs-/exchange path selection, body
# serialisation, signing of /exchange writes, and each method's real .parser
# closure -- which otherwise only runs during a docs render. The router
# intercepts every request, so nothing here touches the network.

box::use(./mock_router[mock_router])

# A throwaway wallet key so signing (which runs before the request) succeeds; the
# mock ignores the signature entirely. 0x0101..01 is a valid non-zero secp256k1
# scalar.
.keys <- get_api_keys(private_key = paste0("0x", paste(rep("01", 32), collapse = "")))

# A real-looking account/destination address and a spot token wire string.
.addr <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"
.dest <- "0x5e9ee1089755c3435139848e47e6635505d5a13a"
.validator <- "0x5ac99df645f3414876c816caa18b2d234024b487"
.token <- "PURR:0xc1fb593aeffbeb02f85e0308e9956a90"

# Pre-seed the asset-lookup cache so Trading's name_to_asset / name_to_coin /
# sz_decimals resolve "BTC" (perp asset 0, szDecimals 5) and "PURR/USDC" (spot
# asset 10000) with no metadata fetch. Built via build_asset_maps so the cache
# layout matches the live one exactly.
seed_meta <- function(client) {
  meta <- list(universe = list(
    list(name = "BTC", szDecimals = 5, maxLeverage = 40)
  ))
  spot_meta <- list(
    tokens = list(
      list(name = "USDC", index = 0, szDecimals = 8),
      list(name = "PURR", index = 1, szDecimals = 0)
    ),
    universe = list(
      list(name = "PURR/USDC", tokens = list(1, 0), index = 0, isCanonical = TRUE)
    )
  )
  client$.__enclos_env__$private$.meta_cache <- build_asset_maps(meta, spot_meta)
  return(invisible(client))
}

test_that("HyperliquidMarketData public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  market <- HyperliquidMarketData$new(keys = .keys)

  start <- lubridate::now("UTC") - lubridate::days(1)
  end <- lubridate::now("UTC")

  expect_true(data.table::is.data.table(market$get_meta()))
  expect_true(data.table::is.data.table(market$get_spot_meta()))
  expect_true(data.table::is.data.table(market$get_spot_tokens()))
  expect_true(data.table::is.data.table(market$get_meta_and_asset_ctxs()))
  expect_true(data.table::is.data.table(market$get_spot_meta_and_asset_ctxs()))
  expect_true(data.table::is.data.table(market$get_all_mids()))
  expect_true(data.table::is.data.table(market$get_l2_book("BTC")))
  expect_true(data.table::is.data.table(market$get_candles("BTC", interval = "1h", start = start, end = end)))
  expect_true(data.table::is.data.table(market$get_funding_history("BTC", start = start)))
  expect_true(data.table::is.data.table(market$get_predicted_fundings()))
  expect_true(data.table::is.data.table(market$get_perp_dexs()))
  expect_true(data.table::is.data.table(market$get_recent_trades("BTC")))
  expect_equal(nrow(market$get_exchange_status()), 1L)
})

test_that("HyperliquidAccount public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  account <- HyperliquidAccount$new(keys = .keys)

  start <- lubridate::now("UTC") - lubridate::days(1)

  expect_true(data.table::is.data.table(account$get_positions(.addr)))
  expect_equal(nrow(account$get_margin_summary(.addr)), 1L)
  expect_true(data.table::is.data.table(account$get_spot_balances(.addr)))
  expect_true(data.table::is.data.table(account$get_open_orders(.addr)))
  expect_true(data.table::is.data.table(account$get_frontend_open_orders(.addr)))
  expect_true(data.table::is.data.table(account$get_user_fills(.addr)))
  expect_true(data.table::is.data.table(account$get_user_fills_by_time(.addr, start = start)))
  expect_true(data.table::is.data.table(account$get_historical_orders(.addr)))
  expect_true(data.table::is.data.table(account$get_user_funding(.addr, start = start)))
  expect_true(data.table::is.data.table(account$get_user_non_funding_ledger_updates(.addr, start = start)))
  expect_true(data.table::is.data.table(account$get_portfolio(.addr)))
  expect_true(data.table::is.data.table(account$get_portfolio_volume(.addr)))
  expect_equal(nrow(account$get_user_fees(.addr)), 1L)
  expect_true(data.table::is.data.table(account$get_user_volume(.addr)))
  expect_equal(nrow(account$get_user_rate_limit(.addr)), 1L)
  expect_equal(nrow(account$get_user_role(.addr)), 1L)
  expect_true(data.table::is.data.table(account$get_sub_accounts(.addr)))
  expect_true(data.table::is.data.table(account$get_order_status(.addr, oid_or_cloid = 461291857943)))
  expect_true(data.table::is.data.table(account$get_user_vault_equities(.addr)))
})

test_that("HyperliquidTrading public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  trading <- HyperliquidTrading$new(keys = .keys)
  seed_meta(trading)

  gtc <- list(limit = list(tif = "Gtc"))
  order <- list(coin = "BTC", is_buy = TRUE, sz = 0.001, limit_px = 50000, order_type = gtc, reduce_only = FALSE)

  expect_true(data.table::is.data.table(trading$place_order("BTC", TRUE, 0.001, 50000, gtc)))
  expect_true(data.table::is.data.table(trading$bulk_orders(list(order))))
  expect_true(data.table::is.data.table(trading$market_open("BTC", is_buy = TRUE, sz = 0.001)))
  expect_true(data.table::is.data.table(trading$market_close("BTC")))
  expect_true(data.table::is.data.table(trading$modify_order(123, "BTC", TRUE, 0.002, 49000, gtc)))
  expect_true(data.table::is.data.table(trading$bulk_modify(list(list(oid = 123, order = order)))))
  expect_true(data.table::is.data.table(trading$cancel_order("BTC", oid = 123)))
  expect_true(data.table::is.data.table(trading$bulk_cancel(list(list(coin = "BTC", oid = 123)))))
  expect_true(data.table::is.data.table(trading$cancel_by_cloid("BTC", cloid = new_cloid())))
  expect_true(data.table::is.data.table(trading$bulk_cancel_by_cloid(list(list(coin = "BTC", cloid = new_cloid())))))
  expect_equal(nrow(trading$schedule_cancel(lubridate::now("UTC") + lubridate::seconds(60))), 1L)
  expect_equal(nrow(trading$update_leverage("BTC", leverage = 5)), 1L)
  expect_equal(nrow(trading$update_isolated_margin("BTC", amount = 12.5)), 1L)

  agent <- trading$approve_agent("bot")
  expect_true(data.table::is.data.table(agent))
  expect_equal(names(agent), c("agent_address", "agent_key", "status"))

  expect_equal(nrow(trading$approve_builder_fee(.dest, "0.001%")), 1L)
})

test_that("HyperliquidTransfers public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  transfers <- HyperliquidTransfers$new(keys = .keys)

  expect_equal(nrow(transfers$usd_class_transfer(100, to_perp = TRUE)), 1L)
  expect_equal(nrow(transfers$usd_send(25, .dest)), 1L)
  expect_equal(nrow(transfers$spot_send(25, .dest, token = .token)), 1L)
  expect_equal(nrow(transfers$withdraw(25, .dest)), 1L)
  expect_equal(nrow(transfers$send_asset(.dest, source_dex = "", destination_dex = "spot", token = .token, amount = 10)), 1L)
  expect_equal(nrow(transfers$sub_account_transfer(.dest, is_deposit = TRUE, usd = 100)), 1L)
  expect_equal(nrow(transfers$sub_account_spot_transfer(.dest, is_deposit = TRUE, token = .token, amount = 10)), 1L)
  expect_equal(nrow(transfers$vault_transfer(.dest, is_deposit = TRUE, usd = 100)), 1L)
})

test_that("HyperliquidStaking public methods round-trip through the router", {
  old <- options(httr2_mock = mock_router)
  on.exit(options(old), add = TRUE)
  staking <- HyperliquidStaking$new(keys = .keys)

  expect_equal(nrow(staking$get_staking_summary(.validator)), 1L)
  expect_true(data.table::is.data.table(staking$get_staking_delegations(.validator)))
  expect_true(data.table::is.data.table(staking$get_staking_rewards(.validator)))
  expect_true(data.table::is.data.table(staking$get_delegator_history(.validator)))
  expect_equal(nrow(staking$token_delegate(validator = .validator, wei = 100, is_undelegate = FALSE)), 1L)
})
