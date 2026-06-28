# File: R/helpers_parse.R
# Generic response-flattening helpers for the hyperliquid package. They turn the
# raw parsed JSON (numbers as strings, timestamps as epoch milliseconds, nested
# objects, parallel positional arrays, and {time, hash, delta} discriminated
# ledgers) into flat, list-column-free data.tables. Endpoint-specific parsers
# (built next) compose these.

#' Return `x`, or `default` When `x` Is NULL
#'
#' A plainly-named, readable null-coalescing helper: it initialises with the
#' default and updates only when `x` is present. Used for the many inline field
#' defaults where an init-then-update statement cannot be written (i.e. inside a
#' `data.table()` call), in place of a `%||%` operator.
#'
#' @param x A value or NULL.
#' @param default The value to use when `x` is NULL.
#' @return `x` when it is non-NULL, otherwise `default`.
#'
#' @examples
#' coalesce_null(NULL, NA_character_)
#' coalesce_null("BTC", NA_character_)
#'
#' @keywords internal
#' @noRd
coalesce_null <- function(x, default) {
  result <- default
  if (!is.null(x)) {
    result <- x
  }
  return(result)
}

#' Coerce a Possibly-NULL Numeric-String Scalar to Numeric
#'
#' Hyperliquid returns nearly every number as a JSON string. This parses one to
#' a numeric, mapping NULL, an empty string, or a zero-length value to
#' `NA_real_`.
#'
#' @param x A scalar (string or number) or NULL.
#' @return Numeric scalar, or `NA_real_` when absent/blank.
#'
#' @examples
#' num_or_na("123.45")
#' num_or_na("")
#' num_or_na(NULL)
#'
#' @keywords internal
#' @noRd
num_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_real_)
  }
  if (is.character(x) && !nzchar(x)) {
    return(NA_real_)
  }
  return(suppressWarnings(as.numeric(x)))
}

#' Coerce a Possibly-NULL Scalar to Character
#'
#' @param x A scalar or NULL.
#' @return Character scalar, or `NA_character_` when NULL/zero-length.
#'
#' @examples
#' chr_or_na("0xabc")
#' chr_or_na(NULL)
#'
#' @keywords internal
#' @noRd
chr_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  return(as.character(x))
}

#' Coerce a Possibly-NULL Scalar to Logical
#'
#' @param x A scalar or NULL.
#' @return Logical scalar, or `NA` when NULL/zero-length.
#'
#' @examples
#' lgl_or_na(TRUE)
#' lgl_or_na(NULL)
#'
#' @keywords internal
#' @noRd
lgl_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA)
  }
  return(as.logical(x))
}

#' Safely Read the i-th Element of a Positional Array as Numeric
#'
#' Hyperliquid returns several structures as positional arrays (e.g.
#' `metaAndAssetCtxs` = `[meta, ctxs]`, `portfolio` = `[[period, data]]`). A
#' short or partial array would make `x[[i]]` raise a subscript error; this
#' returns `NA_real_` instead when the element is missing, NULL, or blank.
#'
#' @param x A list/vector, or NULL.
#' @param i Integer; the element index.
#' @return `as.numeric(x[[i]])`, or `NA_real_` when absent/blank.
#'
#' @examples
#' nth_num(list("1.5", "2.5"), 2L)
#' nth_num(list("1.5"), 5L)
#'
#' @keywords internal
#' @noRd
nth_num <- function(x, i) {
  if (length(x) < i || is.null(x[[i]]) || identical(x[[i]], "")) {
    return(NA_real_)
  }
  return(suppressWarnings(as.numeric(x[[i]])))
}

#' Safely Read the i-th Element of a Positional Array as Character
#'
#' @param x A list/vector, or NULL.
#' @param i Integer; the element index.
#' @return `as.character(x[[i]])`, or `NA_character_` when absent.
#'
#' @examples
#' nth_chr(list("a", "b"), 1L)
#' nth_chr(list("a"), 9L)
#'
#' @keywords internal
#' @noRd
nth_chr <- function(x, i) {
  if (length(x) < i || is.null(x[[i]])) {
    return(NA_character_)
  }
  return(as.character(x[[i]]))
}

#' Convert camelCase Names to snake_case
#'
#' Converts response field names to R's snake_case convention. Hyperliquid
#' fields are predominantly camelCase (`szDecimals`, `marginTableId`), so this
#' lowercases them while inserting underscores at case boundaries. Only the case
#' changes; the field is never otherwise renamed.
#'
#' @param x Character vector; names to convert.
#' @return Character vector; converted snake_case names.
#'
#' @examples
#' to_snake_case(c("szDecimals", "marginTableId", "coin"))
#'
#' @keywords internal
#' @noRd
to_snake_case <- function(x) {
  out <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  out <- gsub("([A-Z])([A-Z][a-z])", "\\1_\\2", out)
  out <- tolower(out)
  return(out)
}

#' Convert a Named List to a Single-Row data.table
#'
#' Converts a flat named list (from a Hyperliquid JSON object) into a single-row
#' [data.table::data.table]. NULL or empty values become `NA`. Any nested
#' object/array or multi-element value is collapsed to a single JSON string, so
#' the result is guaranteed to contain **no list columns** (and never
#' row-recycles) even if the API returns an unexpectedly nested field. Column
#' names are snake_cased.
#'
#' @param x A named list, or NULL.
#' @return A single-row [data.table::data.table] with snake_case column names;
#'   a zero-row data.table when `x` is NULL or empty.
#'
#' @examples
#' as_dt_row(list(coin = "BTC", szDecimals = 5, ctx = list(a = 1, b = 2)))
#'
#' @keywords internal
#' @noRd
as_dt_row <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(data.table::data.table()[])
  }
  x <- lapply(x, function(val) {
    if (is.null(val)) {
      return(NA)
    }
    if (is.list(val) && length(val) == 0) {
      return(NA)
    }
    # Enforce the no-list-column contract: collapse any nested object/array or
    # multi-element value to a single JSON string rather than a list column.
    if (is.list(val) || length(val) != 1L) {
      return(as.character(jsonlite::toJSON(val, auto_unbox = TRUE, null = "null")))
    }
    return(val)
  })
  dt <- data.table::as.data.table(x)
  data.table::setnames(dt, to_snake_case(names(dt)))
  return(dt[])
}

#' Convert a List of Named Lists to a data.table
#'
#' Row-binds a list whose elements are named lists (a JSON array of objects)
#' into a [data.table::data.table] with snake_case columns, padding absent
#' fields with `NA` (`fill = TRUE`). This is also the discriminator-stacking
#' primitive: heterogeneous rows that each carry a `type`-style field stack into
#' one table with the union of columns.
#'
#' @param items A list of named lists, or NULL.
#' @return A [data.table::data.table]; zero-row if `items` is NULL or empty.
#'
#' @examples
#' as_dt_list(list(list(a = 1, b = 2), list(a = 3, c = 4)))
#'
#' @keywords internal
#' @noRd
as_dt_list <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(lapply(items, as_dt_row), fill = TRUE)
  return(dt[])
}

#' Coerce a Set of Known Columns to Numeric In Place
#'
#' Many Hyperliquid numeric fields arrive as strings. After flattening with
#' `as_dt_row()` / `as_dt_list()`, this coerces the named columns (those that
#' are present) to numeric **by reference** with [data.table::set], leaving
#' columns the response did not include untouched.
#'
#' @param dt A [data.table::data.table] (modified in place).
#' @param cols Character vector; the column names to coerce to numeric.
#' @return The same `dt`, invisibly, with the listed columns coerced.
#'
#' @examples
#' dt <- data.table::data.table(px = c("100.5", ""), sz = c("1", "2"))
#' coerce_numeric_cols(dt, c("px", "sz"))
#'
#' @keywords internal
#' @noRd
coerce_numeric_cols <- function(dt, cols) {
  present <- intersect(cols, names(dt))
  for (col in present) {
    data.table::set(dt, j = col, value = suppressWarnings(as.numeric(dt[[col]])))
  }
  return(dt[])
}

#' Parse a {time, hash, delta} Discriminated Ledger into a data.table
#'
#' Hyperliquid ledger endpoints (e.g. `userNonFundingLedgerUpdates`) return one
#' record per update shaped `{time, hash, delta}`, where `delta` is an object
#' whose `type` field discriminates the variant and whose remaining fields
#' differ per variant. This flattens each record to a row carrying the `time`
#' (as a POSIXct), the `hash`, and the delta's fields (including the `type`
#' discriminator), then stacks the heterogeneous rows with `fill = TRUE` so each
#' variant's columns coexist. No deduplication is performed.
#'
#' @param items A list of `{time, hash, delta}` records, or NULL.
#' @return A [data.table::data.table], one row per record; zero-row when empty.
#'   No list columns.
#'
#' @examples
#' parse_delta_ledger(list(
#'   list(time = 1700000000000, hash = "0xabc",
#'        delta = list(type = "deposit", usdc = "100.5"))
#' ))
#'
#' @keywords internal
#' @noRd
parse_delta_ledger <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(it) {
    meta_dt <- data.table::data.table(
      time = ms_to_datetime(num_or_na(it$time)),
      hash = chr_or_na(it$hash)
    )
    delta_dt <- as_dt_row(it$delta)
    if (nrow(delta_dt) == 0L) {
      return(meta_dt)
    }
    return(cbind(meta_dt, delta_dt))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

# ---- Typed empty constructors ----
#
# Each `empty_dt_<descriptive>()` returns a zero-row data.table whose columns
# match the corresponding endpoint parser's populated shape (every column
# present, correctly typed). An empty live response (a flat account, a coin with
# no funding events, an order book with no levels) still owes its caller every
# documented column, and the methods' typed `@return` contracts (`assert_has_columns`)
# require them, which a bare `data.table()` would not carry. Each parser's empty
# branch substitutes the matching constructor here instead of inlining the
# schema, so the shape is defined once. Timestamp columns are built with
# `ms_to_datetime(numeric(0))`, the same coercion the parsers apply, so the empty
# column's class and tz match a populated one exactly.
#
# The schema-agnostic flattening primitives above (`as_dt_row()`, `as_dt_list()`,
# `parse_delta_ledger()`) have no fixed column set and so return a bare
# `data.table()`; the discriminated-ledger endpoint parsers contribute only their
# always-present lead columns (`time`, `hash`, `delta_type`).

## Account domain --------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_positions <- function() {
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

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_margin_summary <- function() {
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

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_spot_balances <- function() {
  return(data.table::data.table(
    coin = character(0),
    total = numeric(0),
    hold = numeric(0),
    entry_ntl = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_open_orders <- function() {
  return(data.table::data.table(
    coin = character(0),
    oid = numeric(0),
    side = character(0),
    limit_px = numeric(0),
    sz = numeric(0),
    timestamp = ms_to_datetime(numeric(0))
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_frontend_open_orders <- function() {
  return(data.table::data.table(
    coin = character(0),
    oid = numeric(0),
    side = character(0),
    limit_px = numeric(0),
    sz = numeric(0),
    timestamp = ms_to_datetime(numeric(0)),
    order_type = character(0),
    is_trigger = logical(0),
    trigger_px = numeric(0),
    trigger_condition = character(0),
    reduce_only = logical(0),
    tif = character(0),
    orig_sz = numeric(0),
    is_position_tpsl = logical(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_fills <- function() {
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

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_historical_orders <- function() {
  return(data.table::data.table(
    oid = numeric(0),
    coin = character(0),
    side = character(0),
    limit_px = numeric(0),
    sz = numeric(0),
    orig_sz = numeric(0),
    order_type = character(0),
    tif = character(0),
    reduce_only = logical(0),
    trigger_px = numeric(0),
    trigger_condition = character(0),
    is_trigger = logical(0),
    is_position_tpsl = logical(0),
    cloid = character(0),
    timestamp = ms_to_datetime(numeric(0)),
    status = character(0),
    status_timestamp = ms_to_datetime(numeric(0))
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_funding <- function() {
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

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_non_funding_ledger <- function() {
  return(data.table::data.table(
    time = ms_to_datetime(numeric(0)),
    hash = character(0),
    delta_type = character(0),
    usdc = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_portfolio <- function() {
  return(data.table::data.table(
    period = character(0),
    metric = character(0),
    time = ms_to_datetime(numeric(0)),
    value = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_portfolio_volume <- function() {
  return(data.table::data.table(
    period = character(0),
    vlm = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_fees <- function() {
  return(data.table::data.table(
    user_add_rate = numeric(0),
    user_cross_rate = numeric(0),
    active_referral_discount = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_volume <- function() {
  return(data.table::data.table(
    date = character(0),
    exchange = numeric(0),
    user_add = numeric(0),
    user_cross = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_rate_limit <- function() {
  return(data.table::data.table(
    cum_vlm = numeric(0),
    n_requests_used = numeric(0),
    n_requests_cap = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_role <- function() {
  return(data.table::data.table(
    role = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_sub_accounts <- function() {
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

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_order_status <- function() {
  return(data.table::data.table(
    query_status = character(0),
    oid = numeric(0),
    coin = character(0),
    side = character(0),
    limit_px = numeric(0),
    sz = numeric(0),
    orig_sz = numeric(0),
    order_type = character(0),
    tif = character(0),
    reduce_only = logical(0),
    trigger_px = numeric(0),
    trigger_condition = character(0),
    is_trigger = logical(0),
    is_position_tpsl = logical(0),
    cloid = character(0),
    timestamp = ms_to_datetime(numeric(0)),
    status = character(0),
    status_timestamp = ms_to_datetime(numeric(0))
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_user_vault_equities <- function() {
  return(data.table::data.table(
    vault_address = character(0),
    equity = numeric(0),
    locked_until_timestamp = ms_to_datetime(numeric(0))
  )[])
}

## Market-data domain ----------------------------------------------------------

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_meta <- function() {
  return(data.table::data.table(
    name = character(0),
    sz_decimals = numeric(0),
    max_leverage = numeric(0),
    margin_table_id = numeric(0),
    only_isolated = logical(0),
    is_delisted = logical(0),
    margin_mode = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_spot_meta_universe <- function() {
  return(data.table::data.table(
    name = character(0),
    index = numeric(0),
    is_canonical = logical(0),
    token_base = numeric(0),
    token_quote = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_spot_tokens <- function() {
  return(data.table::data.table(
    name = character(0),
    index = numeric(0),
    sz_decimals = numeric(0),
    wei_decimals = numeric(0),
    token_id = character(0),
    is_canonical = logical(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_meta_and_asset_ctxs <- function() {
  return(data.table::data.table(
    name = character(0),
    sz_decimals = numeric(0),
    max_leverage = numeric(0),
    day_ntl_vlm = numeric(0),
    funding = numeric(0),
    mark_px = numeric(0),
    mid_px = numeric(0),
    oracle_px = numeric(0),
    open_interest = numeric(0),
    premium = numeric(0),
    prev_day_px = numeric(0),
    impact_px_bid = numeric(0),
    impact_px_ask = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_spot_meta_and_asset_ctxs <- function() {
  return(data.table::data.table(
    coin = character(0),
    day_ntl_vlm = numeric(0),
    mark_px = numeric(0),
    mid_px = numeric(0),
    prev_day_px = numeric(0),
    circulating_supply = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_all_mids <- function() {
  return(data.table::data.table(
    coin = character(0),
    mid = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_l2_book <- function() {
  return(data.table::data.table(
    side = character(0),
    level = integer(0),
    px = numeric(0),
    sz = numeric(0),
    n = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_candles <- function() {
  return(data.table::data.table(
    datetime = ms_to_datetime(numeric(0)),
    open = numeric(0),
    high = numeric(0),
    low = numeric(0),
    close = numeric(0),
    volume = numeric(0),
    trades = numeric(0),
    close_time = ms_to_datetime(numeric(0)),
    interval = character(0),
    coin = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_funding_history <- function() {
  return(data.table::data.table(
    coin = character(0),
    funding_rate = numeric(0),
    premium = numeric(0),
    time = ms_to_datetime(numeric(0))
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_predicted_fundings <- function() {
  return(data.table::data.table(
    coin = character(0),
    venue = character(0),
    funding_rate = numeric(0),
    next_funding_time = ms_to_datetime(numeric(0)),
    funding_interval_hours = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_perp_dexs <- function() {
  return(data.table::data.table(
    name = character(0),
    full_name = character(0),
    deployer = character(0),
    oracle_updater = character(0),
    fee_recipient = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_recent_trades <- function() {
  return(data.table::data.table(
    coin = character(0),
    side = character(0),
    px = numeric(0),
    sz = numeric(0),
    time = ms_to_datetime(numeric(0)),
    hash = character(0),
    tid = numeric(0),
    user_buyer = character(0),
    user_seller = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_exchange_status <- function() {
  return(data.table::data.table(
    time = ms_to_datetime(numeric(0)),
    special_statuses = character(0)
  )[])
}

## Staking domain --------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_staking_summary <- function() {
  return(data.table::data.table(
    delegated = numeric(0),
    undelegated = numeric(0),
    total_pending_withdrawal = numeric(0),
    n_pending_withdrawals = integer(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_staking_delegations <- function() {
  return(data.table::data.table(
    validator = character(0),
    amount = numeric(0),
    locked_until_timestamp = ms_to_datetime(numeric(0))
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_staking_rewards <- function() {
  return(data.table::data.table(
    time = ms_to_datetime(numeric(0)),
    source = character(0),
    total_amount = numeric(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_delegator_history <- function() {
  return(data.table::data.table(
    time = ms_to_datetime(numeric(0)),
    hash = character(0),
    delta_type = character(0)
  )[])
}

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_token_delegate <- function() {
  return(data.table::data.table(
    status = character(0),
    response_type = character(0)
  )[])
}

## Transfers domain ------------------------------------------------------------

#' @keywords internal
#' @noRd
#' @noassert
empty_dt_transfer_ack <- function() {
  return(data.table::data.table(
    status = character(0),
    response_type = character(0)
  )[])
}
