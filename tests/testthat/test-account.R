# Offline tests for HyperliquidAccount: every user-scoped /info parser against
# its captured fixture (columns, types, no list columns, zero-row on empty),
# plus end-to-end reads through a mocked transport asserting the posted body
# carries the right `type` discriminator and `user` address. Account reads are
# unauthenticated, so no signing is exercised here.

source(testthat::test_path("fixtures-account.R"))

# ---- test helpers ------------------------------------------------------------

# Build an httr2 response from a fixture value (mirrors the live JSON body).
hl_acct_response <- function(data, status = 200L) {
  body <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = status,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(body))
  ))
}

# Decode the JSON body of a built httr2 request back to an R list.
hl_acct_req_body <- function(req) {
  data <- req$body$data
  if (is.raw(data)) {
    data <- rawToChar(data)
  }
  return(jsonlite::fromJSON(as.character(data), simplifyVector = FALSE))
}

no_list_cols <- function(dt) {
  return(!any(vapply(dt, is.list, logical(1))))
}

# A read-only client (no signing key, no env warning) -- Account never signs.
read_client <- function() {
  return(hyperliquid:::HyperliquidAccount$new(
    keys = list(private_key = NULL, account_address = NULL, wallet_address = NULL)
  ))
}

ADDR <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"

# ---- parse_positions ---------------------------------------------------------

test_that("parse_positions returns one row per position with split leverage", {
  dt <- hyperliquid:::parse_positions(fixture_clearinghouse_state())
  expect_s3_class(dt, "data.table")
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c(
      "coin",
      "szi",
      "entry_px",
      "position_value",
      "unrealized_pnl",
      "return_on_equity",
      "leverage_type",
      "leverage_value",
      "liquidation_px",
      "margin_used"
    )
  )
  expect_equal(dt$coin, c("BTC", "ETH"))
  expect_equal(dt$szi, c(0.61148, -0.3708))
  expect_equal(dt$entry_px, c(61699.1, 1606.85))
  expect_equal(dt$leverage_type, c("cross", "cross"))
  expect_equal(dt$leverage_value, c(20, 20))
  # BTC has a null liquidationPx -> NA; ETH carries one.
  expect_true(is.na(dt$liquidation_px[1]))
  expect_equal(dt$liquidation_px[2], 7863059.5308084209)
  expect_type(dt$szi, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_positions returns a zero-row data.table when empty", {
  empty <- hyperliquid:::parse_positions(fixture_clearinghouse_state_empty())
  expect_equal(nrow(empty), 0L)
  # A flat account is a routine live response: the typed zero-row schema must
  # still carry every contracted column so the @return contract holds.
  expect_equal(
    names(empty),
    c("coin", "szi", "entry_px", "position_value", "unrealized_pnl",
      "return_on_equity", "leverage_type", "leverage_value", "liquidation_px",
      "margin_used")
  )
  expect_silent(hyperliquid:::assert_return_HyperliquidAccount__get_positions(empty))
  expect_equal(nrow(hyperliquid:::parse_positions(NULL)), 0L)
})

# ---- parse_margin_summary ----------------------------------------------------

test_that("parse_margin_summary flattens the summary to one typed row", {
  dt <- hyperliquid:::parse_margin_summary(fixture_clearinghouse_state())
  expect_equal(nrow(dt), 1L)
  expect_equal(
    names(dt),
    c(
      "account_value",
      "total_ntl_pos",
      "total_raw_usd",
      "total_margin_used",
      "withdrawable",
      "cross_account_value",
      "cross_total_ntl_pos",
      "cross_total_raw_usd",
      "cross_total_margin_used"
    )
  )
  expect_equal(dt$account_value, 2976574.9037540001)
  expect_equal(dt$total_margin_used, 161989.260803)
  expect_equal(dt$withdrawable, 2652596.3820770001)
  expect_equal(dt$cross_account_value, 2976574.9037540001)
  expect_type(dt$account_value, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_margin_summary returns zeros on the empty fixture, zero-row on NULL", {
  dt <- hyperliquid:::parse_margin_summary(fixture_clearinghouse_state_empty())
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$account_value, 0)
  # An address that never deposited returns an empty clearinghouseState: the
  # typed zero-row schema must still satisfy the @return contract.
  empty <- hyperliquid:::parse_margin_summary(NULL)
  expect_equal(nrow(empty), 0L)
  expect_silent(hyperliquid:::assert_return_HyperliquidAccount__get_margin_summary(empty))
})

# ---- parse_spot_balances -----------------------------------------------------

test_that("parse_spot_balances returns one row per balance", {
  dt <- hyperliquid:::parse_spot_balances(fixture_spot_balances())
  expect_equal(nrow(dt), 3L)
  expect_equal(names(dt), c("coin", "total", "hold", "entry_ntl"))
  expect_equal(dt$coin, c("USDC", "PURR", "HFUN"))
  expect_equal(dt$total, c(13967.93682455, 0, 0))
  expect_equal(dt$hold, c(-5.92201599, 0, 0))
  expect_type(dt$total, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_spot_balances returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_spot_balances(fixture_spot_balances_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_spot_balances(NULL)), 0L)
})

# ---- parse_open_orders -------------------------------------------------------

test_that("parse_open_orders maps the wire side and POSIXct timestamp", {
  dt <- hyperliquid:::parse_open_orders(fixture_open_orders())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("coin", "oid", "side", "limit_px", "sz", "timestamp"))
  expect_equal(dt$coin, c("MERL", "AERO"))
  expect_equal(dt$side, c("buy", "sell"))
  expect_equal(dt$oid, c(461291857939, 461291857943))
  expect_equal(dt$limit_px, c(0.020781, 0.33001))
  expect_s3_class(dt$timestamp, "POSIXct")
  expect_type(dt$oid, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_open_orders returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_open_orders(fixture_open_orders_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_open_orders(NULL)), 0L)
})

# ---- parse_frontend_open_orders ----------------------------------------------

test_that("parse_frontend_open_orders adds detail columns and drops children/cloid", {
  dt <- hyperliquid:::parse_frontend_open_orders(fixture_frontend_open_orders())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c(
      "coin",
      "oid",
      "side",
      "limit_px",
      "sz",
      "timestamp",
      "order_type",
      "is_trigger",
      "trigger_px",
      "trigger_condition",
      "reduce_only",
      "tif",
      "orig_sz",
      "is_position_tpsl"
    )
  )
  expect_false("children" %in% names(dt))
  expect_false("cloid" %in% names(dt))
  expect_equal(dt$coin, c("SOL", "ETH"))
  expect_equal(dt$side, c("sell", "sell"))
  expect_equal(dt$order_type, c("Limit", "Limit"))
  expect_equal(dt$tif, c("Alo", "Alo"))
  expect_false(dt$is_trigger[1])
  expect_false(dt$reduce_only[1])
  expect_type(dt$is_trigger, "logical")
  expect_true(no_list_cols(dt))
})

test_that("parse_frontend_open_orders returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_frontend_open_orders(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_frontend_open_orders(list())), 0L)
})

# ---- parse_user_fills --------------------------------------------------------

test_that("parse_user_fills flattens fills with mapped side and POSIXct time", {
  dt <- hyperliquid:::parse_user_fills(fixture_user_fills())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c(
      "coin",
      "px",
      "sz",
      "side",
      "time",
      "start_position",
      "dir",
      "closed_pnl",
      "hash",
      "oid",
      "crossed",
      "fee",
      "fee_token",
      "tid"
    )
  )
  expect_equal(dt$coin, c("IOTA", "PENDLE"))
  expect_equal(dt$side, c("buy", "sell"))
  expect_equal(dt$dir, c("Open Long", "Open Short"))
  expect_equal(dt$crossed, c(TRUE, FALSE))
  expect_equal(dt$fee_token, c("USDC", "USDC"))
  expect_s3_class(dt$time, "POSIXct")
  expect_type(dt$tid, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_fills handles the by-time payload and the empty case", {
  dt <- hyperliquid:::parse_user_fills(fixture_user_fills_by_time())
  expect_equal(nrow(dt), 2L)
  expect_equal(dt$coin, c("SKR", "PURR"))
  expect_equal(dt$closed_pnl, c(0, -0.542685))
  # An account that never traded returns an empty fills array: the typed
  # zero-row schema must still satisfy the @return contract.
  empty <- hyperliquid:::parse_user_fills(fixture_user_fills_empty())
  expect_equal(nrow(empty), 0L)
  expect_silent(hyperliquid:::assert_return_HyperliquidAccount__get_user_fills(empty))
  expect_equal(nrow(hyperliquid:::parse_user_fills(NULL)), 0L)
})

# ---- parse_historical_orders -------------------------------------------------

test_that("parse_historical_orders emits one row per status transition (no dedup)", {
  dt <- hyperliquid:::parse_historical_orders(fixture_historical_orders())
  expect_equal(nrow(dt), 3L)
  expect_equal(
    names(dt),
    c(
      "oid",
      "coin",
      "side",
      "limit_px",
      "sz",
      "orig_sz",
      "order_type",
      "tif",
      "reduce_only",
      "trigger_px",
      "trigger_condition",
      "is_trigger",
      "is_position_tpsl",
      "cloid",
      "timestamp",
      "status",
      "status_timestamp"
    )
  )
  # The STRK oid recurs across canceled then open -- not deduplicated.
  expect_equal(dt$oid, c(461291892194, 461291892194, 461291888494))
  expect_equal(dt$status, c("canceled", "open", "filled"))
  expect_equal(dt$coin, c("STRK", "STRK", "IOTA"))
  expect_equal(dt$side, c("buy", "buy", "buy"))
  expect_true(all(is.na(dt$cloid)))
  expect_s3_class(dt$timestamp, "POSIXct")
  expect_s3_class(dt$status_timestamp, "POSIXct")
  expect_true(no_list_cols(dt))
})

test_that("parse_historical_orders returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_historical_orders(fixture_historical_orders_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_historical_orders(NULL)), 0L)
})

# ---- parse_user_funding ------------------------------------------------------

test_that("parse_user_funding lifts the funding delta into top-level columns", {
  dt <- hyperliquid:::parse_user_funding(fixture_user_funding())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c("time", "hash", "coin", "funding_rate", "szi", "usdc", "n_samples")
  )
  expect_equal(dt$coin, c("AAVE", "ACE"))
  expect_equal(dt$funding_rate, c(0.00004551, 0.0000125))
  expect_equal(dt$usdc, c(148.912547, 26.873315))
  expect_equal(dt$n_samples, c(24, 24))
  expect_s3_class(dt$time, "POSIXct")
  expect_type(dt$funding_rate, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_funding returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_user_funding(fixture_user_funding_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_user_funding(NULL)), 0L)
})

# ---- parse_non_funding_ledger ------------------------------------------------

test_that("parse_non_funding_ledger stacks variants under a delta_type discriminator", {
  dt <- hyperliquid:::parse_non_funding_ledger(fixture_non_funding_ledger())
  expect_equal(nrow(dt), 6L)
  expect_equal(names(dt)[1:4], c("time", "hash", "delta_type", "usdc"))
  expect_equal(
    dt$delta_type,
    c("deposit", "withdraw", "accountClassTransfer", "spotTransfer", "vaultDeposit", "liquidation")
  )
  expect_equal(dt$usdc[1], 1000)
  # spotTransfer carries an amount but no usdc.
  expect_true(is.na(dt$usdc[4]))
  expect_true("amount" %in% names(dt))
  # The liquidation's nested liquidatedPositions collapses to a JSON string.
  expect_true("liquidated_positions" %in% names(dt))
  expect_type(dt$liquidated_positions, "character")
  expect_s3_class(dt$time, "POSIXct")
  expect_true(no_list_cols(dt))
})

test_that("parse_non_funding_ledger returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_non_funding_ledger(fixture_non_funding_ledger_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_non_funding_ledger(NULL)), 0L)
})

# ---- parse_portfolio ---------------------------------------------------------

test_that("parse_portfolio melts value and pnl histories long", {
  dt <- hyperliquid:::parse_portfolio(fixture_portfolio())
  # 2 periods x 2 metrics x 2 points each.
  expect_equal(nrow(dt), 8L)
  expect_equal(names(dt), c("period", "metric", "time", "value"))
  expect_equal(unique(dt$period), c("day", "perpAllTime"))
  expect_equal(unique(dt$metric), c("account_value", "pnl"))
  expect_s3_class(dt$time, "POSIXct")
  expect_equal(dt$value[1], 337097050.2698649764)
  # First pnl point of the day period is 0.
  expect_equal(dt[period == "day" & metric == "pnl"]$value, c(0, 19805.730092))
  expect_type(dt$value, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_portfolio returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_portfolio(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_portfolio(list())), 0L)
})

# ---- parse_portfolio_volume --------------------------------------------------

test_that("parse_portfolio_volume returns one row per period", {
  dt <- hyperliquid:::parse_portfolio_volume(fixture_portfolio())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("period", "vlm"))
  expect_equal(dt$period, c("day", "perpAllTime"))
  expect_equal(dt$vlm, c(0, 0))
  expect_type(dt$vlm, "double")
  expect_true(no_list_cols(dt))
})

# ---- parse_user_fees ---------------------------------------------------------

test_that("parse_user_fees flattens the fee schedule to one row", {
  dt <- hyperliquid:::parse_user_fees(fixture_user_fees())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("user_add_rate", "user_cross_rate", "active_referral_discount"))
  expect_equal(dt$user_add_rate, 0)
  expect_equal(dt$user_cross_rate, 0.00028)
  expect_equal(dt$active_referral_discount, 0)
  expect_type(dt$user_cross_rate, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_fees returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_user_fees(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_user_fees(list())), 0L)
})

# ---- parse_user_volume -------------------------------------------------------

test_that("parse_user_volume returns one row per day from dailyUserVlm", {
  dt <- hyperliquid:::parse_user_volume(fixture_user_fees())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("date", "exchange", "user_add", "user_cross"))
  expect_equal(dt$date, c("2026-05-24", "2026-05-25"))
  expect_equal(dt$user_cross, c(7824407.5, 8038495.5700000003))
  expect_type(dt$exchange, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_volume returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_user_volume(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_user_volume(list())), 0L)
})

# ---- parse_user_rate_limit ---------------------------------------------------

test_that("parse_user_rate_limit flattens the rate-limit state", {
  dt <- hyperliquid:::parse_user_rate_limit(fixture_user_rate_limit())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("cum_vlm", "n_requests_used", "n_requests_cap"))
  expect_equal(dt$cum_vlm, 190895644047.9899902344)
  expect_equal(dt$n_requests_used, 51346860978)
  expect_equal(dt$n_requests_cap, 190895654047)
  expect_type(dt$cum_vlm, "double")
  expect_true(no_list_cols(dt))
})

# ---- parse_user_role ---------------------------------------------------------

test_that("parse_user_role returns the role in one row", {
  dt <- hyperliquid:::parse_user_role(fixture_user_role())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), "role")
  expect_equal(dt$role, "vault")
  expect_type(dt$role, "character")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_role returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_user_role(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_user_role(list())), 0L)
})

# ---- parse_sub_accounts ------------------------------------------------------

test_that("parse_sub_accounts flattens the per-sub-account summary", {
  dt <- hyperliquid:::parse_sub_accounts(fixture_sub_accounts())
  expect_equal(nrow(dt), 2L)
  expect_equal(
    names(dt),
    c(
      "name",
      "sub_account_user",
      "master",
      "account_value",
      "total_ntl_pos",
      "total_raw_usd",
      "total_margin_used",
      "withdrawable"
    )
  )
  expect_equal(dt$name, c("hyperliquid_1s2", "hyperliquid_1s3"))
  expect_equal(dt$sub_account_user[1], "0x4cd2393c90a4e769972a9862540492b4bc19695c")
  expect_equal(dt$account_value, c(50041.813241, 4581524.7700629998))
  expect_equal(dt$withdrawable[1], 49985.412996)
  expect_type(dt$account_value, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_sub_accounts returns a zero-row data.table when null/empty", {
  expect_equal(nrow(hyperliquid:::parse_sub_accounts(fixture_sub_accounts_null())), 0L)
  expect_equal(nrow(hyperliquid:::parse_sub_accounts(list())), 0L)
})

# ---- parse_order_status ------------------------------------------------------

test_that("parse_order_status flattens a found order to one row", {
  dt <- hyperliquid:::parse_order_status(fixture_order_status())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt)[1], "query_status")
  expect_true(all(c("oid", "coin", "side", "status", "status_timestamp") %in% names(dt)))
  expect_equal(dt$query_status, "order")
  expect_equal(dt$coin, "AERO")
  expect_equal(dt$side, "sell")
  expect_equal(dt$status, "canceled")
  expect_s3_class(dt$status_timestamp, "POSIXct")
  expect_true(no_list_cols(dt))
})

test_that("parse_order_status returns one all-NA row for an unknown oid", {
  dt <- hyperliquid:::parse_order_status(fixture_order_status_unknown())
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$query_status, "unknownOid")
  expect_true(is.na(dt$oid))
  expect_true(is.na(dt$coin))
  expect_true(is.na(dt$status))
  expect_true(no_list_cols(dt))
})

test_that("parse_order_status returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_order_status(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_order_status(list())), 0L)
})

# ---- parse_user_vault_equities -----------------------------------------------

test_that("parse_user_vault_equities returns one row per vault", {
  dt <- hyperliquid:::parse_user_vault_equities(fixture_user_vault_equities())
  expect_equal(nrow(dt), 2L)
  expect_equal(names(dt), c("vault_address", "equity", "locked_until_timestamp"))
  expect_equal(dt$vault_address[1], "0x010461c14e146ac35fe42271bdc1134ee31c703a")
  expect_equal(dt$equity, c(2977223.0296200002, 999999.999999))
  expect_s3_class(dt$locked_until_timestamp, "POSIXct")
  expect_type(dt$equity, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_user_vault_equities returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_user_vault_equities(fixture_user_vault_equities_empty())), 0L)
  expect_equal(nrow(hyperliquid:::parse_user_vault_equities(NULL)), 0L)
})

# ---- end-to-end reads through a mocked transport -----------------------------

test_that("get_positions posts clearinghouseState with the user and parses positions", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_acct_req_body(req)
    seen$url <- req$url
    return(hl_acct_response(fixture_clearinghouse_state()))
  })

  client <- read_client()
  dt <- client$get_positions(ADDR)

  expect_match(seen$url, "/info", fixed = TRUE)
  expect_equal(seen$body$type, "clearinghouseState")
  expect_equal(seen$body$user, ADDR)
  expect_equal(nrow(dt), 2L)
  expect_equal(dt$coin, c("BTC", "ETH"))
  expect_true(no_list_cols(dt))
})

test_that("get_margin_summary reads the same payload as a sibling method", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_acct_req_body(req)
    return(hl_acct_response(fixture_clearinghouse_state()))
  })

  client <- read_client()
  dt <- client$get_margin_summary(ADDR)

  expect_equal(seen$body$type, "clearinghouseState")
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$account_value, 2976574.9037540001)
  expect_true(no_list_cols(dt))
})

test_that("get_user_fills_by_time posts the time bounds and aggregate flag", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_acct_req_body(req)
    return(hl_acct_response(fixture_user_fills_by_time()))
  })

  client <- read_client()
  dt <- client$get_user_fills_by_time(
    ADDR,
    start = lubridate::as_datetime("2026-06-06 00:00:00", tz = "UTC"),
    end = lubridate::as_datetime("2026-06-06 02:00:00", tz = "UTC"),
    aggregate_by_time = TRUE
  )

  expect_equal(seen$body$type, "userFillsByTime")
  expect_equal(seen$body$user, ADDR)
  expect_true(is.numeric(seen$body$startTime))
  expect_true(is.numeric(seen$body$endTime))
  expect_true(seen$body$aggregateByTime)
  expect_equal(nrow(dt), 2L)
  expect_true(no_list_cols(dt))
})

test_that("get_user_funding accepts raw epoch-ms bounds and omits end when NULL", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_acct_req_body(req)
    return(hl_acct_response(fixture_user_funding()))
  })

  client <- read_client()
  dt <- client$get_user_funding(ADDR, start = 1735689600000)

  expect_equal(seen$body$type, "userFunding")
  expect_equal(seen$body$startTime, 1735689600000)
  expect_null(seen$body$endTime)
  expect_equal(nrow(dt), 2L)
  expect_equal(dt$coin, c("AAVE", "ACE"))
  expect_true(no_list_cols(dt))
})

test_that("get_order_status posts the oid and parses the status", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_acct_req_body(req)
    return(hl_acct_response(fixture_order_status()))
  })

  client <- read_client()
  dt <- client$get_order_status(ADDR, 461291857943)

  expect_equal(seen$body$type, "orderStatus")
  expect_equal(seen$body$user, ADDR)
  expect_equal(seen$body$oid, 461291857943)
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$status, "canceled")
  expect_true(no_list_cols(dt))
})

test_that("get_sub_accounts handles the null response as a zero-row table", {
  httr2::local_mocked_responses(function(req) {
    return(hl_acct_response(fixture_sub_accounts_null()))
  })

  client <- read_client()
  dt <- client$get_sub_accounts(ADDR)

  expect_equal(nrow(dt), 0L)
  expect_true(no_list_cols(dt))
})

# ---- input validation --------------------------------------------------------

test_that("account reads validate the address", {
  client <- read_client()
  expect_error(client$get_positions("nope"))
  expect_error(client$get_user_role(""))
})

test_that("get_order_status rejects a non-scalar order id", {
  client <- read_client()
  expect_error(client$get_order_status(ADDR, c(1, 2)))
})
