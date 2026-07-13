# File: R/conditions.R
# Hyperliquid's typed API-error conditions. Hyperliquid has two failure shapes,
# both funnelled through `parse_hyperliquid_response()`, and they are genuinely
# different surfaces:
#   1. `/info` with a malformed body returns a non-2xx HTTP status (422
#      text/plain). This is a plain HTTP failure, keyed on the status.
#   2. `/exchange` returns HTTP **200** even on failure, with
#      `{status:"err", response:"<string>"}`. This is a venue exchange error on a
#      success status, so it carries NO HTTP status of its own.
#
# Both layer Hyperliquid's own class family IN FRONT of connectcore's, per the
# recipe in `?connectcore_conditions`. The exchange-error surface adds a distinct
# `hyperliquid_exchange_error` class at the very front of the family, so a caller
# can single it out — and, because the 200 status is meaningless for it, it is
# documented no-status: it carries neither a per-status class nor a `status`
# field. A caller can catch `hyperliquid_exchange_error` (the 200-envelope venue
# errors), `hyperliquid_api_error` (any Hyperliquid API failure, HTTP or
# exchange), `connectcore_api_error` (any API failure fleet-wide), or
# `connectcore_error` (any transport failure).
#
# Backward compatibility is a hard contract: the message strings are
# byte-identical to the bare `rlang::abort()` calls this replaced — "Hyperliquid
# HTTP error <status>\n<body>" and "Hyperliquid exchange error: <response>". The
# classes and fields are purely additive.

#' Raise a typed Hyperliquid HTTP API error
#'
#' Signals a condition classed
#' `c("hyperliquid_api_error_<status>", "hyperliquid_api_error",`
#' `"connectcore_api_error_<status>", "connectcore_api_error",`
#' `"connectcore_error")` (on top of rlang's error classes) for a non-2xx HTTP
#' status (Hyperliquid's `/info` malformed-body 422), carrying the HTTP `status`,
#' the request `url` (query-string credentials redacted with
#' [connectcore::scrub_url()]), and the response `body_snippet` as structured
#' fields. The message defaults to the byte-identical
#' `"Hyperliquid HTTP error <status>\n<body>"` string. See
#' [connectcore::connectcore_conditions] for the taxonomy and the subclass recipe.
#'
#' @param status (scalar<count in [100, 599]>) the HTTP status code. Also names
#'   the most specific classes, `hyperliquid_api_error_<status>` and
#'   `connectcore_api_error_<status>`.
#' @param url (scalar<character> | NULL) the request URL; query-string credentials
#'   are redacted with [connectcore::scrub_url()] before storing on the `url`
#'   field. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored on the
#'   `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character> | NULL) the condition message. `NULL`
#'   (default) derives the byte-identical legacy string from `status` and `body`.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#'
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_hyperliquid_error <- function(status, url = NULL, body = NULL, message = NULL) {
  if (is.null(message)) {
    message <- paste0("Hyperliquid HTTP error ", status)
    if (!is.null(body)) {
      message <- paste0(message, "\n", body)
    }
  }
  return(rlang::abort(
    message = message,
    class = c(
      sprintf("hyperliquid_api_error_%d", as.integer(status)),
      "hyperliquid_api_error",
      sprintf("connectcore_api_error_%d", as.integer(status)),
      "connectcore_api_error",
      "connectcore_error"
    ),
    status = as.integer(status),
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}

#' Raise a typed Hyperliquid exchange (200-envelope) error
#'
#' Signals a condition classed
#' `c("hyperliquid_exchange_error", "hyperliquid_api_error",`
#' `"connectcore_api_error", "connectcore_error")` (on top of rlang's error
#' classes) for a `/exchange` failure, which Hyperliquid returns on an HTTP **200**
#' with `{status:"err", response:"<string>"}`. Because the 200 status is
#' meaningless for this surface, the error is **no-status**: it carries neither a
#' per-status class nor a `status` field. It carries the exchange `response`
#' string, the request `url` (credentials redacted), and the response
#' `body_snippet` instead. The message defaults to the byte-identical
#' `"Hyperliquid exchange error: <response>"` string. See
#' [connectcore::connectcore_conditions] for the taxonomy and the subclass recipe.
#'
#' @param response (scalar<character> | NULL) the exchange error string from the
#'   `response` field of the `{status:"err"}` envelope; stored on the `response`
#'   field and rendered into the message.
#' @param url (scalar<character> | NULL) the request URL; query-string credentials
#'   are redacted with [connectcore::scrub_url()] before storing on the `url`
#'   field. Default `NULL`.
#' @param body (scalar<character> | NULL) the response body text; stored on the
#'   `body_snippet` field (named `body_snippet`, not `body`, because
#'   `rlang::abort()` reserves `body`). Default `NULL`.
#' @param message (scalar<character> | NULL) the condition message. `NULL`
#'   (default) derives the byte-identical legacy string from `response`.
#' @return (class<connectcore_error>) never returns normally; signals the classed
#'   condition described above.
#'
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_hyperliquid_exchange_error <- function(response, url = NULL, body = NULL, message = NULL) {
  if (is.null(message)) {
    message <- paste0("Hyperliquid exchange error: ", response)
  }
  return(rlang::abort(
    message = message,
    class = c(
      "hyperliquid_exchange_error",
      "hyperliquid_api_error",
      "connectcore_api_error",
      "connectcore_error"
    ),
    response = response,
    url = connectcore::scrub_url(url),
    body_snippet = body,
    call = rlang::caller_env()
  ))
}

#' Raise a typed Hyperliquid input-validation error
#'
#' Signals a condition classed `c("hyperliquid_validation_error",`
#' `"hyperliquid_error")` (on top of rlang's error classes) for a NON-transport
#' failure: a method's argument, parameter, or credential setup is malformed or
#' violates a rule before any request is made (a bad address / coin / interval /
#' side / cloid, a missing wallet key, an unknown coin or asset id, a non-finite
#' amount). `hyperliquid_error` is the connector's DOMAIN root, parallel to the
#' transport `connectcore_error` root: a validation failure is not a transport
#' failure, so the two roots never meet -- exactly the `core_error` /
#' `connectcore_error` split. The `message` is passed through verbatim, so the
#' string stays byte-identical to the bare `rlang::abort()` this replaced. See
#' [connectcore::connectcore_conditions] for the transport taxonomy.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<hyperliquid_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_hyperliquid_validation_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("hyperliquid_validation_error", "hyperliquid_error"),
    ...,
    call = call
  ))
}

#' Raise a typed Hyperliquid wire-encoding error
#'
#' Signals a condition classed `c("hyperliquid_encoding_error",`
#' `"hyperliquid_error")` (on top of rlang's error classes) for a value that
#' cannot be serialised to the venue's wire format: the msgpack encoder rejecting
#' an unrepresentable integer, an over-long string, a non-finite or unsupported
#' value, or a float-to-wire conversion that would silently round the order.
#' `hyperliquid_error` is the connector's DOMAIN root (see
#' [abort_hyperliquid_validation_error]); an encoding failure is a distinct kind
#' from an input-validation failure, so it carries its own subclass. The `message`
#' is passed through verbatim, so the string stays byte-identical to the bare
#' `rlang::abort()` this replaced.
#'
#' @param message (scalar<character>) the condition message, passed through
#'   verbatim to [rlang::abort()].
#' @param ... structured fields stored on the condition, read with `e[["field"]]`.
#'   Forwarded to [rlang::abort()].
#' @param call (environment) the environment blamed in the traceback; defaults to
#'   the caller via [rlang::caller_env()].
#' @return (class<hyperliquid_error>) never returns normally; signals the classed
#'   condition described above.
#' @importFrom rlang abort caller_env
#' @keywords internal
#' @noassert
#' @noRd
abort_hyperliquid_encoding_error <- function(message, ..., call = rlang::caller_env()) {
  return(rlang::abort(
    message = message,
    class = c("hyperliquid_encoding_error", "hyperliquid_error"),
    ...,
    call = call
  ))
}
