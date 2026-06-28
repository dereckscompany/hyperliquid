#!/usr/bin/env Rscript
# File: dev/capture-hyperliquid.R
#
# READ-ONLY capture harness for the `hyperliquid` package.
#
# Purpose: hit the REAL Hyperliquid API (the user's own account + the public
# market data API) with READ-ONLY requests and dump each raw response body
# verbatim to local/raw-data/hyperliquid/<name>.json. Those captures are then
# compared (by hand or by a sibling validation script) against the committed
# fixtures in tests/testthat/fixtures/ to prove the fixtures faithfully mirror
# the live wire shapes.
#
# SAFETY: Hyperliquid is body-routed -- the ENTIRE read API lives behind a
# single `POST /info` endpoint discriminated by `body$type` (there are no GET
# read endpoints). Writes live behind `POST /exchange` and require a signed
# body. This script issues ONLY `POST /info` read requests; it NEVER touches
# `/exchange`, never signs anything, never places/cancels orders, never moves
# funds, and never reads HYPERLIQUID_PRIVATE_KEY. The only credential used is
# the PUBLIC account address (HYPERLIQUID_ACCOUNT_ADDRESS), which read endpoints
# take as a plain `user` body field. Raw bodies (which contain the user's real
# account data) are written ONLY under local/raw-data/hyperliquid/ which is
# git-ignored.
#
# Network: defaults to TESTNET (the network the committed fixtures were captured
# from). Override with HYPERLIQUID_CAPTURE_NETWORK=mainnet.
#
# Run from the package root:
#   Rscript dev/capture-hyperliquid.R

suppressWarnings(suppressMessages({
  library(httr2)
  library(jsonlite)
}))

# ---------------------------------------------------------------------------
# Credentials (PUBLIC address only) + host. Never printed.
# ---------------------------------------------------------------------------
if (file.exists(".Renviron")) {
  readRenviron(".Renviron")
}

# PUBLIC account address only. We deliberately do NOT read the private key:
# reads need no signature.
account_address <- Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")

network <- Sys.getenv("HYPERLIQUID_CAPTURE_NETWORK", "testnet")
HOST <- if (identical(tolower(network), "mainnet")) {
  "https://api.hyperliquid.xyz"
} else {
  "https://api.hyperliquid-testnet.xyz"
}
INFO_URL <- paste0(HOST, "/info")

OUT_DIR <- file.path("local", "raw-data", "hyperliquid")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Defensive: refuse to write anywhere git would track. local/ is git-ignored.
if (Sys.which("git") != "") {
  probe <- file.path(OUT_DIR, "ignore-probe.json")
  ignored <- suppressWarnings(system2(
    "git",
    c("check-ignore", probe),
    stdout = TRUE,
    stderr = FALSE
  ))
  if (length(ignored) == 0L) {
    stop(
      "Refusing to write: ",
      OUT_DIR,
      " is NOT git-ignored. Aborting to avoid committing real account data."
    )
  }
}

cat("Network    :", network, "\n")
cat("Info URL   :", INFO_URL, "\n")
cat("Account set:", nzchar(account_address), "\n")
cat("Output dir :", normalizePath(OUT_DIR), "\n\n")

# Recent time window helpers (ms epoch), so the script ages well.
now_ms <- as.numeric(Sys.time()) * 1000
day_ms <- 24 * 60 * 60 * 1000
win_start_ms <- floor(now_ms - 30 * day_ms)
candle_start_ms <- floor(now_ms - 2 * day_ms)
candle_end_ms <- floor(now_ms)

# ---------------------------------------------------------------------------
# One POST /info: perform, write raw body verbatim, log a one-line status.
# Wrapped so a single failure (network, 4xx, parse) never aborts the batch.
# ---------------------------------------------------------------------------
log_rows <- list()

is_empty_body <- function(parsed) {
  if (is.null(parsed)) {
    return(TRUE)
  }
  if (length(parsed) == 0L) {
    return(TRUE)
  }
  return(FALSE)
}

capture <- function(name, body) {
  result <- tryCatch(
    {
      req <- httr2::request(INFO_URL) |>
        httr2::req_method("POST") |>
        httr2::req_body_json(body) |>
        httr2::req_timeout(30) |>
        # Do NOT throw on 4xx/5xx -- we want to capture the error body too.
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_user_agent("hyperliquid-capture-readonly/1.0")
      resp <- httr2::req_perform(req)

      status <- httr2::resp_status(resp)
      body_raw <- httr2::resp_body_raw(resp)
      out_path <- file.path(OUT_DIR, paste0(name, ".json"))
      writeBin(body_raw, out_path)

      parsed <- tryCatch(
        jsonlite::fromJSON(rawToChar(body_raw), simplifyVector = FALSE),
        error = function(e) NULL
      )
      list(
        name = name,
        type = body$type,
        status = status,
        bytes = length(body_raw),
        empty = is_empty_body(parsed),
        ok = status >= 200 && status < 300,
        parsed = parsed
      )
    },
    error = function(e) {
      list(
        name = name,
        type = body$type,
        status = NA_integer_,
        bytes = 0L,
        empty = NA,
        ok = FALSE,
        parsed = NULL,
        err = conditionMessage(e)
      )
    }
  )

  state <- if (!isTRUE(result$ok)) {
    "FAIL"
  } else if (isTRUE(result$empty)) {
    "EMPTY"
  } else {
    "POPULATED"
  }
  cat(sprintf(
    "%-32s type=%-28s status=%-4s bytes=%-7s %s%s\n",
    name,
    result$type,
    ifelse(is.na(result$status), "ERR", result$status),
    result$bytes,
    state,
    if (!is.null(result$err)) paste0("  <", result$err, ">") else ""
  ))
  log_rows[[name]] <<- result
  return(invisible(result))
}

# ---------------------------------------------------------------------------
# PUBLIC market data reads (no address required).
# ---------------------------------------------------------------------------
cat("== Market data (public) ==\n")
capture("meta", list(type = "meta"))
capture("spot_meta", list(type = "spotMeta"))
capture("meta_and_asset_ctxs", list(type = "metaAndAssetCtxs"))
capture("spot_meta_and_asset_ctxs", list(type = "spotMetaAndAssetCtxs"))
capture("all_mids", list(type = "allMids"))
capture("l2_book", list(type = "l2Book", coin = "BTC"))
capture(
  "candle_snapshot",
  list(
    type = "candleSnapshot",
    req = list(
      coin = "BTC",
      interval = "1h",
      startTime = candle_start_ms,
      endTime = candle_end_ms
    )
  )
)
capture("funding_history", list(type = "fundingHistory", coin = "BTC", startTime = win_start_ms))
capture("predicted_fundings", list(type = "predictedFundings"))
capture("perp_dexs", list(type = "perpDexs"))
capture("recent_trades", list(type = "recentTrades", coin = "BTC"))
capture("exchange_status", list(type = "exchangeStatus"))

# ---------------------------------------------------------------------------
# PRIVATE account reads (PUBLIC address only -- no signing).
# ---------------------------------------------------------------------------
if (nzchar(account_address)) {
  cat("\n== Account (public address) ==\n")
  addr <- account_address
  capture("clearinghouse_state", list(type = "clearinghouseState", user = addr))
  capture("spot_clearinghouse_state", list(type = "spotClearinghouseState", user = addr))
  capture("open_orders", list(type = "openOrders", user = addr))
  capture("frontend_open_orders", list(type = "frontendOpenOrders", user = addr))
  fills_res <- capture("user_fills", list(type = "userFills", user = addr))
  capture("user_fills_by_time", list(type = "userFillsByTime", user = addr, startTime = win_start_ms))
  ho_res <- capture("historical_orders", list(type = "historicalOrders", user = addr))
  capture("user_funding", list(type = "userFunding", user = addr, startTime = win_start_ms))
  capture(
    "user_non_funding_ledger_updates",
    list(
      type = "userNonFundingLedgerUpdates",
      user = addr,
      startTime = win_start_ms
    )
  )
  capture("portfolio", list(type = "portfolio", user = addr))
  capture("user_fees", list(type = "userFees", user = addr))
  capture("user_rate_limit", list(type = "userRateLimit", user = addr))
  capture("user_role", list(type = "userRole", user = addr))
  capture("sub_accounts", list(type = "subAccounts", user = addr))
  capture("user_vault_equities", list(type = "userVaultEquities", user = addr))

  # orderStatus needs a concrete oid -- pull one from historical orders or fills.
  pick_oid <- function(res) {
    p <- res$parsed
    if (is.null(p) || length(p) == 0L) {
      return(NULL)
    }
    # historicalOrders -> list of {order: {oid}, status}; userFills -> list of {oid}
    first <- p[[1]]
    if (!is.null(first$order$oid)) {
      return(first$order$oid)
    }
    if (!is.null(first$oid)) {
      return(first$oid)
    }
    return(NULL)
  }
  oid <- pick_oid(ho_res)
  if (is.null(oid)) {
    oid <- pick_oid(fills_res)
  }
  if (!is.null(oid)) {
    capture("order_status", list(type = "orderStatus", user = addr, oid = oid))
  }

  cat("\n== Staking (public address) ==\n")
  capture("delegator_summary", list(type = "delegatorSummary", user = addr))
  capture("delegations", list(type = "delegations", user = addr))
  capture("delegator_rewards", list(type = "delegatorRewards", user = addr))
  capture("delegator_history", list(type = "delegatorHistory", user = addr))
} else {
  cat("\n(no HYPERLIQUID_ACCOUNT_ADDRESS set -- skipping private reads)\n")
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
cat("\n== Summary ==\n")
states <- vapply(
  log_rows,
  function(r) {
    if (!isTRUE(r$ok)) {
      "FAIL"
    } else if (isTRUE(r$empty)) {
      "EMPTY"
    } else {
      "POPULATED"
    }
  },
  character(1)
)
cat("POPULATED:", sum(states == "POPULATED"), "\n")
cat("EMPTY    :", sum(states == "EMPTY"), "\n")
cat("FAIL     :", sum(states == "FAIL"), "\n")
cat("Total    :", length(states), "\n")
cat("\nCaptures written to", OUT_DIR, "\n")
