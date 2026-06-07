# Offline tests for HyperliquidTransfers: the shared ack parser, and end-to-end
# signed writes asserting the posted action type + {r,s,v} signature (sign.R is
# already vector-tested, so structural correctness is enough here).

source(testthat::test_path("fixtures-transfers.R"))

# ---- shared helpers ----------------------------------------------------------

# A throwaway signing key (the python SDK test scalar) and its derived address.
priv_hex <- "0123456789012345678901234567890123456789012345678901234567890123"
priv_raw <- hyperliquid:::hex2raw(priv_hex)
throwaway_keys <- list(
  private_key = priv_raw,
  account_address = NULL,
  wallet_address = ethsign::eth_address(priv_raw)
)

mk_resp <- function(data) {
  return(httr2::response(
    status_code = 200L,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")))
  ))
}

# Run `call_fn()` against a mock that records the posted /exchange body and
# returns `fixture`. Returns the captured request body and the parsed table.
post_capture <- function(call_fn, fixture) {
  posted <- NULL
  httr2::local_mocked_responses(function(req) {
    raw_body <- req$body$data
    body_txt <- if (is.raw(raw_body)) rawToChar(raw_body) else as.character(raw_body)
    posted <<- jsonlite::fromJSON(body_txt, simplifyVector = FALSE)
    return(mk_resp(fixture))
  })
  dt <- call_fn()
  return(list(posted = posted, dt = dt))
}

new_client <- function(vault_address = NULL) {
  return(hyperliquid:::HyperliquidTransfers$new(
    keys = throwaway_keys,
    vault_address = vault_address
  ))
}

expect_has_signature <- function(posted) {
  expect_true(all(c("r", "s", "v") %in% names(posted$signature)))
  expect_true(nzchar(posted$signature$r))
  expect_true(nzchar(posted$signature$s))
  return(expect_true(is.numeric(posted$signature$v)))
}

# ---- parser ------------------------------------------------------------------

test_that("parse_transfer_ack flattens the ack to one row with no list columns", {
  dt <- hyperliquid:::parse_transfer_ack(fixture_transfer_ack_body())
  expect_equal(nrow(dt), 1L)
  expect_equal(names(dt), c("status", "response_type"))
  expect_equal(dt$status, "ok")
  expect_equal(dt$response_type, "default")
  expect_type(dt$status, "character")
  expect_type(dt$response_type, "character")
  expect_false(any(vapply(dt, is.list, logical(1))))
})

test_that("parse_transfer_ack returns a zero-row table on empty input", {
  expect_equal(nrow(hyperliquid:::parse_transfer_ack(list())), 0L)
  expect_equal(nrow(hyperliquid:::parse_transfer_ack(NULL)), 0L)
})

# ---- user-signed transfers ---------------------------------------------------

test_that("usd_class_transfer posts usdClassTransfer with subaccount amount and a signature", {
  client <- new_client(vault_address = "0x1234567890123456789012345678901234567890")
  res <- post_capture(
    function() client$usd_class_transfer(100, to_perp = TRUE),
    fixture_usd_class_transfer()
  )
  expect_equal(res$posted$action$type, "usdClassTransfer")
  expect_equal(
    res$posted$action$amount,
    "100 subaccount:0x1234567890123456789012345678901234567890"
  )
  expect_true(res$posted$action$toPerp)
  expect_equal(res$posted$action$nonce, res$posted$nonce)
  expect_equal(res$posted$action$signatureChainId, "0x66eee")
  expect_equal(res$posted$action$hyperliquidChain, "Mainnet")
  expect_has_signature(res$posted)
  expect_equal(res$dt$status, "ok")
  expect_equal(res$dt$response_type, "default")
})

test_that("usd_class_transfer without a vault posts a bare numeric amount", {
  client <- new_client()
  res <- post_capture(
    function() client$usd_class_transfer(50, to_perp = FALSE),
    fixture_usd_class_transfer()
  )
  expect_equal(res$posted$action$amount, "50")
  expect_false(res$posted$action$toPerp)
})

test_that("usd_send posts usdSend with destination, amount, time, and a signature", {
  client <- new_client()
  res <- post_capture(
    function() client$usd_send(25, "0x5e9ee1089755c3435139848e47e6635505d5a13a"),
    fixture_usd_send()
  )
  expect_equal(res$posted$action$type, "usdSend")
  expect_equal(res$posted$action$destination, "0x5e9ee1089755c3435139848e47e6635505d5a13a")
  expect_equal(res$posted$action$amount, "25")
  expect_equal(res$posted$action$time, res$posted$nonce)
  expect_has_signature(res$posted)
  expect_equal(res$dt$status, "ok")
})

test_that("spot_send posts spotSend carrying the token", {
  client <- new_client()
  res <- post_capture(
    function() {
      return(client$spot_send(
        1.5,
        "0x5e9ee1089755c3435139848e47e6635505d5a13a",
        "PURR:0xc1fb593aeffbeb02f85e0308e9956a90"
      ))
    },
    fixture_spot_send()
  )
  expect_equal(res$posted$action$type, "spotSend")
  expect_equal(res$posted$action$token, "PURR:0xc1fb593aeffbeb02f85e0308e9956a90")
  expect_equal(res$posted$action$amount, "1.5")
  expect_has_signature(res$posted)
})

test_that("withdraw posts withdraw3", {
  client <- new_client()
  res <- post_capture(
    function() client$withdraw(10, "0x5e9ee1089755c3435139848e47e6635505d5a13a"),
    fixture_withdraw()
  )
  expect_equal(res$posted$action$type, "withdraw3")
  expect_equal(res$posted$action$destination, "0x5e9ee1089755c3435139848e47e6635505d5a13a")
  expect_equal(res$posted$action$amount, "10")
  expect_has_signature(res$posted)
})

test_that("send_asset posts sendAsset with dex routing and an empty fromSubAccount", {
  client <- new_client()
  res <- post_capture(
    function() {
      return(client$send_asset(
        "0x5e9ee1089755c3435139848e47e6635505d5a13a",
        "",
        "spot",
        "USDC:0xeb62eee3685fc4c43992febcd9e75443",
        42
      ))
    },
    fixture_send_asset()
  )
  expect_equal(res$posted$action$type, "sendAsset")
  expect_equal(res$posted$action$sourceDex, "")
  expect_equal(res$posted$action$destinationDex, "spot")
  expect_equal(res$posted$action$token, "USDC:0xeb62eee3685fc4c43992febcd9e75443")
  expect_equal(res$posted$action$amount, "42")
  expect_equal(res$posted$action$fromSubAccount, "")
  expect_equal(res$posted$action$nonce, res$posted$nonce)
  expect_has_signature(res$posted)
})

# ---- L1 transfers ------------------------------------------------------------

test_that("sub_account_transfer posts subAccountTransfer with a micro-USD integer", {
  client <- new_client()
  res <- post_capture(
    function() {
      return(client$sub_account_transfer(
        "0x5e9ee1089755c3435139848e47e6635505d5a13a",
        is_deposit = TRUE,
        usd = 10
      ))
    },
    fixture_sub_account_transfer()
  )
  expect_equal(res$posted$action$type, "subAccountTransfer")
  expect_equal(res$posted$action$subAccountUser, "0x5e9ee1089755c3435139848e47e6635505d5a13a")
  expect_true(res$posted$action$isDeposit)
  expect_equal(res$posted$action$usd, 10000000)
  # L1 actions are not user-signed: no EIP-712 chain tag is appended.
  expect_null(res$posted$action$signatureChainId)
  expect_has_signature(res$posted)
})

test_that("sub_account_spot_transfer posts subAccountSpotTransfer with a string amount", {
  client <- new_client()
  res <- post_capture(
    function() {
      return(client$sub_account_spot_transfer(
        "0x5e9ee1089755c3435139848e47e6635505d5a13a",
        is_deposit = FALSE,
        token = "PURR:0xc1fb593aeffbeb02f85e0308e9956a90",
        amount = 5
      ))
    },
    fixture_sub_account_spot_transfer()
  )
  expect_equal(res$posted$action$type, "subAccountSpotTransfer")
  expect_false(res$posted$action$isDeposit)
  expect_equal(res$posted$action$token, "PURR:0xc1fb593aeffbeb02f85e0308e9956a90")
  expect_equal(res$posted$action$amount, "5")
  expect_has_signature(res$posted)
})

test_that("vault_transfer posts vaultTransfer with a micro-USD integer", {
  client <- new_client()
  res <- post_capture(
    function() {
      return(client$vault_transfer(
        "0xdfc24b077bc1425ad1dea75bcb6f8158e10df303",
        is_deposit = TRUE,
        usd = 250
      ))
    },
    fixture_vault_transfer()
  )
  expect_equal(res$posted$action$type, "vaultTransfer")
  expect_equal(res$posted$action$vaultAddress, "0xdfc24b077bc1425ad1dea75bcb6f8158e10df303")
  expect_true(res$posted$action$isDeposit)
  expect_equal(res$posted$action$usd, 250000000)
  expect_has_signature(res$posted)
})

# ---- validation --------------------------------------------------------------

test_that("transfers reject bad addresses and non-positive amounts", {
  client <- new_client()
  expect_error(client$usd_send(10, "not-an-address"))
  expect_error(client$usd_send(0, "0x5e9ee1089755c3435139848e47e6635505d5a13a"))
  expect_error(client$usd_send(-5, "0x5e9ee1089755c3435139848e47e6635505d5a13a"))
  expect_error(client$spot_send(1, "0x5e9ee1089755c3435139848e47e6635505d5a13a", ""))
})
