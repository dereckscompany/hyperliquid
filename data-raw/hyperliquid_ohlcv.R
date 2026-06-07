# File: data-raw/hyperliquid_ohlcv.R
# Regenerates data/hyperliquid_ohlcv.rda with ONE controlled live read of public
# market data (no key required). Daily ("1d") OHLCV for BTC, ETH, SOL over the
# last ~1 year, stacked long with a `symbol` column. Run with:
#   Rscript data-raw/hyperliquid_ohlcv.R

suppressMessages(devtools::load_all("."))

symbols <- c("BTC", "ETH", "SOL")
to <- lubridate::now("UTC")
from <- to - lubridate::ddays(365)

# Key-free public client: market data needs no wallet signature.
market <- HyperliquidMarketData$new(
  keys = list(private_key = NULL, account_address = NULL, wallet_address = NULL)
)

rows <- lapply(symbols, function(sym) {
  dt <- market$get_candles(sym, interval = "1d", start = from, end = to)
  dt[, symbol := sym]
  dt[, list(symbol, datetime, open, high, low, close, volume, trades)]
})

hyperliquid_ohlcv <- data.table::rbindlist(rows)
data.table::setorder(hyperliquid_ohlcv, symbol, datetime)
hyperliquid_ohlcv <- hyperliquid_ohlcv[]

usethis::use_data(hyperliquid_ohlcv, overwrite = TRUE, compress = "bzip2")

cat(sprintf(
  "hyperliquid_ohlcv: %d rows across %d symbols\n",
  nrow(hyperliquid_ohlcv),
  length(unique(hyperliquid_ohlcv$symbol))
))
