# File: R/constants.R
# Package-wide constants: candle intervals (+ their durations in seconds), the
# order-side wire map, time-in-force values, and order-grouping values. These
# are the small fixed vocabularies the validators and parsers check against.

#' Hyperliquid Candle Intervals
#'
#' The 14 candle intervals accepted by Hyperliquid's `candleSnapshot` endpoint,
#' in ascending order. Unlike some other venues there is no `1s` or `6h`
#' interval.
#'
#' @format A character vector of 14 interval codes.
#'
#' @examples
#' HYPERLIQUID_INTERVALS
#'
#' @export
HYPERLIQUID_INTERVALS <- c(
  "1m", "3m", "5m", "15m", "30m",
  "1h", "2h", "4h", "8h", "12h",
  "1d", "3d", "1w", "1M"
)

#' Candle Interval Durations in Seconds
#'
#' Maps each [HYPERLIQUID_INTERVALS] code to its duration in seconds, used to
#' segment and backfill kline requests (Hyperliquid returns at most ~5000
#' candles per `candleSnapshot` call). `"1M"` is approximated as 30 days, the
#' conventional value for window arithmetic; calendar-month boundaries are not
#' resolved here.
#'
#' @format A named numeric vector keyed by interval code.
#'
#' @keywords internal
#' @noRd
hyperliquid_interval_to_seconds <- c(
  "1m" = 60,
  "3m" = 180,
  "5m" = 300,
  "15m" = 900,
  "30m" = 1800,
  "1h" = 3600,
  "2h" = 7200,
  "4h" = 14400,
  "8h" = 28800,
  "12h" = 43200,
  "1d" = 86400,
  "3d" = 259200,
  "1w" = 604800,
  "1M" = 2592000
)

#' Order-Side Wire Map (friendly -> Hyperliquid wire)
#'
#' Hyperliquid encodes the order side as `"B"` (bid / buy) and `"A"` (ask /
#' sell). This maps the friendly lowercase side to its wire code; invert with
#' [ORDER_SIDE_FROM_WIRE] when parsing responses.
#'
#' @format A named character vector `c(buy = "B", sell = "A")`.
#'
#' @keywords internal
#' @noRd
ORDER_SIDE <- c(buy = "B", sell = "A")

#' Order-Side Wire Map (Hyperliquid wire -> friendly)
#'
#' The inverse of [ORDER_SIDE]: maps Hyperliquid's `"B"`/`"A"` wire codes back
#' to the friendly `"buy"`/`"sell"` labels used in returned tables.
#'
#' @format A named character vector `c(B = "buy", A = "sell")`.
#'
#' @keywords internal
#' @noRd
ORDER_SIDE_FROM_WIRE <- c(B = "buy", A = "sell")

#' Time-in-Force Values
#'
#' The time-in-force codes accepted in a limit order's wire type: `"Alo"`
#' (add-liquidity-only / post-only), `"Ioc"` (immediate-or-cancel), and `"Gtc"`
#' (good-til-cancelled).
#'
#' @format A character vector of 3 time-in-force codes.
#'
#' @keywords internal
#' @noRd
TIF_VALUES <- c("Alo", "Ioc", "Gtc")

#' Order Grouping Values
#'
#' The grouping codes accepted by the `order` action: `"na"` (independent
#' orders), `"normalTpsl"`, and `"positionTpsl"` (the two take-profit/stop-loss
#' bracketing modes).
#'
#' @format A character vector of 3 grouping codes.
#'
#' @keywords internal
#' @noRd
GROUPING_VALUES <- c("na", "normalTpsl", "positionTpsl")
