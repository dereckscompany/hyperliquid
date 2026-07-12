# Typed conditions for the request funnel (R/conditions.R + parse_hyperliquid_response).
# Internal (unexported) functions are reached via hyperliquid:::fn.

# ---- HTTP error surface (/info malformed -> non-2xx) -------------------------

test_that("parse_hyperliquid_response HTTP path raises a typed, status-keyed condition", {
  resp <- httr2::response(
    status_code = 422L,
    headers = list(`Content-Type` = "text/plain"),
    body = charToRaw("Failed to deserialize the JSON body.")
  )

  # per-status class keyed on the HTTP status
  status_hit <- tryCatch(
    hyperliquid:::parse_hyperliquid_response(resp),
    hyperliquid_api_error_422 = function(e) e
  )
  expect_s3_class(status_hit, "hyperliquid_api_error_422")
  expect_equal(status_hit$status, 422L)
  expect_match(status_hit$body_snippet, "deserialize")

  # package family and connectcore family both catch it
  expect_s3_class(
    tryCatch(hyperliquid:::parse_hyperliquid_response(resp), hyperliquid_api_error = function(e) e),
    "hyperliquid_api_error"
  )
  cc_fam <- tryCatch(hyperliquid:::parse_hyperliquid_response(resp), connectcore_api_error = function(e) e)
  expect_s3_class(cc_fam, "connectcore_api_error")
  expect_s3_class(cc_fam, "connectcore_error")

  # an HTTP error is NOT an exchange error
  expect_false(inherits(status_hit, "hyperliquid_exchange_error"))

  # message byte-identical to the legacy HTTP string
  err <- tryCatch(hyperliquid:::parse_hyperliquid_response(resp), error = function(e) e)
  expect_equal(conditionMessage(err), "Hyperliquid HTTP error 422\nFailed to deserialize the JSON body.")
})

# ---- Exchange error surface (/exchange -> HTTP 200 {status:"err"}) -----------

test_that("parse_hyperliquid_response exchange path raises a no-status hyperliquid_exchange_error", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"status":"err","response":"Order could not immediately match."}')
  )

  # caught specifically as the exchange-error subclass
  ex_hit <- tryCatch(
    hyperliquid:::parse_hyperliquid_response(resp),
    hyperliquid_exchange_error = function(e) e
  )
  expect_s3_class(ex_hit, "hyperliquid_exchange_error")
  expect_equal(ex_hit$response, "Order could not immediately match.")

  # documented no-status: no status field, no per-status class
  expect_null(ex_hit$status)
  expect_false(inherits(ex_hit, "hyperliquid_api_error_200"))
  expect_false(inherits(ex_hit, "connectcore_api_error_200"))

  # it nests under the shared families so a broader handler still catches it
  expect_s3_class(ex_hit, "hyperliquid_api_error")
  expect_s3_class(ex_hit, "connectcore_api_error")
  expect_s3_class(ex_hit, "connectcore_error")

  # message byte-identical to the legacy exchange string
  err <- tryCatch(hyperliquid:::parse_hyperliquid_response(resp), error = function(e) e)
  expect_equal(conditionMessage(err), "Hyperliquid exchange error: Order could not immediately match.")
})

test_that("parse_hyperliquid_response returns the parsed body on a success envelope", {
  resp <- httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw('{"status":"ok","response":{"type":"order"}}')
  )
  out <- hyperliquid:::parse_hyperliquid_response(resp)
  expect_equal(out$status, "ok")
})
