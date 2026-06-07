# Tests for the standalone CSV backfill layer (R/backfill.R). The candle and
# funding walkers are exercised offline through a local httr2 mock that
# synthesises responses from the request body, so resume, dedup-on-resume, and
# the schema-mismatch refusal are all asserted without network. One opt-in live
# test against mainnet is gated behind HYPERLIQUID_LIVE_TESTS.

day_ms <- 86400000
hour_ms <- 3600000
anchor_ms <- 1700000000000 - (1700000000000 %% day_ms)
anchor_dt <- function(offset_ms = 0) lubridate::as_datetime((anchor_ms + offset_ms) / 1000, tz = "UTC")

# A mock httr2 transport that synthesises candleSnapshot / fundingHistory bodies
# from the request, mirroring the live JSON shapes. Installed via
# options(httr2_mock = ).
backfill_mock <- function(req) {
  raw_body <- req$body$data
  body_txt <- if (is.raw(raw_body)) rawToChar(raw_body) else as.character(raw_body)
  body <- jsonlite::fromJSON(body_txt, simplifyVector = FALSE)
  if (identical(body$type, "candleSnapshot")) {
    r <- body$req
    step_ms <- hyperliquid:::hyperliquid_interval_to_seconds[[r$interval]] * 1000
    ts <- seq(from = r$startTime, to = r$endTime, by = step_ms)
    payload <- lapply(ts, function(t) {
      list(
        t = t,
        T = t + step_ms - 1,
        s = r$coin,
        i = r$interval,
        o = "100",
        c = "101",
        h = "102",
        l = "99",
        v = "10",
        n = 5L
      )
    })
  } else if (identical(body$type, "fundingHistory")) {
    ts <- seq(from = body$startTime, to = body$endTime, by = hour_ms)
    if (length(ts) > 500L) {
      ts <- ts[seq_len(500L)]
    }
    payload <- lapply(ts, function(t) {
      list(coin = body$coin, fundingRate = "0.0001", premium = "0.00005", time = t)
    })
  } else {
    stop(sprintf("Unmocked backfill type: %s", body$type))
  }
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(json))
  ))
}

# ---- klines: fresh write + schema ---------------------------------------------

test_that("hyperliquid_backfill_klines writes the canonical schema", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)

  hyperliquid_backfill_klines(
    symbols = "BTC",
    intervals = "1d",
    from = anchor_dt(0),
    to = anchor_dt(5L * day_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )

  dt <- data.table::fread(file)
  expect_equal(
    names(dt),
    c("symbol", "interval", "datetime", "open", "high", "low", "close", "volume", "trades")
  )
  expect_equal(nrow(dt), 6L)
  expect_true(all(dt$symbol == "BTC"))
  expect_true(all(dt$interval == "1d"))
})

# ---- klines: resume ----------------------------------------------------------

test_that("hyperliquid_backfill_klines resumes without duplicating rows", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)

  # First pass: 6 daily candles.
  hyperliquid_backfill_klines(
    symbols = "BTC",
    intervals = "1d",
    from = anchor_dt(0),
    to = anchor_dt(5L * day_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )
  expect_equal(nrow(data.table::fread(file)), 6L)

  # Re-run identically: the series is already up to date, nothing is added.
  hyperliquid_backfill_klines(
    symbols = "BTC",
    intervals = "1d",
    from = anchor_dt(0),
    to = anchor_dt(5L * day_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )
  expect_equal(nrow(data.table::fread(file)), 6L)

  # Extend the window: only the 3 new candles are appended, no overlap dup.
  hyperliquid_backfill_klines(
    symbols = "BTC",
    intervals = "1d",
    from = anchor_dt(0),
    to = anchor_dt(8L * day_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )
  dt <- data.table::fread(file)
  expect_equal(nrow(dt), 9L)
  expect_equal(data.table::uniqueN(dt$datetime), 9L)
  expect_false(is.unsorted(dt$datetime))
})

# ---- klines: schema-mismatch refusal -----------------------------------------

test_that("hyperliquid_backfill_klines refuses a file with different columns", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)
  data.table::fwrite(data.table::data.table(foo = 1L, bar = 2L), file)

  expect_error(
    hyperliquid_backfill_klines(
      symbols = "BTC",
      intervals = "1d",
      from = anchor_dt(0),
      to = anchor_dt(5L * day_ms),
      file = file,
      sleep = 0,
      verbose = FALSE
    ),
    "differ"
  )
})

test_that("hyperliquid_backfill_klines validates inputs", {
  expect_error(hyperliquid_backfill_klines(symbols = character(0)), "non-empty")
  expect_error(
    hyperliquid_backfill_klines(symbols = "BTC", intervals = "7m", file = tempfile()),
    "Invalid interval"
  )
})

# ---- funding: fresh write + resume -------------------------------------------

test_that("hyperliquid_backfill_funding writes the canonical schema", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)

  hyperliquid_backfill_funding(
    symbols = "BTC",
    from = anchor_dt(0),
    to = anchor_dt(10L * hour_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )

  dt <- data.table::fread(file)
  expect_equal(names(dt), c("coin", "funding_rate", "premium", "time"))
  expect_equal(nrow(dt), 11L)
  expect_true(all(dt$coin == "BTC"))
})

test_that("hyperliquid_backfill_funding resumes without duplicating rows", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)

  hyperliquid_backfill_funding(
    symbols = "BTC",
    from = anchor_dt(0),
    to = anchor_dt(10L * hour_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )
  expect_equal(nrow(data.table::fread(file)), 11L)

  # Extend by 5 hours: 5 new records appended, no boundary dup.
  hyperliquid_backfill_funding(
    symbols = "BTC",
    from = anchor_dt(0),
    to = anchor_dt(15L * hour_ms),
    file = file,
    sleep = 0,
    verbose = FALSE
  )
  dt <- data.table::fread(file)
  expect_equal(nrow(dt), 16L)
  expect_equal(data.table::uniqueN(dt$time), 16L)
  expect_false(is.unsorted(dt$time))
})

test_that("hyperliquid_backfill_funding refuses a file with different columns", {
  old <- options(httr2_mock = backfill_mock)
  on.exit(options(old), add = TRUE)
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)
  data.table::fwrite(data.table::data.table(foo = 1L), file)

  expect_error(
    hyperliquid_backfill_funding(
      symbols = "BTC",
      from = anchor_dt(0),
      to = anchor_dt(10L * hour_ms),
      file = file,
      sleep = 0,
      verbose = FALSE
    ),
    "differ"
  )
})

# ---- opt-in live network test ------------------------------------------------

test_that("hyperliquid_backfill_klines hits mainnet (live, opt-in)", {
  skip_if(Sys.getenv("HYPERLIQUID_LIVE_TESTS") != "true", "set HYPERLIQUID_LIVE_TESTS=true to run")
  testthat::skip_if_offline()
  file <- tempfile(fileext = ".csv")
  on.exit(unlink(file), add = TRUE)

  suppressWarnings(hyperliquid_backfill_klines(
    symbols = "BTC",
    intervals = "1d",
    from = lubridate::now("UTC") - lubridate::ddays(10),
    to = lubridate::now("UTC"),
    file = file,
    sleep = 0,
    verbose = FALSE
  ))
  dt <- data.table::fread(file)
  expect_true(nrow(dt) > 0L)
  expect_equal(
    names(dt),
    c("symbol", "interval", "datetime", "open", "high", "low", "close", "volume", "trades")
  )
})
