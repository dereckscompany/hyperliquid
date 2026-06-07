# File: R/utils_time.R
# Time conversion helpers. Hyperliquid timestamps are epoch milliseconds; all
# conversions go through lubridate and are handled in UTC.

#' Convert an Epoch-Milliseconds Timestamp to POSIXct
#'
#' @param x Numeric vector; epoch milliseconds (the form Hyperliquid returns for
#'   every timestamp field).
#' @return POSIXct vector in UTC. Use [lubridate::with_tz()] to view elsewhere.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
ms_to_datetime <- function(x) {
  return(lubridate::as_datetime(as.numeric(x) / 1000, tz = "UTC"))
}

#' Coerce a Datetime to Epoch Milliseconds
#'
#' Normalises a POSIXct, Date, or datetime-like value to UTC via
#' [lubridate::as_datetime()] and returns whole-number epoch milliseconds, the
#' form the Hyperliquid API expects for time bounds and nonces.
#'
#' @param x A POSIXct, Date, or value coercible by [lubridate::as_datetime()].
#' @return Numeric; whole-number epoch milliseconds. `NULL` passes through as
#'   `NULL`.
#'
#' @importFrom lubridate as_datetime
#' @keywords internal
#' @noRd
datetime_to_ms <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  # Keep this a double, never as.integer(): epoch milliseconds are ~1.7e12 today
  # and always exceed the 32-bit integer range (which itself caps at 2038-01-19
  # in seconds), so as.integer() would silently yield NA. A whole-number double
  # serialises cleanly with no scientific notation in the JSON body.
  return(floor(as.numeric(lubridate::as_datetime(x, tz = "UTC")) * 1000))
}

#' Convert a Hyperliquid Timestamp to POSIXct
#'
#' Hyperliquid returns every timestamp as epoch milliseconds. This converts that
#' form to a POSIXct in UTC.
#'
#' @param time_value Numeric; epoch milliseconds.
#' @return POSIXct vector in UTC.
#'
#' @examples
#' time_convert_from_hyperliquid(1700000000000)
#'
#' @export
time_convert_from_hyperliquid <- function(time_value) {
  return(ms_to_datetime(time_value))
}

#' Convert a POSIXct to a Hyperliquid Timestamp
#'
#' Formats a POSIXct as the timestamp form Hyperliquid expects: whole-number
#' epoch milliseconds.
#'
#' @param datetime POSIXct object(s) to convert.
#' @return Numeric; whole-number epoch milliseconds.
#'
#' @examples
#' dt <- lubridate::as_datetime("2023-11-14 22:13:20", tz = "UTC")
#' time_convert_to_hyperliquid(dt)
#'
#' @importFrom rlang abort
#' @export
time_convert_to_hyperliquid <- function(datetime) {
  if (!inherits(datetime, "POSIXct")) {
    rlang::abort("`datetime` must be a POSIXct object.")
  }
  return(datetime_to_ms(datetime))
}
