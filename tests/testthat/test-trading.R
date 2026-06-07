# Offline tests for HyperliquidTrading: the order/cancel/default parsers, and
# end-to-end signed writes through a mocked transport asserting the posted action
# type, the order-wire keys, the {r,s,v} signature, micro-USD scaling, and the
# market_* read-then-write chains. The meta cache is pre-seeded so name_to_asset
# resolves without any network. sign.R is already vector-tested, so structural
# correctness of the posted body is enough here.

source(testthat::test_path("fixtures-trading.R"))

# ---- shared helpers ----------------------------------------------------------

# A throwaway signing key (the python SDK test scalar).
priv_hex <- "0123456789012345678901234567890123456789012345678901234567890123"

mk_resp <- function(data) {
  return(httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")))
  ))
}

decode_body <- function(req) {
  raw_body <- req$body$data
  body_txt <- if (is.raw(raw_body)) rawToChar(raw_body) else as.character(raw_body)
  return(jsonlite::fromJSON(body_txt, simplifyVector = FALSE))
}

# Pre-seed a tiny meta cache: BTC (perp asset 0, szDecimals 5) and PURR/USDC
# (spot asset 10000). Built via build_asset_maps so the cache layout matches the
# live one exactly.
seed_meta <- function(client) {
  meta <- list(
    universe = list(
      list(name = "BTC", szDecimals = 5, maxLeverage = 40)
    )
  )
  spot_meta <- list(
    tokens = list(
      list(name = "USDC", index = 0, szDecimals = 8),
      list(name = "PURR", index = 1, szDecimals = 0)
    ),
    universe = list(
      list(name = "PURR/USDC", index = 0, tokens = list(1, 0), isCanonical = TRUE)
    )
  )
  client$.__enclos_env__$private$.meta_cache <- hyperliquid:::build_asset_maps(meta, spot_meta)
  return(invisible(client))
}

new_client <- function() {
  keys <- hyperliquid:::get_api_keys(private_key = paste0("0x", priv_hex))
  client <- hyperliquid:::HyperliquidTrading$new(keys = keys)
  return(seed_meta(client))
}

# Run `call_fn()` against a mock that serves /info reads (allMids,
# clearinghouseState) and records the posted /exchange write, returning `ack`.
mock_trade <- function(call_fn, ack, mids = NULL, state = NULL) {
  posted <- NULL
  httr2::local_mocked_responses(function(req) {
    body <- decode_body(req)
    if (!is.null(body$type)) {
      if (identical(body$type, "allMids")) {
        return(mk_resp(mids))
      }
      if (identical(body$type, "clearinghouseState")) {
        return(mk_resp(state))
      }
      return(mk_resp(list()))
    }
    posted <<- body
    return(mk_resp(ack))
  })
  dt <- call_fn()
  return(list(posted = posted, dt = dt))
}

expect_has_signature <- function(posted) {
  expect_true(all(c("r", "s", "v") %in% names(posted$signature)))
  expect_true(nzchar(posted$signature$r))
  expect_true(nzchar(posted$signature$s))
  expect_true(is.numeric(posted$signature$v))
}

# ---- parsers -----------------------------------------------------------------

test_that("parse_order_response flattens mixed statuses with no list columns", {
  dt <- hyperliquid:::parse_order_response(fixture_order_mixed())
  expect_s3_class(dt, "data.table")
  expect_equal(nrow(dt), 3L)
  expect_equal(names(dt), c("status", "oid", "total_sz", "avg_px", "error"))
  expect_equal(dt$status, c("resting", "filled", "error"))
  expect_equal(dt$oid, c(77738308, 77747314, NA))
  expect_equal(dt$total_sz, c(NA, 0.02, NA))
  expect_equal(dt$avg_px, c(NA, 1891.4, NA))
  expect_equal(dt$error[3], "Order must have minimum value of $10.")
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_order_response returns a zero-row table on empty input", {
  expect_equal(nrow(hyperliquid:::parse_order_response(list())), 0L)
  expect_equal(
    nrow(hyperliquid:::parse_order_response(
      list(response = list(data = list(statuses = list())))
    )),
    0L
  )
})

test_that("parse_cancel_response maps success and error rows", {
  dt <- hyperliquid:::parse_cancel_response(fixture_cancel_success())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("status", "error"))
  expect_equal(dt$status, "success")
  expect_true(is.na(dt$error))
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_action_status flattens the default ack to one row", {
  dt <- hyperliquid:::parse_action_status(fixture_action_default())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("status", "response_type"))
  expect_equal(dt$status, "ok")
  expect_equal(dt$response_type, "default")
})

# ---- place_order / bulk_orders -----------------------------------------------

test_that("place_order posts an order action with the canonical wire and a signature", {
  client <- new_client()
  res <- mock_trade(
    function() {
      client$place_order(
        "BTC",
        is_buy = TRUE,
        sz = 0.001,
        limit_px = 50000,
        order_type = list(limit = list(tif = "Gtc"))
      )
    },
    fixture_order_resting()
  )
  expect_equal(res$posted$action$type, "order")
  expect_equal(res$posted$action$grouping, "na")
  wire <- res$posted$action$orders[[1]]
  expect_equal(names(wire), c("a", "b", "p", "s", "r", "t"))
  expect_equal(wire$a, 0)
  expect_true(wire$b)
  expect_equal(wire$p, "50000")
  expect_equal(wire$s, "0.001")
  expect_false(wire$r)
  expect_equal(wire$t$limit$tif, "Gtc")
  expect_has_signature(res$posted)
  expect_equal(res$dt$status, "resting")
  expect_equal(res$dt$oid, 77738308)
})

test_that("place_order appends the cloid wire key when supplied", {
  client <- new_client()
  cloid <- "0x00000000000000000000000000000001"
  res <- mock_trade(
    function() {
      client$place_order(
        "BTC",
        is_buy = TRUE,
        sz = 0.5,
        limit_px = 50000,
        order_type = list(limit = list(tif = "Alo")),
        cloid = cloid
      )
    },
    fixture_order_resting()
  )
  wire <- res$posted$action$orders[[1]]
  expect_equal(names(wire), c("a", "b", "p", "s", "r", "t", "c"))
  expect_equal(wire$c, cloid)
  expect_equal(wire$t$limit$tif, "Alo")
})

test_that("place_order encodes a trigger order type in isMarket/triggerPx/tpsl order", {
  client <- new_client()
  res <- mock_trade(
    function() {
      client$place_order(
        "BTC",
        is_buy = FALSE,
        sz = 0.01,
        limit_px = 48000,
        order_type = list(trigger = list(triggerPx = 49000, isMarket = TRUE, tpsl = "sl")),
        reduce_only = TRUE
      )
    },
    fixture_order_resting()
  )
  wire <- res$posted$action$orders[[1]]
  expect_false(wire$b)
  expect_true(wire$r)
  expect_equal(names(wire$t$trigger), c("isMarket", "triggerPx", "tpsl"))
  expect_true(wire$t$trigger$isMarket)
  expect_equal(wire$t$trigger$triggerPx, "49000")
  expect_equal(wire$t$trigger$tpsl, "sl")
})

test_that("bulk_orders attaches a lowercased builder and stacks filled statuses", {
  client <- new_client()
  orders <- list(
    list(
      coin = "BTC",
      is_buy = TRUE,
      sz = 0.001,
      limit_px = 50000,
      order_type = list(limit = list(tif = "Gtc")),
      reduce_only = FALSE
    )
  )
  res <- mock_trade(
    function() {
      client$bulk_orders(
        orders,
        builder = list(b = "0xABCDEF0123456789012345678901234567890123", f = 10)
      )
    },
    fixture_order_filled()
  )
  expect_equal(res$posted$action$type, "order")
  expect_equal(res$posted$action$builder$b, "0xabcdef0123456789012345678901234567890123")
  expect_equal(res$posted$action$builder$f, 10)
  expect_equal(res$dt$status, "filled")
  expect_equal(res$dt$total_sz, 0.02)
  expect_equal(res$dt$avg_px, 1891.4)
})

# ---- modify ------------------------------------------------------------------

test_that("modify_order posts a batchModify with the oid and a rebuilt wire", {
  client <- new_client()
  res <- mock_trade(
    function() {
      client$modify_order(
        oid = 123,
        name = "BTC",
        is_buy = FALSE,
        sz = 0.002,
        limit_px = 51000,
        order_type = list(limit = list(tif = "Gtc"))
      )
    },
    fixture_order_resting()
  )
  expect_equal(res$posted$action$type, "batchModify")
  modify <- res$posted$action$modifies[[1]]
  expect_equal(modify$oid, 123)
  expect_equal(names(modify$order), c("a", "b", "p", "s", "r", "t"))
  expect_equal(modify$order$p, "51000")
  expect_equal(modify$order$s, "0.002")
  expect_has_signature(res$posted)
})

# ---- cancel ------------------------------------------------------------------

test_that("cancel_order posts a cancel action with asset/oid items", {
  client <- new_client()
  res <- mock_trade(
    function() client$cancel_order("BTC", oid = 555),
    fixture_cancel_success()
  )
  expect_equal(res$posted$action$type, "cancel")
  item <- res$posted$action$cancels[[1]]
  expect_equal(item$a, 0)
  expect_equal(item$o, 555)
  expect_has_signature(res$posted)
  expect_equal(res$dt$status, "success")
})

test_that("cancel_by_cloid posts a cancelByCloid action with asset/cloid items", {
  client <- new_client()
  cloid <- "0x00000000000000000000000000000009"
  res <- mock_trade(
    function() client$cancel_by_cloid("BTC", cloid),
    fixture_cancel_success()
  )
  expect_equal(res$posted$action$type, "cancelByCloid")
  item <- res$posted$action$cancels[[1]]
  expect_equal(item$asset, 0)
  expect_equal(item$cloid, cloid)
  expect_has_signature(res$posted)
})

# ---- schedule_cancel ---------------------------------------------------------

test_that("schedule_cancel posts scheduleCancel with a ms time", {
  client <- new_client()
  res <- mock_trade(
    function() client$schedule_cancel(1700000005000),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "scheduleCancel")
  expect_equal(res$posted$action$time, 1700000005000)
  expect_equal(res$dt$status, "ok")
  expect_equal(res$dt$response_type, "default")
})

test_that("schedule_cancel without a time omits the time field", {
  client <- new_client()
  res <- mock_trade(
    function() client$schedule_cancel(),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "scheduleCancel")
  expect_null(res$posted$action$time)
})

# ---- leverage / margin -------------------------------------------------------

test_that("update_leverage posts updateLeverage with asset/isCross/leverage", {
  client <- new_client()
  res <- mock_trade(
    function() client$update_leverage("BTC", leverage = 5, is_cross = TRUE),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "updateLeverage")
  expect_equal(res$posted$action$asset, 0)
  expect_true(res$posted$action$isCross)
  expect_equal(res$posted$action$leverage, 5)
  expect_has_signature(res$posted)
})

test_that("update_isolated_margin scales the amount to a micro-USD integer", {
  client <- new_client()
  res <- mock_trade(
    function() client$update_isolated_margin("BTC", amount = 12.5),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "updateIsolatedMargin")
  expect_equal(res$posted$action$asset, 0)
  expect_true(res$posted$action$isBuy)
  expect_equal(res$posted$action$ntli, 12500000)
  expect_has_signature(res$posted)
})

test_that("update_isolated_margin allows a negative amount to remove margin", {
  client <- new_client()
  res <- mock_trade(
    function() client$update_isolated_margin("BTC", amount = -12.5),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "updateIsolatedMargin")
  expect_equal(res$posted$action$ntli, -12500000)
  expect_has_signature(res$posted)
})

# ---- market_open / market_close (read-then-write chains) ---------------------

test_that("market_open reads all_mids and posts an aggressive IoC order", {
  client <- new_client()
  res <- mock_trade(
    function() client$market_open("BTC", is_buy = TRUE, sz = 0.001, slippage = 0.05),
    fixture_order_filled(),
    mids = fixture_all_mids()
  )
  expect_equal(res$posted$action$type, "order")
  wire <- res$posted$action$orders[[1]]
  expect_true(wire$b)
  expect_false(wire$r)
  expect_equal(wire$t$limit$tif, "Ioc")
  # 61958.5 * 1.05 = 65056.425 -> 5 sig figs 65056 -> round to (6-5)=1 dp -> 65056.
  expect_equal(wire$p, "65056")
})

test_that("market_close derives side and size from the open position", {
  client <- new_client()
  res <- mock_trade(
    function() client$market_close("BTC", slippage = 0.05),
    fixture_order_filled(),
    mids = fixture_all_mids(),
    state = fixture_clearinghouse_state()
  )
  expect_equal(res$posted$action$type, "order")
  wire <- res$posted$action$orders[[1]]
  expect_true(wire$b) # short position (szi < 0) -> buy to close
  expect_equal(wire$s, "0.5") # abs(szi)
  expect_true(wire$r) # reduce_only
  expect_equal(wire$t$limit$tif, "Ioc")
  expect_equal(wire$p, "65056")
})

test_that("market_close aborts when there is no open position for the coin", {
  client <- new_client()
  empty_state <- list(assetPositions = list())
  expect_error(
    mock_trade(
      function() client$market_close("BTC"),
      fixture_order_filled(),
      mids = fixture_all_mids(),
      state = empty_state
    )
  )
})

# ---- approvals (user-signed) -------------------------------------------------

test_that("approve_agent generates a fresh key, posts approveAgent, and returns the secret", {
  client <- new_client()
  res <- mock_trade(
    function() client$approve_agent("bot"),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "approveAgent")
  expect_equal(res$posted$action$agentName, "bot")
  expect_match(res$posted$action$agentAddress, "^0x[0-9a-f]{40}$")
  expect_equal(res$posted$action$signatureChainId, "0x66eee")
  expect_equal(res$posted$action$hyperliquidChain, "Mainnet")
  expect_has_signature(res$posted)
  expect_equal(names(res$dt), c("agent_address", "agent_key", "status"))
  expect_match(res$dt$agent_key, "^0x[0-9a-f]{64}$")
  expect_match(res$dt$agent_address, "^0x[0-9a-f]{40}$")
  expect_equal(res$dt$agent_address, res$posted$action$agentAddress)
  expect_equal(res$dt$status, "ok")
})

test_that("approve_agent with no name signs (and posts) an empty agentName", {
  client <- new_client()
  res <- mock_trade(
    function() client$approve_agent(),
    fixture_action_default()
  )
  expect_equal(res$posted$action$agentName, "")
  expect_has_signature(res$posted)
})

test_that("approve_builder_fee posts approveBuilderFee with the percent rate", {
  client <- new_client()
  builder <- "0xabcdef0123456789012345678901234567890123"
  res <- mock_trade(
    function() client$approve_builder_fee(builder, "0.001%"),
    fixture_action_default()
  )
  expect_equal(res$posted$action$type, "approveBuilderFee")
  expect_equal(res$posted$action$maxFeeRate, "0.001%")
  expect_equal(res$posted$action$builder, builder)
  expect_has_signature(res$posted)
  expect_equal(res$dt$status, "ok")
})

# ---- validation --------------------------------------------------------------

test_that("trading validates sizes, prices, coins, cloids, and leverage", {
  client <- new_client()
  expect_error(client$place_order("BTC", TRUE, 0, 50000, list(limit = list(tif = "Gtc"))))
  expect_error(client$place_order("BTC", TRUE, 0.1, -1, list(limit = list(tif = "Gtc"))))
  expect_error(client$place_order("", TRUE, 0.1, 50000, list(limit = list(tif = "Gtc"))))
  expect_error(client$cancel_by_cloid("BTC", "0xbad"))
  expect_error(client$update_leverage("BTC", leverage = 2.5))
  expect_error(client$update_isolated_margin("BTC", amount = 0))
})
