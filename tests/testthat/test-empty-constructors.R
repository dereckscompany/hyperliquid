# Guards the typed-empty-constructor convention (R/helpers_parse.R): every
# `empty_dt_*()` must return a zero-row data.table that still carries its full
# typed column set, and every endpoint parser must route its empty branch
# through one. This is the invariant that the column-less `data.table()[]`
# empties (which silently violated the methods' `assert_has_columns` @return
# contracts on a flat account / empty book / quiet window) used to break.

test_that("every empty_dt_* constructor returns a typed zero-row data.table, never column-less", {
  ns <- asNamespace("hyperliquid")
  ctors <- ls(ns, pattern = "^empty_dt_")
  # Sanity: the whole family is discovered (account + market-data + staking +
  # transfers), not an empty/partial sweep.
  expect_gt(length(ctors), 30L)

  for (nm in ctors) {
    dt <- get(nm, envir = ns)()
    expect_s3_class(dt, "data.table")
    expect_identical(nrow(dt), 0L, label = nm)
    # The bug this guards: an empty branch must still carry its columns.
    expect_true(ncol(dt) > 0L, label = paste0(nm, " column count"))
    # The package's flat-table contract: no list columns, ever.
    expect_false(any(vapply(dt, is.list, logical(1L))), label = paste0(nm, " has a list column"))
  }
})

test_that("endpoint parsers route their empty branch through the matching constructor", {
  # A representative spread across the domains and across both the previously
  # column-less (loose-contract) and previously inline-typed (strict-contract)
  # parsers, proving the empty output now equals the documented zero-row schema.
  expect_identical(parse_spot_balances(NULL), empty_dt_spot_balances())
  expect_identical(parse_open_orders(NULL), empty_dt_open_orders())
  expect_identical(parse_user_role(NULL), empty_dt_user_role())
  expect_identical(parse_positions(list()), empty_dt_positions())
  expect_identical(parse_meta(list()), empty_dt_meta())
  expect_identical(parse_all_mids(NULL), empty_dt_all_mids())
  expect_identical(parse_staking_delegations(NULL), empty_dt_staking_delegations())
  expect_identical(parse_transfer_ack(NULL), empty_dt_transfer_ack())
})
