# File: R/helpers_validate.R
# Internal, per-concern input validators shared across the client classes. Each
# aborts with an actionable, example-bearing message before any request is
# signed or sent, and returns the canonicalised value where one exists.

#' Validate an Ethereum Address
#'
#' @param x Character; a `0x`-prefixed 40-hex-character Ethereum address.
#' @return The lowercased address; aborts on anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_address <- function(x) {
  assert::assert_scalar_character(x)
  if (!grepl("^0[xX][0-9a-fA-F]{40}$", x)) {
    rlang::abort(paste0(
      "Invalid address '", x, "'. Expected a 0x-prefixed 40-hex-character ",
      "Ethereum address, e.g. \"0x5e9ee1089755c3435139848e47e6635505d5a13a\"."
    ))
  }
  return(tolower(x))
}

#' Validate a Coin / Name Symbol
#'
#' Accepts any non-empty scalar string; Hyperliquid coins take several forms
#' (`"BTC"`, `"@107"`, `"HYPE/USDC"`, `"dex:COIN"`) and friendly-name resolution
#' to an asset id happens later against fetched metadata.
#'
#' @param x Character; a coin or friendly name.
#' @return `x` unchanged; aborts when empty or non-scalar.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_coin <- function(x) {
  assert::assert_scalar_character(x)
  if (!nzchar(x)) {
    rlang::abort(
      "`coin` must be a non-empty string, e.g. \"BTC\", \"@107\", or \"HYPE/USDC\"."
    )
  }
  return(x)
}

#' Validate a Candle Interval
#'
#' @param x Character; one of the 14 [HYPERLIQUID_INTERVALS] codes.
#' @return `x` unchanged; aborts on anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_interval <- function(x) {
  assert::assert_scalar_character(x)
  if (!x %in% HYPERLIQUID_INTERVALS) {
    rlang::abort(paste0(
      "Invalid interval '", x, "'. Expected one of: ",
      paste(HYPERLIQUID_INTERVALS, collapse = ", "), "."
    ))
  }
  return(x)
}

#' Validate an Order Side
#'
#' @param side Character; `"buy"` or `"sell"` (case-insensitive).
#' @return The lowercased side (`"buy"`/`"sell"`); aborts on anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_side <- function(side) {
  assert::assert_scalar_character(side)
  low <- tolower(side)
  if (!low %in% names(ORDER_SIDE)) {
    rlang::abort(paste0("Invalid side '", side, "'. Expected \"buy\" or \"sell\"."))
  }
  return(low)
}

#' Coerce an Order Side to the `is_buy` Boolean
#'
#' Hyperliquid order wires carry the side as a boolean `b` (`TRUE` = buy / bid,
#' `FALSE` = sell / ask). This validates the friendly side and returns that
#' boolean.
#'
#' @param side Character; `"buy"` or `"sell"` (case-insensitive).
#' @return Logical; `TRUE` for buy, `FALSE` for sell. Aborts on anything else.
#'
#' @examples
#' side_to_is_buy("buy")
#' side_to_is_buy("SELL")
#'
#' @keywords internal
#' @noRd
side_to_is_buy <- function(side) {
  return(identical(validate_side(side), "buy"))
}

#' Validate a Client Order Id (cloid)
#'
#' @param x Character; a `0x`-prefixed 32-hex-character (16-byte) cloid, as
#'   produced by [new_cloid()].
#' @return The lowercased cloid; aborts on anything else.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
validate_cloid <- function(x) {
  assert::assert_scalar_character(x)
  if (!grepl("^0[xX][0-9a-fA-F]{32}$", x)) {
    rlang::abort(paste0(
      "Invalid cloid '", x, "'. Expected a 0x-prefixed 32-hex-character client ",
      "order id (16 bytes), e.g. the output of new_cloid()."
    ))
  }
  return(tolower(x))
}

#' Assert a Finite, Strictly-Positive Scalar Amount
#'
#' The house validator for amounts typed inline as `scalar<numeric in ]0, Inf[>`
#' at the call sites (prices, sizes, transfer amounts). It first checks the
#' scalar-numeric type with [assert::assert_scalar_numeric], then enforces a
#' finite value strictly greater than zero (rejecting `0`, negatives, `NA`,
#' `NaN`, and `Inf`, none of which `assert_between`'s inclusive lower bound would
#' catch).
#'
#' @param x A scalar numeric amount.
#' @param name Character; the parameter name, for the error message.
#' @return `x`, invisibly; aborts on anything else.
#'
#' @examples
#' assert_finite_positive(10.5, "amount")
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
assert_finite_positive <- function(x, name) {
  assert::assert_scalar_numeric(x)
  if (!is.finite(x) || x <= 0) {
    rlang::abort(sprintf(
      "`%s` must be a single finite number greater than 0 (in ]0, Inf[), got: %s",
      name, format(x)
    ))
  }
  return(invisible(x))
}
