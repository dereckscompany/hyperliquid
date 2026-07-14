# tests/testthat/test-HyperliquidBase.R
# Constructor max_tries and the idempotency-gated retry carve-out. Hyperliquid's
# whole API is POST, so retry is decided by the path: /info (a read) is
# idempotent and retries; /exchange (a write) is never auto-retried.

# A throwaway non-zero secp256k1 scalar so the signer builds during construction.
.keys <- get_api_keys(private_key = paste0("0x", paste(rep("01", 32), collapse = "")))

test_that("HyperliquidBase rejects max_tries outside [1, 10]", {
  expect_error(HyperliquidBase$new(keys = .keys, max_tries = 0L))
  expect_error(HyperliquidBase$new(keys = .keys, max_tries = 11L))
})

# `httr2::req_perform()` short-circuits its retry loop whenever the `httr2_mock`
# option is set, so `local_mock_api()` / `local_mocked_responses()` cannot
# exercise retry. We mock the per-attempt fetch (`httr2:::req_perform1`) instead,
# letting `req_perform()` re-drive it against the policy the constructor's
# `max_tries` and the path's idempotency threaded into
# `connectcore::build_request()`; `sys_sleep` is stubbed so backoff is instant.

test_that("an /exchange write is performed exactly once even with max_tries = 5 (no double-submit)", {
  base <- HyperliquidBase$new(keys = .keys, max_tries = 5L)
  n <- 0L
  testthat::local_mocked_bindings(
    sys_sleep = function(seconds, ...) invisible(),
    req_perform1 = function(req, req_prep, path, handle, resend_count) {
      n <<- n + 1L
      return(httr2::response(status_code = 500L, body = charToRaw("server error")))
    },
    .package = "httr2"
  )
  priv <- base$.__enclos_env__$private
  # signed = TRUE -> /exchange, marked non-idempotent: never auto-retried.
  expect_error(priv$.request(
    list(action = list(type = "cancel"), nonce = 1, signature = "sig"),
    signed = TRUE
  ))
  expect_identical(n, 1L) # a write is never silently resent
})

test_that("a transient 500 on an idempotent /info read is retried and then succeeds (max_tries = 3)", {
  base <- HyperliquidBase$new(keys = .keys, max_tries = 3L)
  n <- 0L
  testthat::local_mocked_bindings(
    sys_sleep = function(seconds, ...) invisible(),
    req_perform1 = function(req, req_prep, path, handle, resend_count) {
      n <<- n + 1L
      if (n == 1L) {
        return(httr2::response(status_code = 500L, body = charToRaw("server error")))
      }
      return(httr2::response(
        status_code = 200L,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"ok":true}')
      ))
    },
    .package = "httr2"
  )
  priv <- base$.__enclos_env__$private
  # signed = FALSE -> /info, marked idempotent: retried on a transient failure.
  out <- priv$.request(list(type = "meta"), signed = FALSE)
  expect_true(out$ok)
  expect_identical(n, 2L) # retried once on the 500, then succeeded
})
