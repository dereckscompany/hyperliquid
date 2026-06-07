# File: R/parse_trading.R
# Endpoint parsers for the signed /exchange trading actions. Each turns the
# {status, response:{type, data}} envelope Hyperliquid returns into one flat,
# list-column-free data.table. The order/batchModify, cancel/cancelByCloid, and
# the simple "default" actions each have their own shape, so each gets its own
# parser; the class methods pass these as the .parser closure to .submit_l1 /
# .submit_user.

#' Flatten an Order Action's Per-Order Statuses
#'
#' The `order` and `batchModify` actions return
#' `{response:{type:"order", data:{statuses:[...]}}}`, with one status per
#' submitted order. Each status is a single-key object discriminated by its key:
#' `{resting:{oid}}`, `{filled:{oid, totalSz, avgPx}}`, or `{error:"..."}`
#' (trigger orders may add other keys, handled generically). This stacks them
#' one row per status, the key as the `status` discriminator.
#'
#' @param statuses A list of per-order status objects, or NULL.
#' @return A [data.table::data.table] with `status`, `oid`, `total_sz`,
#'   `avg_px`, and `error`; a zero-row table when empty.
#' @keywords internal
#' @noRd
parse_order_statuses <- function(statuses) {
  empty <- data.table::data.table(
    status = character(),
    oid = numeric(),
    total_sz = numeric(),
    avg_px = numeric(),
    error = character()
  )
  if (is.null(statuses) || length(statuses) == 0L) {
    return(empty[])
  }
  rows <- lapply(statuses, function(st) {
    if (!is.list(st)) {
      return(data.table::data.table(
        status = as.character(st),
        oid = NA_real_,
        total_sz = NA_real_,
        avg_px = NA_real_,
        error = NA_character_
      ))
    }
    key <- names(st)[1]
    if (identical(key, "error")) {
      return(data.table::data.table(
        status = "error",
        oid = NA_real_,
        total_sz = NA_real_,
        avg_px = NA_real_,
        error = chr_or_na(st$error)
      ))
    }
    inner <- st[[1]]
    return(data.table::data.table(
      status = chr_or_na(key),
      oid = num_or_na(inner$oid),
      total_sz = num_or_na(inner$totalSz),
      avg_px = num_or_na(inner$avgPx),
      error = NA_character_
    ))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse an Order / batchModify Action Response
#'
#' @param resp The parsed `{status, response:{type:"order", data:{statuses}}}`
#'   body.
#' @return A [data.table::data.table], one row per submitted order's status.
#' @keywords internal
#' @noRd
parse_order_response <- function(resp) {
  return(parse_order_statuses(resp$response$data$statuses))
}

#' Parse a cancel / cancelByCloid Action Response
#'
#' The `cancel` and `cancelByCloid` actions return
#' `{response:{type:"cancel", data:{statuses:[...]}}}`, one status per cancel.
#' Each status is either the string `"success"` or an `{error:"..."}` object.
#'
#' @param resp The parsed `{status, response:{type:"cancel", data:{statuses}}}`
#'   body.
#' @return A [data.table::data.table] with `status` and `error`, one row per
#'   cancel; a zero-row table when empty.
#' @keywords internal
#' @noRd
parse_cancel_response <- function(resp) {
  statuses <- resp$response$data$statuses
  empty <- data.table::data.table(status = character(), error = character())
  if (is.null(statuses) || length(statuses) == 0L) {
    return(empty[])
  }
  rows <- lapply(statuses, function(st) {
    if (is.list(st)) {
      return(data.table::data.table(
        status = coalesce_null(names(st)[1], "error"),
        error = chr_or_na(st[[1]])
      ))
    }
    return(data.table::data.table(status = as.character(st), error = NA_character_))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

#' Parse a Simple Action Status Envelope
#'
#' Most non-order actions (`scheduleCancel`, `updateLeverage`,
#' `updateIsolatedMargin`, `approveAgent`, `approveBuilderFee`) return a bare
#' `{status:"ok", response:{type:"default"}}` envelope with no per-row data.
#' This flattens that to a single row.
#'
#' @param resp The parsed `{status, response:{type}}` body.
#' @return A single-row [data.table::data.table] with `status` and
#'   `response_type`.
#' @keywords internal
#' @noRd
parse_action_status <- function(resp) {
  return(data.table::data.table(
    status = chr_or_na(resp$status),
    response_type = chr_or_na(resp$response$type)
  ))
}
