# Tests for the staking domain: the parsers against their captured fixtures, an
# end-to-end /info read through a mocked transport, and the user-signed
# tokenDelegate write (asserting action type + {r,s,v} signature structure).

source(testthat::test_path("fixtures-staking.R"))

# ---- test helpers ------------------------------------------------------------

# Build an httr2 response from a fixture list (mirrors the live JSON body).
hl_staking_response <- function(data, status = 200L) {
  body <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = status,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(body))
  ))
}

# Decode the JSON body of a built httr2 request back to an R list. req_body_raw
# stores the serialised body as either a raw vector or the json string itself.
hl_staking_req_body <- function(req) {
  data <- req$body$data
  if (is.raw(data)) {
    data <- rawToChar(data)
  }
  return(jsonlite::fromJSON(as.character(data), simplifyVector = FALSE))
}

no_list_cols <- function(dt) {
  return(!any(vapply(dt, is.list, logical(1))))
}

# A read-only client (no signing key, no env warning).
read_client <- function() {
  return(hyperliquid:::HyperliquidStaking$new(
    keys = list(private_key = NULL, account_address = NULL, wallet_address = NULL)
  ))
}

STAKER <- "0x5ac99df645f3414876c816caa18b2d234024b487"

# ---- parse_staking_summary ---------------------------------------------------

test_that("parse_staking_summary flattens the summary to one typed row", {
  dt <- hyperliquid:::parse_staking_summary(fixture_staking_summary())
  expect_s3_class(dt, "data.table")
  expect_equal(nrow(dt), 1L)
  expect_equal(
    names(dt),
    c("delegated", "undelegated", "total_pending_withdrawal", "n_pending_withdrawals")
  )
  expect_equal(dt$delegated, 70064.72854868)
  expect_equal(dt$undelegated, 0)
  expect_equal(dt$n_pending_withdrawals, 0L)
  expect_type(dt$delegated, "double")
  expect_type(dt$n_pending_withdrawals, "integer")
  expect_true(no_list_cols(dt))
})

test_that("parse_staking_summary returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_staking_summary(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_staking_summary(list())), 0L)
})

# ---- parse_staking_delegations -----------------------------------------------

test_that("parse_staking_delegations stacks delegations with a POSIXct lockup", {
  dt <- hyperliquid:::parse_staking_delegations(fixture_staking_delegations())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("validator", "amount", "locked_until_timestamp"))
  expect_equal(dt$validator, STAKER)
  expect_equal(dt$amount, 70064.72854868)
  expect_type(dt$amount, "double")
  expect_s3_class(dt$locked_until_timestamp, "POSIXct")
  expect_true(no_list_cols(dt))
})

test_that("parse_staking_delegations returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_staking_delegations(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_staking_delegations(list())), 0L)
})

# ---- parse_staking_rewards ---------------------------------------------------

test_that("parse_staking_rewards stacks reward accruals with a POSIXct time", {
  dt <- hyperliquid:::parse_staking_rewards(fixture_staking_rewards())
  expect_equal(nrow(dt), 4L)
  expect_equal(names(dt), c("time", "source", "total_amount"))
  expect_s3_class(dt$time, "POSIXct")
  expect_equal(dt$source, c("delegation", "commission", "delegation", "commission"))
  expect_equal(dt$total_amount[1], 4.18960439)
  expect_type(dt$total_amount, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_staking_rewards returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_staking_rewards(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_staking_rewards(list())), 0L)
})

# ---- parse_delegator_history -------------------------------------------------

test_that("parse_delegator_history lifts the delta key into a delta_type column", {
  dt <- hyperliquid:::parse_delegator_history(fixture_delegator_history())
  expect_equal(nrow(dt), 2L)
  # Leading meta + discriminator, then the union of variant fields.
  expect_equal(names(dt)[1:3], c("time", "hash", "delta_type"))
  expect_true(all(c("validator", "amount", "is_undelegate") %in% names(dt)))
  expect_s3_class(dt$time, "POSIXct")
  expect_equal(dt$delta_type, c("delegate", "cDeposit"))
  # delegate row carries validator + is_undelegate; cDeposit row does not.
  expect_equal(dt$validator[1], STAKER)
  expect_true(is.na(dt$validator[2]))
  expect_false(dt$is_undelegate[1])
  expect_true(is.na(dt$is_undelegate[2]))
  # amount is numeric for both variants.
  expect_equal(dt$amount, c(10000, 10000))
  expect_type(dt$amount, "double")
  expect_true(no_list_cols(dt))
})

test_that("parse_delegator_history returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_delegator_history(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_delegator_history(list())), 0L)
})

# ---- parse_token_delegate ----------------------------------------------------

test_that("parse_token_delegate flattens the exchange success envelope", {
  dt <- hyperliquid:::parse_token_delegate(fixture_token_delegate_response())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("status", "response_type"))
  expect_equal(dt$status, "ok")
  expect_equal(dt$response_type, "default")
  expect_true(no_list_cols(dt))
})

test_that("parse_token_delegate returns a zero-row data.table when empty", {
  expect_equal(nrow(hyperliquid:::parse_token_delegate(NULL)), 0L)
  expect_equal(nrow(hyperliquid:::parse_token_delegate(list())), 0L)
})

# ---- end-to-end read through a mocked transport ------------------------------

test_that("get_staking_summary posts delegatorSummary and parses the response", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_staking_req_body(req)
    seen$url <- req$url
    return(hl_staking_response(fixture_staking_summary()))
  })

  client <- read_client()
  dt <- client$get_staking_summary(STAKER)

  # Request carried the right /info discriminator and address.
  expect_match(seen$url, "/info", fixed = TRUE)
  expect_equal(seen$body$type, "delegatorSummary")
  expect_equal(seen$body$user, STAKER)
  # Parsed result.
  expect_equal(nrow(dt), 1L)
  expect_equal(dt$delegated, 70064.72854868)
  expect_true(no_list_cols(dt))
})

test_that("get_delegator_history posts delegatorHistory and stacks the ledger", {
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_staking_req_body(req)
    return(hl_staking_response(fixture_delegator_history()))
  })

  client <- read_client()
  dt <- client$get_delegator_history(STAKER)

  expect_equal(seen$body$type, "delegatorHistory")
  expect_equal(nrow(dt), 2L)
  expect_equal(dt$delta_type, c("delegate", "cDeposit"))
  expect_true(no_list_cols(dt))
})

# ---- user-signed write -------------------------------------------------------

test_that("token_delegate posts a signed tokenDelegate action", {
  keys <- get_api_keys(
    private_key = "0123456789012345678901234567890123456789012345678901234567890123"
  )
  seen <- new.env()
  httr2::local_mocked_responses(function(req) {
    seen$body <- hl_staking_req_body(req)
    return(hl_staking_response(fixture_token_delegate_response()))
  })

  client <- hyperliquid:::HyperliquidStaking$new(keys = keys)
  dt <- client$token_delegate(validator = STAKER, wei = 100, is_undelegate = FALSE)

  action <- seen$body$action
  expect_equal(action$type, "tokenDelegate")
  expect_equal(action$validator, STAKER)
  expect_equal(action$wei, 100)
  expect_false(action$isUndelegate)
  # The user-signed mutation tags are present on the posted action.
  expect_equal(action$hyperliquidChain, "Mainnet")
  expect_equal(action$signatureChainId, "0x66eee")
  # nonce mirrored into the outer body; signature is a structural {r, s, v}.
  expect_equal(seen$body$nonce, action$nonce)
  expect_true(all(c("r", "s", "v") %in% names(seen$body$signature)))
  expect_match(seen$body$signature$r, "^0x[0-9a-f]+$")
  expect_true(seen$body$signature$v %in% c(27, 28))
  # vaultAddress / expiresAfter are null for user-signed actions.
  expect_null(seen$body$vaultAddress)
  expect_null(seen$body$expiresAfter)
  # Parsed acknowledgement.
  expect_equal(dt$status, "ok")
  expect_equal(dt$response_type, "default")
  expect_true(no_list_cols(dt))
})

test_that("token_delegate validates its inputs", {
  keys <- get_api_keys(
    private_key = "0123456789012345678901234567890123456789012345678901234567890123"
  )
  client <- hyperliquid:::HyperliquidStaking$new(keys = keys)
  expect_error(client$token_delegate(validator = "not-an-address", wei = 100))
  expect_error(client$token_delegate(validator = STAKER, wei = 1.5))
  expect_error(client$token_delegate(validator = STAKER, wei = -5))
  expect_error(client$token_delegate(validator = STAKER, wei = 0))
})

test_that("staking reads validate the address", {
  client <- read_client()
  expect_error(client$get_staking_summary("nope"))
})
