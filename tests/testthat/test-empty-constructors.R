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
