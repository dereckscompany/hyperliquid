#!/usr/bin/env Rscript
# ============================================================================
# capture_testnet_fixtures.R
# ============================================================================
# Capture real Hyperliquid TESTNET responses to JSON, as ground truth for the
# hand-written mock fixtures (tests/testthat/fixtures-*.R) and the vignettes.
#
# Reads are PUBLIC (no key) and safe to re-run. The optional live-trade capture
# (a tiny long BTC + short ETH pairs trade, then close) is gated behind an env
# flag so a plain run never touches funds:
#
#   Rscript data-raw/capture_testnet_fixtures.R                 # reads only
#   CAPTURE_LIVE_TRADES=true Rscript data-raw/capture_testnet_fixtures.R
#
# Output: data-raw/testnet-captures/<type>.json
# ============================================================================

suppressMessages(devtools::load_all(".", quiet = TRUE))

out_dir <- file.path("data-raw", "testnet-captures")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

info <- function(body) {
  r <- httr2::request("https://api.hyperliquid-testnet.xyz/info")
  r <- httr2::req_body_json(r, body)
  httr2::resp_body_json(httr2::req_perform(r), simplifyVector = FALSE)
}

save_json <- function(obj, name) {
  path <- file.path(out_dir, paste0(name, ".json"))
  jsonlite::write_json(obj, path, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  message("saved ", path)
}

# ---- public market-data + account reads -------------------------------------

readRenviron(".Renviron")
addr <- Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")

reads <- list(
  meta = list(type = "meta"),
  meta_and_asset_ctxs = list(type = "metaAndAssetCtxs"),
  spot_meta = list(type = "spotMeta"),
  spot_meta_and_asset_ctxs = list(type = "spotMetaAndAssetCtxs"),
  all_mids = list(type = "allMids"),
  l2_book_btc = list(type = "l2Book", coin = "BTC"),
  l2_book_eth = list(type = "l2Book", coin = "ETH"),
  candle_snapshot_btc_1h = list(type = "candleSnapshot", req = list(
    coin = "BTC", interval = "1h",
    startTime = 1735689600000, endTime = 1735776000000
  )),
  funding_history_btc = list(type = "fundingHistory", coin = "BTC", startTime = 1735689600000),
  predicted_fundings = list(type = "predictedFundings")
)
for (nm in names(reads)) save_json(info(reads[[nm]]), nm)

if (nzchar(addr)) {
  acct_reads <- list(
    clearinghouse_state = list(type = "clearinghouseState", user = addr),
    spot_clearinghouse_state = list(type = "spotClearinghouseState", user = addr),
    user_fills = list(type = "userFills", user = addr),
    historical_orders = list(type = "historicalOrders", user = addr),
    user_fees = list(type = "userFees", user = addr),
    open_orders = list(type = "openOrders", user = addr)
  )
  for (nm in names(acct_reads)) save_json(info(acct_reads[[nm]]), nm)
}

# ---- optional: a real pairs-trade capture (long BTC + short ETH) -------------

if (identical(Sys.getenv("CAPTURE_LIVE_TRADES"), "true")) {
  message("\n--- live pairs-trade capture (long BTC, short ETH) ---")
  trading <- HyperliquidTrading$new(keys = get_api_keys(), testnet = TRUE)

  best <- function(coin, side) {
    b <- info(list(type = "l2Book", coin = coin))
    as.numeric(b$levels[[side]][[1]]$px) # side 1 = bids, 2 = asks
  }
  # Long BTC: marketable buy at the ask. Short ETH: marketable sell at the bid.
  btc_px <- round(best("BTC", 2L) + 100)
  eth_px <- round(best("ETH", 1L) - 2, 1)

  print(trading$place_order(
    name = "BTC", is_buy = TRUE, sz = 0.0002, limit_px = btc_px,
    order_type = list(limit = list(tif = "Gtc"))
  ))
  print(trading$place_order(
    name = "ETH", is_buy = FALSE, sz = 0.01, limit_px = eth_px,
    order_type = list(limit = list(tif = "Gtc"))
  ))

  # Capture the account WITH both open positions, and the fills.
  save_json(info(list(type = "clearinghouseState", user = addr)), "clearinghouse_state_pairs")
  save_json(info(list(type = "userFills", user = addr)), "user_fills_pairs")

  # Flatten both legs (reduce-only).
  print(trading$place_order(
    name = "BTC", is_buy = FALSE, sz = 0.0002, limit_px = round(best("BTC", 1L) - 100),
    order_type = list(limit = list(tif = "Gtc")), reduce_only = TRUE
  ))
  print(trading$place_order(
    name = "ETH", is_buy = TRUE, sz = 0.01, limit_px = round(best("ETH", 2L) + 2, 1),
    order_type = list(limit = list(tif = "Gtc")), reduce_only = TRUE
  ))
  message("--- closed both legs; account flat ---")
}

message("\nDone. Captures in ", out_dir)
