# Precision regression: every numeric field Hyperliquid reports as a decimal
# STRING must survive parsing at full double precision. No round(), signif(),
# sprintf("%.Nf"), format(nsmall = ), or other narrowing cast may ever sit
# between the venue's string and R's as.numeric().
#
# Why this test exists: on 2026-09-13 the fleet found every Hyperliquid candle
# in the data lake had been stored to four decimal places for months -- a coin
# priced below a cent (e.g. "0.000212") lost almost all of its information,
# and a strategy that ranks coins by calmness ranked them wrongly as a direct
# result. The cause traced to a re-serialisation default in the data scraper
# (since fixed), NOT to this package: hyperliquid's own parse path
# (num_or_na() -> as.numeric(), R/helpers_parse.R) was proven correct, verified
# live against the venue -- its "0.000212" comes back as
# 0.00021200000000000000, full precision intact. This test pins that fact so
# the layer that is currently correct STAYS correct: if anyone later adds a
# round()/signif()/sprintf("%.4f")/format(nsmall = ) or a narrowing cast to a
# parse helper, it fails immediately.
#
# Drives the real public client methods (get_candles / get_meta_and_asset_ctxs
# / get_funding_history) through the shared connectcore mock harness
# (body_routes + local_mock_api), exactly as test-client-endpoints.R does, with
# a synthetic high-precision fixture -- never a private helper reimplemented
# here. Uses expect_identical() throughout, never expect_equal()'s tolerance,
# because tolerance is exactly what would hide this defect.

# ---- fixture: decimal strings with many significant digits ------------------

# A value just under 2^53 (the largest integer a double represents exactly),
# used as a character-typed identifier (the `coin` / `name` field) to prove an
# identifier column is never accidentally coerced to numeric.
.precision_big_id <- "9007199254740991"

.precision_strings <- list(
  a = "0.00023456789",
  b = "12345.678901234",
  c = "0.000000123456",
  d = "1e-10"
)

# A read-only client (no signing key) -- MarketData never signs.
precision_client <- function() {
  return(hyperliquid:::HyperliquidMarketData$new(
    keys = list(private_key = NULL, account_address = NULL, wallet_address = NULL)
  ))
}

# A tiny body-routed table covering exactly the three /info types this test
# drives, built the same way the shared mock_router.R does (connectcore's
# body_routes() + local_mock_api()), but with a synthetic high-precision
# fixture instead of the captured real-shaped fixtures.
precision_routes <- function() {
  return(connectcore::body_routes(
    "/info",
    "type",
    list(
      candleSnapshot = function() {
        return(list(list(
          t = 1700000000000,
          T = 1700003599999,
          s = .precision_big_id,
          i = "1h",
          o = .precision_strings$a,
          h = .precision_strings$b,
          l = .precision_strings$c,
          c = .precision_strings$d,
          v = .precision_strings$b,
          n = 42L
        )))
      },
      metaAndAssetCtxs = function() {
        return(list(
          list(
            universe = list(list(
              name = .precision_big_id,
              szDecimals = 5L,
              maxLeverage = 40L
            ))
          ),
          list(list(
            funding = .precision_strings$a,
            openInterest = .precision_strings$b,
            prevDayPx = .precision_strings$c,
            dayNtlVlm = .precision_strings$b,
            premium = .precision_strings$d,
            oraclePx = .precision_strings$a,
            markPx = .precision_strings$c,
            midPx = .precision_strings$b,
            impactPxs = list(.precision_strings$a, .precision_strings$d)
          ))
        ))
      },
      fundingHistory = function() {
        return(list(list(
          coin = .precision_big_id,
          fundingRate = .precision_strings$a,
          premium = .precision_strings$c,
          time = 1700000000000
        )))
      }
    )
  ))
}

# A shared digit-level check: sprintf("%.17g", .) prints enough significant
# digits to uniquely round-trip an IEEE-754 double, so if the parser silently
# narrowed the value (round()/signif()/a %.Nf format), the 17-digit rendering
# of the parsed value would diverge from the 17-digit rendering of the
# fixture's own as.numeric() value.
expect_full_precision <- function(actual, fixture_string) {
  expected <- as.numeric(fixture_string)
  expect_identical(actual, expected)
  return(expect_identical(sprintf("%.17g", actual), sprintf("%.17g", expected)))
}

# ---- candle/kline path: get_candles ------------------------------------------

test_that("get_candles preserves full OHLCV precision through the real parse path", {
  connectcore::local_mock_api(precision_routes())
  client <- precision_client()
  dt <- client$get_candles("BTC", interval = "1h", start = 1700000000000, end = 1700003599999)

  expect_equal(nrow(dt), 1L)
  expect_full_precision(dt$open, .precision_strings$a)
  expect_full_precision(dt$high, .precision_strings$b)
  expect_full_precision(dt$low, .precision_strings$c)
  expect_full_precision(dt$close, .precision_strings$d)
  expect_full_precision(dt$volume, .precision_strings$b)
  # the identifier stays character, byte-identical, never coerced to numeric.
  expect_type(dt$coin, "character")
  expect_identical(dt$coin, .precision_big_id)
})

# ---- ticker/market-data snapshot path: get_meta_and_asset_ctxs ---------------

test_that("get_meta_and_asset_ctxs preserves full price/rate precision", {
  connectcore::local_mock_api(precision_routes())
  client <- precision_client()
  dt <- client$get_meta_and_asset_ctxs()

  expect_equal(nrow(dt), 1L)
  expect_full_precision(dt$funding, .precision_strings$a)
  expect_full_precision(dt$open_interest, .precision_strings$b)
  expect_full_precision(dt$prev_day_px, .precision_strings$c)
  expect_full_precision(dt$day_ntl_vlm, .precision_strings$b)
  expect_full_precision(dt$premium, .precision_strings$d)
  expect_full_precision(dt$oracle_px, .precision_strings$a)
  expect_full_precision(dt$mark_px, .precision_strings$c)
  expect_full_precision(dt$mid_px, .precision_strings$b)
  expect_full_precision(dt$impact_px_bid, .precision_strings$a)
  expect_full_precision(dt$impact_px_ask, .precision_strings$d)
  # the identifier stays character, byte-identical, never coerced to numeric.
  expect_type(dt$name, "character")
  expect_identical(dt$name, .precision_big_id)
})

# ---- funding/rate path: get_funding_history ----------------------------------

test_that("get_funding_history preserves full rate precision", {
  connectcore::local_mock_api(precision_routes())
  client <- precision_client()
  dt <- client$get_funding_history("BTC", start = 1699999999000, end = 1700000001000)

  expect_equal(nrow(dt), 1L)
  expect_full_precision(dt$funding_rate, .precision_strings$a)
  expect_full_precision(dt$premium, .precision_strings$c)
  # the identifier stays character, byte-identical, never coerced to numeric.
  expect_type(dt$coin, "character")
  expect_identical(dt$coin, .precision_big_id)
})
