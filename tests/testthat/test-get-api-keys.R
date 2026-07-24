# get_api_keys(): the three credential modes -- full (key), read-only
# (address without key), and public (neither).

test_that("a private key yields signing credentials with a derived wallet address", {
  keys <- get_api_keys(
    private_key = paste0("0x", paste(rep("01", 32), collapse = "")),
    account_address = ""
  )
  expect_true(is.raw(keys$private_key))
  expect_null(keys$account_address)
  expect_match(keys$wallet_address, "^0x[0-9a-fA-F]{40}$")
})

test_that("read-only mode: an address WITHOUT a key is kept, not discarded", {
  address <- "0xdfc24b077bc1425ad1dea75bcb6f8158e10df303"
  expect_warning(
    keys <- get_api_keys(private_key = "", account_address = address),
    "READ-ONLY"
  )
  expect_null(keys$private_key)
  expect_identical(keys$account_address, address)
  expect_null(keys$wallet_address)
})

test_that("public mode: neither key nor address warns and yields all-NULL credentials", {
  expect_warning(
    keys <- get_api_keys(private_key = "", account_address = ""),
    "only public /info endpoints"
  )
  expect_null(keys$private_key)
  expect_null(keys$account_address)
  expect_null(keys$wallet_address)
})

test_that("read-only credentials resolve as the acting address on a client", {
  address <- "0xdfc24b077bc1425ad1dea75bcb6f8158e10df303"
  keys <- suppressWarnings(get_api_keys(private_key = "", account_address = address))
  client <- HyperliquidAccount$new(keys = keys, async = FALSE)
  # The acting address (account_address first, wallet second) must be the
  # read-only address -- this is what every account-state /info read defaults to.
  expect_identical(client$.__enclos_env__$private$.acting_address(), address)
})
