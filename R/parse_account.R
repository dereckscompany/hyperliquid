# File: R/parse_account.R
# Endpoint parsers for HyperliquidAccount. Each takes the raw parsed JSON
# (jsonlite::fromJSON(simplifyVector = FALSE) output) of one user-scoped /info
# read and returns ONE flat data.table: snake_case columns, number-strings
# coerced via num_or_na, epoch-ms timestamps as POSIXct UTC via ms_to_datetime,
# nested/positional structures flattened, and never a list column. Empty input
# -> zero-row table. These compose the generic helpers in R/helpers_parse.R.

#' Map a Hyperliquid Wire Side Code to the Friendly Label
#'
#' Hyperliquid encodes the order/fill side as `"B"` (bid / buy) or `"A"` (ask /
#' sell). This inverts that via `ORDER_SIDE_FROM_WIRE`, returning `NA` for an
#' unknown code, and is shared by every order/fill parser below.
#'
#' @param x A scalar wire-side code, or NULL.
#' @return The friendly side (`"buy"`/`"sell"`), or `NA_character_`.
#' @keywords internal
#' @noRd
wire_side <- function(x) {
  return(unname(coalesce_null(ORDER_SIDE_FROM_WIRE[chr_or_na(x)], NA_character_)))
}

#' Flatten One Order Object to a Single-Row data.table
#'
#' The shared order shape behind `frontendOpenOrders`, `historicalOrders`, and
#' `orderStatus`. The `children` array is intentionally dropped (kept flat). A
#' NULL order (e.g. an `unknownOid` status) yields a one-row all-`NA` table so
#' callers always get exactly one row.
#'
#' @param o A named list (one order object), or NULL.
#' @return A single-row [data.table::data.table] of the order fields.
#' @keywords internal
#' @noRd
flatten_order <- function(o) {
  return(data.table::data.table(
    coin = chr_or_na(o$coin),
    oid = num_or_na(o$oid),
    side = wire_side(o$side),
    limit_px = num_or_na(o$limitPx),
    sz = num_or_na(o$sz),
    orig_sz = num_or_na(o$origSz),
    order_type = chr_or_na(o$orderType),
    tif = chr_or_na(o$tif),
    reduce_only = lgl_or_na(o$reduceOnly),
    trigger_px = num_or_na(o$triggerPx),
    trigger_condition = chr_or_na(o$triggerCondition),
    is_trigger = lgl_or_na(o$isTrigger),
    is_position_tpsl = lgl_or_na(o$isPositionTpsl),
    cloid = chr_or_na(o$cloid),
    timestamp = ms_to_datetime(num_or_na(o$timestamp))
  ))
}

#' Parse a `clearinghouseState` Response: Open Positions
#'
#' One row per `assetPositions[].position`. The per-position `leverage` object is
#' split into `leverage_type` / `leverage_value`; `cumFunding` and `maxLeverage`
#' are not returned.
#'
#' @param data List; the parsed `{type:"clearinghouseState"}` response.
#' @return A [data.table::data.table] with `coin`, `szi`, `entry_px`,
#'   `position_value`, `unrealized_pnl`, `return_on_equity`, `leverage_type`,
#'   `leverage_value`, `liquidation_px`, `margin_used`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_positions <- function(data) {
  positions <- data$assetPositions
  if (is.null(positions) || length(positions) == 0L) {
    # A flat account (no open positions) is a routine live response; return the
    # typed zero-row schema so the column contract still holds.
    return(data.table::data.table(
      coin = character(0),
      szi = numeric(0),
      entry_px = numeric(0),
      position_value = numeric(0),
      unrealized_pnl = numeric(0),
      return_on_equity = numeric(0),
      leverage_type = character(0),
      leverage_value = numeric(0),
      liquidation_px = numeric(0),
      margin_used = numeric(0)
    )[])
  }
  rows <- lapply(positions, function(ap) {
    p <- ap$position
    return(data.table::data.table(
      coin = chr_or_na(p$coin),
      szi = num_or_na(p$szi),
      entry_px = num_or_na(p$entryPx),
      position_value = num_or_na(p$positionValue),
      unrealized_pnl = num_or_na(p$unrealizedPnl),
      return_on_equity = num_or_na(p$returnOnEquity),
      leverage_type = chr_or_na(p$leverage$type),
      leverage_value = num_or_na(p$leverage$value),
      liquidation_px = num_or_na(p$liquidationPx),
      margin_used = num_or_na(p$marginUsed)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `clearinghouseState` Response: Margin Summary
#'
#' Flattens the cross-margin account summary to one row, pairing the overall
#' `marginSummary` with the `crossMarginSummary` (the `cross_*` columns) and the
#' top-level `withdrawable`.
#'
#' @param data List; the parsed `{type:"clearinghouseState"}` response.
#' @return A single-row [data.table::data.table] with `account_value`,
#'   `total_ntl_pos`, `total_raw_usd`, `total_margin_used`, `withdrawable`,
#'   `cross_account_value`, `cross_total_ntl_pos`, `cross_total_raw_usd`,
#'   `cross_total_margin_used`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_margin_summary <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    # An address that never deposited returns an empty clearinghouseState;
    # return the typed zero-row schema so the column contract still holds.
    return(data.table::data.table(
      account_value = numeric(0),
      total_ntl_pos = numeric(0),
      total_raw_usd = numeric(0),
      total_margin_used = numeric(0),
      withdrawable = numeric(0),
      cross_account_value = numeric(0),
      cross_total_ntl_pos = numeric(0),
      cross_total_raw_usd = numeric(0),
      cross_total_margin_used = numeric(0)
    )[])
  }
  ms <- data$marginSummary
  cms <- data$crossMarginSummary
  return(data.table::data.table(
    account_value = num_or_na(ms$accountValue),
    total_ntl_pos = num_or_na(ms$totalNtlPos),
    total_raw_usd = num_or_na(ms$totalRawUsd),
    total_margin_used = num_or_na(ms$totalMarginUsed),
    withdrawable = num_or_na(data$withdrawable),
    cross_account_value = num_or_na(cms$accountValue),
    cross_total_ntl_pos = num_or_na(cms$totalNtlPos),
    cross_total_raw_usd = num_or_na(cms$totalRawUsd),
    cross_total_margin_used = num_or_na(cms$totalMarginUsed)
  )[])
}

#' Parse a `spotClearinghouseState` Response
#'
#' One row per spot balance.
#'
#' @param data List; the parsed `{type:"spotClearinghouseState"}` response.
#' @return A [data.table::data.table] with `coin`, `total`, `hold`, `entry_ntl`;
#'   zero-row when empty.
#' @keywords internal
#' @noRd
parse_spot_balances <- function(data) {
  balances <- data$balances
  if (is.null(balances) || length(balances) == 0L) {
    return(data.table::data.table(
      coin = character(0),
      total = numeric(0),
      hold = numeric(0),
      entry_ntl = numeric(0)
    )[])
  }
  rows <- lapply(balances, function(b) {
    return(data.table::data.table(
      coin = chr_or_na(b$coin),
      total = num_or_na(b$total),
      hold = num_or_na(b$hold),
      entry_ntl = num_or_na(b$entryNtl)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse an `openOrders` Response
#'
#' One row per resting order; the wire side is mapped to `buy`/`sell` and the
#' timestamp to a POSIXct.
#'
#' @param items List; the parsed `{type:"openOrders"}` response.
#' @return A [data.table::data.table] with `coin`, `oid`, `side`, `limit_px`,
#'   `sz`, `timestamp`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_open_orders <- function(items) {
  if (is.null(items) || length(items) == 0L) {
    return(data.table::data.table(
      coin = character(0),
      oid = numeric(0),
      side = character(0),
      limit_px = numeric(0),
      sz = numeric(0),
      timestamp = ms_to_datetime(numeric(0))
    )[])
  }
  rows <- lapply(items, function(o) {
    return(data.table::data.table(
      coin = chr_or_na(o$coin),
      oid = num_or_na(o$oid),
      side = wire_side(o$side),
      limit_px = num_or_na(o$limitPx),
      sz = num_or_na(o$sz),
      timestamp = ms_to_datetime(num_or_na(o$timestamp))
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `frontendOpenOrders` Response
#'
#' One row per resting order with the frontend's richer detail (order type,
#' trigger fields, reduce-only, tif). The nested `children` array is dropped and
#' the `cloid` field is not surfaced here.
#'
#' @param items List; the parsed `{type:"frontendOpenOrders"}` response.
#' @return A [data.table::data.table] with `coin`, `oid`, `side`, `limit_px`,
#'   `sz`, `timestamp`, `order_type`, `is_trigger`, `trigger_px`,
#'   `trigger_condition`, `reduce_only`, `tif`, `orig_sz`, `is_position_tpsl`;
#'   zero-row when empty.
#' @keywords internal
#' @noRd
parse_frontend_open_orders <- function(items) {
  # An empty response still owes its caller every column; the order shape comes
  # from flatten_order(), so the empty case reuses it rather than restating it.
  rows <- lapply(items, flatten_order)
  dt <- if (length(rows) > 0L) {
    data.table::rbindlist(rows, fill = TRUE)
  } else {
    flatten_order(NULL)[0L]
  }
  data.table::set(dt, j = "cloid", value = NULL)
  data.table::setcolorder(
    dt,
    c(
      "coin",
      "oid",
      "side",
      "limit_px",
      "sz",
      "timestamp",
      "order_type",
      "is_trigger",
      "trigger_px",
      "trigger_condition",
      "reduce_only",
      "tif",
      "orig_sz",
      "is_position_tpsl"
    )
  )
  return(dt[])
}

#' Parse a `userFills` / `userFillsByTime` Response
#'
#' One row per fill; both fill endpoints share this shape. The wire side is
#' mapped to `buy`/`sell` and `time` to a POSIXct.
#'
#' @param items List; the parsed fills response.
#' @return A [data.table::data.table] with `coin`, `px`, `sz`, `side`, `time`,
#'   `start_position`, `dir`, `closed_pnl`, `hash`, `oid`, `crossed`, `fee`,
#'   `fee_token`, `tid`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_fills <- function(items) {
  if (is.null(items) || length(items) == 0L) {
    # An account that never traded returns an empty fills array; return the
    # typed zero-row schema so the column contract still holds.
    return(data.table::data.table(
      coin = character(0),
      px = numeric(0),
      sz = numeric(0),
      side = character(0),
      time = ms_to_datetime(numeric(0)),
      start_position = numeric(0),
      dir = character(0),
      closed_pnl = numeric(0),
      hash = character(0),
      oid = numeric(0),
      crossed = logical(0),
      fee = numeric(0),
      fee_token = character(0),
      tid = numeric(0)
    )[])
  }
  rows <- lapply(items, function(f) {
    return(data.table::data.table(
      coin = chr_or_na(f$coin),
      px = num_or_na(f$px),
      sz = num_or_na(f$sz),
      side = wire_side(f$side),
      time = ms_to_datetime(num_or_na(f$time)),
      start_position = num_or_na(f$startPosition),
      dir = chr_or_na(f$dir),
      closed_pnl = num_or_na(f$closedPnl),
      hash = chr_or_na(f$hash),
      oid = num_or_na(f$oid),
      crossed = lgl_or_na(f$crossed),
      fee = num_or_na(f$fee),
      fee_token = chr_or_na(f$feeToken),
      tid = num_or_na(f$tid)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `historicalOrders` Response
#'
#' One row per **status transition** (no deduplication): the same `oid` recurs
#' across its `open` -> `filled`/`canceled`/... lifecycle. Each record pairs the
#' order shape with its `status` and `status_timestamp`.
#'
#' @param items List; the parsed `{type:"historicalOrders"}` response.
#' @return A [data.table::data.table] with `oid`, `coin`, `side`, `limit_px`,
#'   `sz`, `orig_sz`, `order_type`, `tif`, `reduce_only`, `trigger_px`,
#'   `trigger_condition`, `is_trigger`, `is_position_tpsl`, `cloid`,
#'   `timestamp`, `status`, `status_timestamp`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_historical_orders <- function(items) {
  rows <- lapply(items, function(it) {
    core <- flatten_order(it$order)
    data.table::set(core, j = "status", value = chr_or_na(it$status))
    data.table::set(
      core,
      j = "status_timestamp",
      value = ms_to_datetime(num_or_na(it$statusTimestamp))
    )
    return(core)
  })
  # An empty response still owes its caller every column; the order shape comes
  # from flatten_order(), extended with the two status columns.
  dt <- if (length(rows) > 0L) {
    data.table::rbindlist(rows, fill = TRUE)
  } else {
    core <- flatten_order(NULL)[0L]
    data.table::set(core, j = "status", value = character(0))
    data.table::set(core, j = "status_timestamp", value = ms_to_datetime(numeric(0)))
    core
  }
  data.table::setcolorder(
    dt,
    c(
      "oid",
      "coin",
      "side",
      "limit_px",
      "sz",
      "orig_sz",
      "order_type",
      "tif",
      "reduce_only",
      "trigger_px",
      "trigger_condition",
      "is_trigger",
      "is_position_tpsl",
      "cloid",
      "timestamp",
      "status",
      "status_timestamp"
    )
  )
  return(dt[])
}

#' Parse a `userFunding` Response
#'
#' One row per funding payment. Each record is a `{time, hash, delta}` envelope
#' whose `delta` (type `"funding"`) carries the per-coin fields; they are lifted
#' to top-level columns.
#'
#' @param items List; the parsed `{type:"userFunding"}` response.
#' @return A [data.table::data.table] with `time`, `hash`, `coin`,
#'   `funding_rate`, `szi`, `usdc`, `n_samples`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_funding <- function(items) {
  if (is.null(items) || length(items) == 0L) {
    return(data.table::data.table(
      time = ms_to_datetime(numeric(0)),
      hash = character(0),
      coin = character(0),
      funding_rate = numeric(0),
      szi = numeric(0),
      usdc = numeric(0),
      n_samples = numeric(0)
    )[])
  }
  rows <- lapply(items, function(it) {
    d <- it$delta
    return(data.table::data.table(
      time = ms_to_datetime(num_or_na(it$time)),
      hash = chr_or_na(it$hash),
      coin = chr_or_na(d$coin),
      funding_rate = num_or_na(d$fundingRate),
      szi = num_or_na(d$szi),
      usdc = num_or_na(d$usdc),
      n_samples = num_or_na(d$nSamples)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `userNonFundingLedgerUpdates` Response
#'
#' Stacks the heterogeneous `{time, hash, delta}` ledger via
#' `parse_delta_ledger()`, renaming the delta's `type` discriminator to
#' `delta_type` and leading with the common columns. Each variant's extra fields
#' (`fee`, `nonce`, `to_perp`, `token`, `amount`, ...) coexist via `fill = TRUE`;
#' nested structures (e.g. `liquidatedPositions`) collapse to a JSON string so no
#' list column is produced. No deduplication is performed.
#'
#' @param items List; the parsed `{type:"userNonFundingLedgerUpdates"}` response.
#' @return A [data.table::data.table] led by `time`, `hash`, `delta_type`,
#'   `usdc`, then the union of the variants' fields; zero-row when empty.
#' @keywords internal
#' @noRd
parse_non_funding_ledger <- function(items) {
  dt <- parse_delta_ledger(items)
  if (nrow(dt) == 0L) {
    # Heterogeneous ledger: only the always-present lead columns are knowable
    # when empty (the per-variant fields appear with data).
    return(data.table::data.table(
      time = ms_to_datetime(numeric(0)),
      hash = character(0),
      delta_type = character(0),
      usdc = numeric(0)
    )[])
  }
  if ("type" %in% names(dt)) {
    data.table::setnames(dt, "type", "delta_type")
  }
  dt <- coerce_numeric_cols(
    dt,
    c(
      "usdc",
      "usdc_value",
      "amount",
      "fee",
      "native_token_fee",
      "liquidated_ntl_pos",
      "account_value"
    )
  )
  lead <- intersect(c("time", "hash", "delta_type", "usdc"), names(dt))
  data.table::setcolorder(dt, c(lead, setdiff(names(dt), lead)))
  return(dt[])
}

#' Parse a `portfolio` Response: Value / PnL History
#'
#' The payload is `[[period, data]]` pairs. Each period's `accountValueHistory`
#' and `pnlHistory` (lists of `[timestamp, value]`) are melted long to one row
#' per (period, metric, point), with `metric` in `account_value` / `pnl`.
#'
#' @param data List; the parsed `{type:"portfolio"}` response.
#' @return A [data.table::data.table] with `period`, `metric`, `time`, `value`;
#'   zero-row when empty.
#' @keywords internal
#' @noRd
parse_portfolio <- function(data) {
  rows <- list()
  for (entry in data) {
    period <- chr_or_na(entry[[1]])
    d <- entry[[2]]
    for (spec in list(
      list(metric = "account_value", history = d$accountValueHistory),
      list(metric = "pnl", history = d$pnlHistory)
    )) {
      for (point in spec$history) {
        rows[[length(rows) + 1L]] <- data.table::data.table(
          period = period,
          metric = spec$metric,
          time = ms_to_datetime(nth_num(point, 1L)),
          value = nth_num(point, 2L)
        )
      }
    }
  }
  if (length(rows) == 0L) {
    return(data.table::data.table(
      period = character(0),
      metric = character(0),
      time = ms_to_datetime(numeric(0)),
      value = numeric(0)
    )[])
  }
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `portfolio` Response: Per-Period Volume
#'
#' Sibling of `parse_portfolio()` over the same payload: one row per period
#' carrying the period's `vlm`.
#'
#' @param data List; the parsed `{type:"portfolio"}` response.
#' @return A [data.table::data.table] with `period`, `vlm`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_portfolio_volume <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table(
      period = character(0),
      vlm = numeric(0)
    )[])
  }
  rows <- lapply(data, function(entry) {
    return(data.table::data.table(
      period = chr_or_na(entry[[1]]),
      vlm = num_or_na(entry[[2]]$vlm)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `userFees` Response: Fee Rates
#'
#' Flattens the user's current fee rates to one row.
#'
#' @param data List; the parsed `{type:"userFees"}` response.
#' @return A single-row [data.table::data.table] with `user_add_rate`,
#'   `user_cross_rate`, `active_referral_discount`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_fees <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table(
      user_add_rate = numeric(0),
      user_cross_rate = numeric(0),
      active_referral_discount = numeric(0)
    )[])
  }
  return(data.table::data.table(
    user_add_rate = num_or_na(data$userAddRate),
    user_cross_rate = num_or_na(data$userCrossRate),
    active_referral_discount = num_or_na(data$activeReferralDiscount)
  )[])
}

#' Parse a `userFees` Response: Daily Volume
#'
#' Sibling of `parse_user_fees()` over the same payload: one row per day in
#' `dailyUserVlm`.
#'
#' @param data List; the parsed `{type:"userFees"}` response.
#' @return A [data.table::data.table] with `date`, `exchange`, `user_add`,
#'   `user_cross`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_volume <- function(data) {
  daily <- data$dailyUserVlm
  if (is.null(daily) || length(daily) == 0L) {
    return(data.table::data.table(
      date = character(0),
      exchange = numeric(0),
      user_add = numeric(0),
      user_cross = numeric(0)
    )[])
  }
  rows <- lapply(daily, function(d) {
    return(data.table::data.table(
      date = chr_or_na(d$date),
      exchange = num_or_na(d$exchange),
      user_add = num_or_na(d$userAdd),
      user_cross = num_or_na(d$userCross)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `userRateLimit` Response
#'
#' @param data List; the parsed `{type:"userRateLimit"}` response.
#' @return A single-row [data.table::data.table] with `cum_vlm`,
#'   `n_requests_used`, `n_requests_cap`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_rate_limit <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table(
      cum_vlm = numeric(0),
      n_requests_used = numeric(0),
      n_requests_cap = numeric(0)
    )[])
  }
  return(data.table::data.table(
    cum_vlm = num_or_na(data$cumVlm),
    n_requests_used = num_or_na(data$nRequestsUsed),
    n_requests_cap = num_or_na(data$nRequestsCap)
  )[])
}

#' Parse a `userRole` Response
#'
#' @param data List; the parsed `{type:"userRole"}` response.
#' @return A single-row [data.table::data.table] with `role`; zero-row when
#'   empty.
#' @keywords internal
#' @noRd
parse_user_role <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table(role = character(0))[])
  }
  return(data.table::data.table(role = chr_or_na(data$role))[])
}

#' Parse a `subAccounts` Response
#'
#' The endpoint returns `null` (not `[]`) for an account with no sub-accounts,
#' which maps to a zero-row table. Otherwise one row per sub-account with its
#' name, address, master, and a flattened cross-margin summary.
#'
#' @param items List or NULL; the parsed `{type:"subAccounts"}` response.
#' @return A [data.table::data.table] with `name`, `sub_account_user`, `master`,
#'   `account_value`, `total_ntl_pos`, `total_raw_usd`, `total_margin_used`,
#'   `withdrawable`; zero-row when null/empty.
#' @keywords internal
#' @noRd
parse_sub_accounts <- function(items) {
  if (is.null(items) || length(items) == 0L) {
    return(data.table::data.table(
      name = character(0),
      sub_account_user = character(0),
      master = character(0),
      account_value = numeric(0),
      total_ntl_pos = numeric(0),
      total_raw_usd = numeric(0),
      total_margin_used = numeric(0),
      withdrawable = numeric(0)
    )[])
  }
  rows <- lapply(items, function(s) {
    ch <- s$clearinghouseState
    ms <- ch$marginSummary
    return(data.table::data.table(
      name = chr_or_na(s$name),
      sub_account_user = chr_or_na(s$subAccountUser),
      master = chr_or_na(s$master),
      account_value = num_or_na(ms$accountValue),
      total_ntl_pos = num_or_na(ms$totalNtlPos),
      total_raw_usd = num_or_na(ms$totalRawUsd),
      total_margin_used = num_or_na(ms$totalMarginUsed),
      withdrawable = num_or_na(ch$withdrawable)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse an `orderStatus` Response
#'
#' Flattens the order-status lookup to one row. The outer `status` (`"order"` or
#' `"unknownOid"`) becomes `query_status`; when the order is found, its fields
#' plus per-order `status` / `status_timestamp` are filled, otherwise those
#' columns are `NA`.
#'
#' @param data List; the parsed `{type:"orderStatus"}` response.
#' @return A single-row [data.table::data.table] with `query_status` and the
#'   order shape (`oid`, `coin`, `side`, ..., `status`, `status_timestamp`);
#'   zero-row when empty.
#' @keywords internal
#' @noRd
parse_order_status <- function(data) {
  # An empty response still owes its caller every column; the order shape comes
  # from flatten_order(), extended with the query/status columns.
  if (is.null(data) || length(data) == 0L) {
    core <- flatten_order(NULL)[0L]
    data.table::set(core, j = "query_status", value = character(0))
    data.table::set(core, j = "status", value = character(0))
    data.table::set(core, j = "status_timestamp", value = ms_to_datetime(numeric(0)))
  } else {
    inner <- data$order
    core <- flatten_order(inner$order)
    data.table::set(core, j = "query_status", value = chr_or_na(data$status))
    data.table::set(core, j = "status", value = chr_or_na(inner$status))
    data.table::set(
      core,
      j = "status_timestamp",
      value = ms_to_datetime(num_or_na(inner$statusTimestamp))
    )
  }
  data.table::setcolorder(
    core,
    c(
      "query_status",
      "oid",
      "coin",
      "side",
      "limit_px",
      "sz",
      "orig_sz",
      "order_type",
      "tif",
      "reduce_only",
      "trigger_px",
      "trigger_condition",
      "is_trigger",
      "is_position_tpsl",
      "cloid",
      "timestamp",
      "status",
      "status_timestamp"
    )
  )
  return(core[])
}

#' Parse a `userVaultEquities` Response
#'
#' One row per vault the user has deposited into.
#'
#' @param items List; the parsed `{type:"userVaultEquities"}` response.
#' @return A [data.table::data.table] with `vault_address`, `equity`,
#'   `locked_until_timestamp`; zero-row when empty.
#' @keywords internal
#' @noRd
parse_user_vault_equities <- function(items) {
  if (is.null(items) || length(items) == 0L) {
    return(data.table::data.table(
      vault_address = character(0),
      equity = numeric(0),
      locked_until_timestamp = ms_to_datetime(numeric(0))
    )[])
  }
  rows <- lapply(items, function(v) {
    return(data.table::data.table(
      vault_address = chr_or_na(v$vaultAddress),
      equity = num_or_na(v$equity),
      locked_until_timestamp = ms_to_datetime(num_or_na(v$lockedUntilTimestamp))
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}
