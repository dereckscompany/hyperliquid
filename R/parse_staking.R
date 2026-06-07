# File: R/parse_staking.R
# Endpoint parsers for the staking domain (delegatorSummary, delegations,
# delegatorRewards, delegatorHistory, and the tokenDelegate write envelope).
# Each turns the raw simplifyVector=FALSE list into one flat, list-column-free
# data.table, composing the generic helpers in R/helpers_parse.R.

#' Parse a `delegatorSummary` Response
#'
#' Flattens the single staking-summary object into a one-row table: the staked
#' (`delegated`) and free (`undelegated`) balances, the total pending
#' withdrawal, and the number of pending withdrawals.
#'
#' @param data A named list (the `{type:"delegatorSummary"}` response), or NULL.
#' @return A single-row [data.table::data.table] with `delegated`,
#'   `undelegated`, `total_pending_withdrawal`, `n_pending_withdrawals`; a
#'   zero-row data.table when empty.
#'
#' @importFrom data.table data.table
#' @keywords internal
#' @noRd
parse_staking_summary <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  return(data.table::data.table(
    delegated = num_or_na(data$delegated),
    undelegated = num_or_na(data$undelegated),
    total_pending_withdrawal = num_or_na(data$totalPendingWithdrawal),
    n_pending_withdrawals = as.integer(coalesce_null(data$nPendingWithdrawals, NA_integer_))
  )[])
}

#' Parse a `delegations` Response
#'
#' Stacks one row per active delegation: the `validator` address, the staked
#' `amount`, and the lockup expiry (`locked_until_timestamp`, a POSIXct).
#'
#' @param items A list of `{validator, amount, lockedUntilTimestamp}` objects,
#'   or NULL.
#' @return A [data.table::data.table] with `validator`, `amount`,
#'   `locked_until_timestamp`; a zero-row data.table when empty.
#'
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noRd
parse_staking_delegations <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(d) {
    return(data.table::data.table(
      validator = chr_or_na(d$validator),
      amount = num_or_na(d$amount),
      locked_until_timestamp = ms_to_datetime(num_or_na(d$lockedUntilTimestamp))
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `delegatorRewards` Response
#'
#' Stacks one row per reward accrual: the accrual `time` (a POSIXct), the
#' `source` (e.g. `"delegation"` or `"commission"`), and the `total_amount`.
#'
#' @param items A list of `{time, source, totalAmount}` objects, or NULL.
#' @return A [data.table::data.table] with `time`, `source`, `total_amount`; a
#'   zero-row data.table when empty.
#'
#' @importFrom data.table data.table rbindlist
#' @keywords internal
#' @noRd
parse_staking_rewards <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(r) {
    return(data.table::data.table(
      time = ms_to_datetime(num_or_na(r$time)),
      source = chr_or_na(r$source),
      total_amount = num_or_na(r$totalAmount)
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a `delegatorHistory` Response
#'
#' Adapts [parse_delta_ledger()] to the staking-history `delta` shape. Unlike
#' the `{type, ...}`-keyed ledgers, each history record's `delta` is a one-key
#' object whose **key** is the discriminator (e.g. `{delegate: {...}}`,
#' `{cDeposit: {...}}`); the inner object holds the variant's fields. This lifts
#' that key into a `delta_type` column, flattens the inner fields, and stacks the
#' heterogeneous rows with `fill = TRUE` so each variant's columns coexist. No
#' deduplication is performed.
#'
#' @param items A list of `{time, hash, delta}` records, or NULL.
#' @return A [data.table::data.table] with `time` (POSIXct), `hash`,
#'   `delta_type`, and the union of the variants' fields (`validator`, `amount`,
#'   `is_undelegate` where present); a zero-row data.table when empty.
#'
#' @importFrom data.table data.table rbindlist setcolorder
#' @keywords internal
#' @noRd
parse_delegator_history <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(it) {
    meta_dt <- data.table::data.table(
      time = ms_to_datetime(num_or_na(it$time)),
      hash = chr_or_na(it$hash)
    )
    delta <- it$delta
    if (is.null(delta) || length(delta) == 0) {
      return(meta_dt)
    }
    type_dt <- data.table::data.table(delta_type = chr_or_na(names(delta)[1]))
    inner_dt <- as_dt_row(delta[[1]])
    if (nrow(inner_dt) == 0L) {
      return(cbind(meta_dt, type_dt))
    }
    return(cbind(meta_dt, type_dt, inner_dt))
  })
  dt <- data.table::rbindlist(rows, fill = TRUE)
  dt <- coerce_numeric_cols(dt, c("amount", "wei"))
  lead <- intersect(c("time", "hash", "delta_type"), names(dt))
  data.table::setcolorder(dt, c(lead, setdiff(names(dt), lead)))
  return(dt[])
}

#' Parse a `tokenDelegate` Write Response
#'
#' Flattens the `/exchange` success envelope (`{status, response:{type}}`) into a
#' one-row acknowledgement. Failures are already aborted upstream by
#' [parse_hyperliquid_response()] before this parser runs.
#'
#' @param data The parsed `/exchange` response, or NULL.
#' @return A single-row [data.table::data.table] with `status` and
#'   `response_type`; a zero-row data.table when empty.
#'
#' @importFrom data.table data.table
#' @keywords internal
#' @noRd
parse_token_delegate <- function(data) {
  if (is.null(data) || length(data) == 0) {
    return(data.table::data.table()[])
  }
  return(data.table::data.table(
    status = chr_or_na(data$status),
    response_type = chr_or_na(data$response$type)
  )[])
}
