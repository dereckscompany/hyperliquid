# File: R/data.R
# Documentation for the bundled sample dataset shipped in data/.

#' Daily OHLCV Sample Data from Hyperliquid
#'
#' Historical daily candlestick (OHLCV) data for three major perpetuals
#' (`"BTC"`, `"ETH"`, `"SOL"`) from Hyperliquid's `candleSnapshot` `/info`
#' endpoint, stacked into a single long table with a `symbol` column. Roughly one
#' year of daily candles per coin, included for demonstration and examples.
#' Produced with [HyperliquidMarketData]'s candle method.
#'
#' @format A [data.table::data.table] with one row per (symbol, day) and 8
#'   columns:
#' - `symbol` (Character): Coin symbol, e.g. `"BTC"`.
#' - `datetime` (POSIXct): Candle open time in UTC.
#' - `open` (Numeric): Opening price.
#' - `high` (Numeric): Highest price during the interval.
#' - `low` (Numeric): Lowest price during the interval.
#' - `close` (Numeric): Closing price.
#' - `volume` (Numeric): Trading volume in base currency.
#' - `trades` (Numeric): Number of trades in the interval.
#'
#' @source Hyperliquid `/info` `candleSnapshot` via [HyperliquidMarketData]
#' @examples
#' data(hyperliquid_ohlcv)
#' head(hyperliquid_ohlcv)
"hyperliquid_ohlcv"
