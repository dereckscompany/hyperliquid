# Tests for the instance-free segmented candle fetcher (R/impl_klines.R). No
# network: a synthetic .req_fn closure records the requested windows and
# synthesises candles for each, so segmentation, the 1-candle overlap dedup,
# ordering, and the single-window short-circuit are all asserted offline.

# A recording .req_fn that synthesises one candle per interval step across the
# requested [startTime, endTime] window and routes them through the real
# parse_candles parser, exactly as the impl supplies it.
make_recording_req_fn <- function(coin, interval) {
  interval_s <- hyperliquid:::hyperliquid_interval_to_seconds[[interval]]
  step_ms <- interval_s * 1000
  env <- new.env(parent = emptyenv())
  env$calls <- list()
  env$step_ms <- step_ms
  env$fn <- function(payload, .parser = identity) {
    req <- payload$req
    env$calls[[length(env$calls) + 1L]] <- req
    ts <- seq(from = req$startTime, to = req$endTime, by = step_ms)
    raw <- lapply(ts, function(t) {
      list(
        t = t, T = t + step_ms - 1, s = coin, i = interval,
        o = "100", c = "101", h = "102", l = "99", v = "10", n = 5L
      )
    })
    return(.parser(raw))
  }
  return(env)
}

# A day-aligned epoch-ms anchor keeps candle counts exact.
day_ms <- 86400000
hour_ms <- 3600000
anchor_ms <- 1700000000000 - (1700000000000 %% day_ms)

# ---- single-window short-circuit ---------------------------------------------

test_that("a range within max_candles is fetched in a single window", {
  rec <- make_recording_req_fn("BTC", "1h")
  from_ms <- anchor_ms
  to_ms <- anchor_ms + 10L * hour_ms
  dt <- hyperliquid:::hyperliquid_fetch_klines(
    coin = "BTC", interval = "1h",
    from = from_ms, to = to_ms,
    .req_fn = rec$fn, max_candles = 5000L
  )
  expect_length(rec$calls, 1L)
  expect_equal(rec$calls[[1]]$startTime, from_ms)
  expect_equal(rec$calls[[1]]$endTime, to_ms)
  # 11 hourly candles inclusive of both ends.
  expect_equal(nrow(dt), 11L)
  expect_false(is.unsorted(dt$datetime))
})

# ---- multi-window segmentation -----------------------------------------------

test_that("a range beyond max_candles is split into overlapping windows", {
  rec <- make_recording_req_fn("BTC", "1h")
  from_ms <- anchor_ms
  to_ms <- anchor_ms + 10L * hour_ms
  dt <- hyperliquid:::hyperliquid_fetch_klines(
    coin = "BTC", interval = "1h",
    from = from_ms, to = to_ms,
    .req_fn = rec$fn, max_candles = 3L
  )

  # window = 3 candles = 3h. Walking forward with a 1-candle back-up:
  # [t0,t0+3h], [t0+2h,t0+5h], [t0+4h,t0+7h], [t0+6h,t0+9h], [t0+8h,t0+10h].
  expect_length(rec$calls, 5L)

  window_ms <- 3L * hour_ms
  for (call in rec$calls) {
    expect_lte(call$endTime - call$startTime, window_ms)
  }
  # Each subsequent window starts exactly one candle before the previous end.
  for (i in seq_len(length(rec$calls) - 1L)) {
    expect_equal(rec$calls[[i + 1L]]$startTime, rec$calls[[i]]$endTime - hour_ms)
  }
  # The final window reaches `to`.
  expect_equal(rec$calls[[length(rec$calls)]]$endTime, to_ms)
})

test_that("the 1-candle overlap is deduplicated and the result is ascending", {
  rec <- make_recording_req_fn("ETH", "1h")
  from_ms <- anchor_ms
  to_ms <- anchor_ms + 10L * hour_ms
  dt <- hyperliquid:::hyperliquid_fetch_klines(
    coin = "ETH", interval = "1h",
    from = from_ms, to = to_ms,
    .req_fn = rec$fn, max_candles = 3L
  )
  # Despite overlapping windows, exactly 11 distinct hourly candles remain.
  expect_equal(nrow(dt), 11L)
  expect_equal(data.table::uniqueN(dt$datetime), 11L)
  expect_false(is.unsorted(dt$datetime))
  expect_equal(dt$datetime[1], ms_to_datetime(from_ms))
  expect_equal(dt$datetime[nrow(dt)], ms_to_datetime(to_ms))
})

# ---- combine_klines ----------------------------------------------------------

test_that("combine_klines dedups on datetime and sorts ascending", {
  a <- data.table::data.table(datetime = ms_to_datetime(c(anchor_ms + hour_ms, anchor_ms)), open = c(2, 1))
  b <- data.table::data.table(datetime = ms_to_datetime(c(anchor_ms + hour_ms, anchor_ms + 2 * hour_ms)), open = c(2, 3))
  out <- hyperliquid:::combine_klines(list(a, b))
  expect_equal(nrow(out), 3L)
  expect_false(is.unsorted(out$datetime))
})

test_that("combine_klines returns a zero-row table for empty input", {
  expect_equal(nrow(hyperliquid:::combine_klines(list())), 0L)
  expect_equal(nrow(hyperliquid:::combine_klines(list(data.table::data.table()))), 0L)
})

# ---- validation --------------------------------------------------------------

test_that("an invalid interval aborts before any request", {
  rec <- make_recording_req_fn("BTC", "1h")
  expect_error(
    hyperliquid:::hyperliquid_fetch_klines(
      coin = "BTC", interval = "7m",
      from = anchor_ms, to = anchor_ms + hour_ms, .req_fn = rec$fn
    ),
    "Invalid interval"
  )
  expect_length(rec$calls, 0L)
})

# ---- async parity ------------------------------------------------------------

test_that("async mode yields the same candles as sync mode", {
  skip_if_not_installed("promises")
  skip_if_not_installed("later")
  rec <- make_recording_req_fn("BTC", "1h")
  from_ms <- anchor_ms
  to_ms <- anchor_ms + 10L * hour_ms
  # In async mode the impl chains promises, so the req_fn must return one.
  async_fn <- function(payload, .parser = identity) {
    promises::promise_resolve(rec$fn(payload, .parser))
  }
  p <- hyperliquid:::hyperliquid_fetch_klines(
    coin = "BTC", interval = "1h",
    from = from_ms, to = to_ms,
    .req_fn = async_fn, is_async = TRUE, max_candles = 3L
  )
  out_env <- new.env(parent = emptyenv())
  promises::then(p, function(v) out_env$value <- v)
  while (!later::loop_empty()) later::run_now()
  expect_equal(nrow(out_env$value), 11L)
  expect_false(is.unsorted(out_env$value$datetime))
})
