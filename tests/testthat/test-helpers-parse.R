# Generic response-flattening helpers (R/helpers_parse.R). Internal (unexported)
# functions are reached via hyperliquid:::fn.

# ---- as_dt_row: the no-list-column guarantee ---------------------------------

test_that("as_dt_row collapses nested structures and never yields list columns", {
  row <- hyperliquid:::as_dt_row(list(
    coin = "BTC",
    szDecimals = 5,
    ctx = list(a = 1, b = 2),
    arr = list(1, 2, 3),
    missing = NULL
  ))
  expect_s3_class(row, "data.table")
  expect_equal(nrow(row), 1L)
  # The core contract: no column is a list column.
  expect_false(any(vapply(row, is.list, logical(1))))
  # camelCase field name is snake_cased.
  expect_true("sz_decimals" %in% names(row))
  # Nested object and multi-element array each collapse to one JSON string.
  expect_type(row$ctx, "character")
  expect_match(row$ctx, "\"a\"")
  expect_equal(row$arr, "[1,2,3]")
  # NULL field becomes NA.
  expect_true(is.na(row$missing))
})

test_that("as_dt_row returns a zero-row data.table for NULL or empty input", {
  expect_equal(nrow(hyperliquid:::as_dt_row(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::as_dt_row(list())), 0L)
})

# ---- num_or_na ---------------------------------------------------------------

test_that("num_or_na parses numeric strings and maps blank/NULL to NA", {
  expect_identical(hyperliquid:::num_or_na("123.45"), 123.45)
  expect_identical(hyperliquid:::num_or_na("1e3"), 1000)
  expect_identical(hyperliquid:::num_or_na(""), NA_real_)
  expect_identical(hyperliquid:::num_or_na(NULL), NA_real_)
  expect_identical(hyperliquid:::num_or_na(list()), NA_real_)
})

# ---- to_snake_case -----------------------------------------------------------

test_that("to_snake_case converts camelCase Hyperliquid field names", {
  expect_equal(
    hyperliquid:::to_snake_case(c("szDecimals", "marginTableId", "coin", "openInterest")),
    c("sz_decimals", "margin_table_id", "coin", "open_interest")
  )
})

# ---- parse_delta_ledger: discriminator-stacking ------------------------------

test_that("parse_delta_ledger stacks discriminated {time, hash, delta} rows", {
  items <- list(
    list(
      time = 1700000000000,
      hash = "0xabc",
      delta = list(type = "deposit", usdc = "100.5")
    ),
    list(
      time = 1700000001000,
      hash = "0xdef",
      delta = list(type = "accountClassTransfer", usdc = "50", toPerp = TRUE)
    )
  )
  dt <- hyperliquid:::parse_delta_ledger(items)
  expect_s3_class(dt, "data.table")
  expect_equal(nrow(dt), 2L)
  # Discriminator column plus meta and the union of delta fields are present.
  expect_true(all(c("time", "hash", "type", "usdc", "to_perp") %in% names(dt)))
  expect_equal(dt$type, c("deposit", "accountClassTransfer"))
  # fill = TRUE: a field absent from the first variant is NA in that row.
  expect_true(is.na(dt$to_perp[1]))
  # Time is converted from epoch ms to POSIXct, no list columns survive.
  expect_s3_class(dt$time, "POSIXct")
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_delta_ledger returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_delta_ledger(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_delta_ledger(list())), 0L)
})
