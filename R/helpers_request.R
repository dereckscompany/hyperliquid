# File: R/helpers_request.R
# Hyperliquid's request funnel and error envelope. The connector now owns NO
# transport: the request is built, performed, and sync/async-branched entirely
# by connectcore's shared funnel ([connectcore::build_request()]). Only what is
# genuinely Hyperliquid-specific lives here — the byte-exact body serialisation
# (both POST paths carry a body-signed JSON payload that must hit the wire
# exactly as it was signed) and the two-failure-shape response parser.

#' Build and Execute a Hyperliquid API Request
#'
#' Serialises `body` to the byte-exact signed JSON and routes it through
#' [connectcore::build_request()] as a raw body, to one of Hyperliquid's two
#' POST endpoints (`/info` or `/exchange`). This is the single point through
#' which all Hyperliquid API calls flow.
#'
#' Hyperliquid authenticates by signing the request **body** (a wallet signature
#' embedded as a `signature` field), not the HTTP request, and requires the body
#' on the wire exactly as it was signed — including `vaultAddress`/`expiresAfter`
#' serialised as JSON `null`. The body is therefore pre-serialised here with
#' `jsonlite::toJSON(..., auto_unbox = TRUE, null = "null")` and passed to
#' connectcore's funnel with `body_format = "raw"`, which sends it byte-verbatim
#' via [httr2::req_body_raw] — no `NULL`-pruning, no re-encoding — so the exact
#' signed bytes reach the wire. (The default request-signing `.sign` seam is a
#' no-op for Hyperliquid; signing happens in the body content, not the request.)
#'
#' ### Sync vs Async
#' The `.perform` argument controls execution mode:
#' - `httr2::req_perform` (default): synchronous, returns an [httr2::response].
#' - `httr2::req_perform_promise`: asynchronous, returns a [promises::promise].
#'
#' Errors are surfaced by `parse_envelope`, not httr2: connectcore's funnel
#' disables httr2's auto-error so the API's own error body (HTTP 422 text for
#' `/info`, an `{status:"err"}` envelope for `/exchange`) is formatted by the
#' parser.
#'
#' @param base_url (scalar<character>) the REST base URL (scheme + host).
#' @param path (scalar<character>) the endpoint path, `"/info"` or
#'   `"/exchange"`.
#' @param body (list) the request body, serialised with `auto_unbox`.
#' @param .perform (function) the httr2 perform function. Default
#'   `httr2::req_perform`.
#' @param .parser (function) post-processing applied to the parsed response
#'   body. Default `identity`.
#' @param is_async (scalar<logical>) whether `.perform` returns promises.
#'   Default `FALSE`.
#' @param timeout (scalar<numeric in ]0, Inf[>) request timeout in seconds.
#'   Default `30`.
#' @param parse_envelope (function) turns a response into data and raises on
#'   error; the overridable error seam. Default `parse_hyperliquid_response()`.
#' @return (any) parsed and post-processed API response data, or a promise
#'   thereof.
#'
#' @importFrom jsonlite toJSON
#' @importFrom httr2 req_perform
#' @export
hyperliquid_build_request <- function(
  base_url,
  path,
  body,
  .perform = httr2::req_perform,
  .parser = identity,
  is_async = FALSE,
  timeout = 30,
  parse_envelope = parse_hyperliquid_response
) {
  assert_args_hyperliquid_build_request(
    base_url,
    path,
    body,
    .perform,
    .parser,
    is_async,
    timeout,
    parse_envelope
  )
  # Pre-serialise to the byte-exact signed JSON, then send it byte-verbatim
  # through connectcore's funnel as a raw body. `null = "null"` keeps
  # vaultAddress/expiresAfter as JSON null (the raw path does not prune them).
  raw_body <- as.character(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"))
  return(connectcore::build_request(
    base_url = base_url,
    endpoint = path,
    method = "POST",
    body = raw_body,
    body_format = "raw",
    raw_content_type = "application/json",
    parse_envelope = parse_envelope,
    .perform = .perform,
    .parser = .parser,
    is_async = is_async,
    timeout = timeout,
    user_agent = "dereckscompany/hyperliquid"
  ))
}

#' Parse and Validate a Hyperliquid API Response
#'
#' Extracts the body from an [httr2::response] and detects Hyperliquid's two
#' failure shapes:
#' - `/info` with a malformed body returns **HTTP 422, `text/plain`** (not
#'   JSON); any `>= 400` status is surfaced verbatim.
#' - `/exchange` returns **HTTP 200 even on failure**, with
#'   `{status:"err", response:"<string>"}`; this is detected and aborted with
#'   the response string.
#'
#' On success the parsed JSON body is returned with `simplifyVector = FALSE` so
#' downstream parsers can flatten nested structures deterministically.
#'
#' This is Hyperliquid's error envelope, supplied to [hyperliquid_build_request()]
#' (and to `HyperliquidBase`'s `.parse_envelope` seam) in place of connectcore's
#' default JSON/non-2xx parser, because Hyperliquid signals failure on a 200.
#'
#' @param resp (class<httr2_response>) an [httr2::response] object.
#' @return (list | NULL) the parsed JSON response body; `NULL` when the body is
#'   a JSON `null` (e.g. the `subAccounts` endpoint with no sub-accounts).
#'
#' @importFrom httr2 resp_status resp_body_string
#' @importFrom jsonlite fromJSON
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
parse_hyperliquid_response <- function(resp) {
  assert_args_parse_hyperliquid_response(resp)
  status <- httr2::resp_status(resp)
  body_text <- tryCatch(
    httr2::resp_body_string(resp),
    error = function(e) ""
  )

  # /info malformed -> HTTP 422 text/plain. Surface the body verbatim.
  if (status >= 400L) {
    rlang::abort(paste0("Hyperliquid HTTP error ", status, "\n", body_text))
  }

  if (!nzchar(trimws(body_text))) {
    return(list())
  }

  parsed <- jsonlite::fromJSON(body_text, simplifyVector = FALSE)

  # /exchange failures return HTTP 200 with {status:"err", response:<string>}.
  if (is.list(parsed) && identical(parsed$status, "err")) {
    rlang::abort(paste0("Hyperliquid exchange error: ", parsed$response))
  }

  # Return is NOT wired: a JSON `null` body (e.g. `subAccounts` with no
  # sub-accounts) parses to NULL, which the generated assert_list contract
  # rejects. The corrected `(list | NULL)` @return regenerates accordingly.
  return(parsed)
}
