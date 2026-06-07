# File: R/parse_transfers.R
# Response parser for HyperliquidTransfers. Every /exchange transfer action
# returns the same acknowledgement envelope -- {status:"ok", response:{type:
# "default"}} -- so a single parser flattens it to one row carrying the status
# and the response type discriminator.

#' Parse a Transfer-Action Acknowledgement
#'
#' Hyperliquid's transfer/collateral-movement actions (`usdClassTransfer`,
#' `usdSend`, `spotSend`, `withdraw3`, `sendAsset`, `subAccountTransfer`,
#' `subAccountSpotTransfer`, `vaultTransfer`) all return the same envelope:
#' `{status:"ok", response:{type:"default"}}`. Failures are already aborted
#' upstream by `parse_hyperliquid_response()`, so a success body always carries a
#' `status` and a nested `response` object. This flattens it to a single-row
#' [data.table::data.table] with `status` and `response_type`.
#'
#' @param body The parsed JSON acknowledgement (a named list), or NULL.
#' @return A single-row [data.table::data.table] with `status` and
#'   `response_type`; a zero-row data.table when `body` is NULL or empty. No list
#'   columns.
#'
#' @examples
#' parse_transfer_ack(list(status = "ok", response = list(type = "default")))
#'
#' @keywords internal
#' @noRd
parse_transfer_ack <- function(body) {
  if (is.null(body) || length(body) == 0) {
    return(data.table::data.table()[])
  }
  resp <- body$response
  resp_type <- NA_character_
  if (!is.null(resp)) {
    if (is.list(resp)) {
      resp_type <- chr_or_na(resp$type)
    } else {
      resp_type <- chr_or_na(resp)
    }
  }
  return(data.table::data.table(
    status = chr_or_na(body$status),
    response_type = resp_type
  )[])
}
