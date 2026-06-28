# Guards the typed-empty invariant: every endpoint parser's empty branch must
# return a zero-row data.table that still carries its full typed column set (and
# no list column), never a column-less `data.table()`. That column-less empty is
# what silently violated the methods' `assert_has_columns` @return contracts on a
# flat account / empty book / quiet window. Most empties are inlined at their
# single branch; the two shapes reused across more than one parser/fetcher
# (candles, funding history) are the only extracted `empty_dt_*` constructors.

test_that("the two reused typed-empty constructors return zero-row typed tables", {
  expect_named(
    empty_dt_candles(),
    c("datetime", "open", "high", "low", "close", "volume", "trades", "close_time", "interval", "coin")
  )
  expect_named(empty_dt_funding_history(), c("coin", "funding_rate", "premium", "time"))
  for (dt in list(empty_dt_candles(), empty_dt_funding_history())) {
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L)
  }
})

test_that("every endpoint parser returns a typed zero-row empty, never column-less", {
  # (parser, empty input) for every endpoint parser, across all four domains and
  # both the previously column-less and the previously inline-typed branches.
  # The positional-pair parsers need a two-element `[meta, ctxs]` shell.
  cases <- list(
    positions = list(parse_positions, list()),
    margin_summary = list(parse_margin_summary, list()),
    spot_balances = list(parse_spot_balances, list()),
    open_orders = list(parse_open_orders, NULL),
    frontend_open_orders = list(parse_frontend_open_orders, NULL),
    user_fills = list(parse_user_fills, NULL),
    historical_orders = list(parse_historical_orders, NULL),
    user_funding = list(parse_user_funding, NULL),
    non_funding_ledger = list(parse_non_funding_ledger, NULL),
    portfolio = list(parse_portfolio, NULL),
    portfolio_volume = list(parse_portfolio_volume, NULL),
    user_fees = list(parse_user_fees, list()),
    user_volume = list(parse_user_volume, list()),
    user_rate_limit = list(parse_user_rate_limit, list()),
    user_role = list(parse_user_role, list()),
    sub_accounts = list(parse_sub_accounts, NULL),
    order_status = list(parse_order_status, NULL),
    user_vault_equities = list(parse_user_vault_equities, NULL),
    meta = list(parse_meta, list()),
    spot_meta_universe = list(parse_spot_meta_universe, list()),
    spot_tokens = list(parse_spot_tokens, list()),
    meta_and_asset_ctxs = list(parse_meta_and_asset_ctxs, list(list(universe = list()), list())),
    spot_meta_and_asset_ctxs = list(parse_spot_meta_and_asset_ctxs, list(list(), list())),
    all_mids = list(parse_all_mids, NULL),
    l2_book = list(parse_l2_book, list()),
    candles = list(parse_candles, NULL),
    funding_history = list(parse_funding_history, NULL),
    predicted_fundings = list(parse_predicted_fundings, NULL),
    perp_dexs = list(parse_perp_dexs, NULL),
    recent_trades = list(parse_recent_trades, NULL),
    exchange_status = list(parse_exchange_status, NULL),
    staking_summary = list(parse_staking_summary, NULL),
    staking_delegations = list(parse_staking_delegations, NULL),
    staking_rewards = list(parse_staking_rewards, NULL),
    delegator_history = list(parse_delegator_history, NULL),
    token_delegate = list(parse_token_delegate, NULL),
    transfer_ack = list(parse_transfer_ack, NULL)
  )

  for (nm in names(cases)) {
    parser <- cases[[nm]][[1L]]
    dt <- parser(cases[[nm]][[2L]])
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    expect_true(ncol(dt) > 0L, label = paste(nm, "column count"))
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste(nm, "list column"))
  }
})

test_that("order parsers build the same schema empty as populated (setcolorder drift guard)", {
  # frontendOpenOrders / historicalOrders / orderStatus derive their empty schema
  # from flatten_order(NULL)[0L] and then setcolorder() with an explicit column
  # list, exactly as the populated path does. data.table::setcolorder() appends
  # any column not named in that list, so a new flatten_order() field flows through
  # both paths identically -- but only while neither path's transform drifts from
  # the other. This pins that: empty and populated output must agree on column
  # names, order, and types, for every order parser whose empty reuses flatten_order.
  ord <- list(
    coin = "BTC",
    oid = 1,
    side = "B",
    limitPx = "100",
    sz = "1",
    origSz = "2",
    orderType = "Limit",
    tif = "Gtc",
    reduceOnly = FALSE,
    triggerPx = "0",
    triggerCondition = "N/A",
    isTrigger = FALSE,
    isPositionTpsl = FALSE,
    cloid = "0xabc",
    timestamp = 1700000000000
  )
  cases <- list(
    frontend_open_orders = list(parse_frontend_open_orders, list(ord)),
    historical_orders = list(
      parse_historical_orders,
      list(list(order = ord, status = "filled", statusTimestamp = 1700000001000))
    ),
    order_status = list(
      parse_order_status,
      list(status = "order", order = list(status = "filled", order = ord, statusTimestamp = 1700000001000))
    )
  )
  for (nm in names(cases)) {
    parser <- cases[[nm]][[1L]]
    populated <- parser(cases[[nm]][[2L]])
    empty <- parser(NULL)
    expect_identical(nrow(populated), 1L, label = paste(nm, "populated row count"))
    expect_identical(nrow(empty), 0L, label = paste(nm, "empty row count"))
    expect_identical(names(empty), names(populated), label = paste(nm, "column names and order"))
    expect_identical(
      vapply(empty, function(x) class(x)[1L], ""),
      vapply(populated, function(x) class(x)[1L], ""),
      label = paste(nm, "column types")
    )
  }
})
