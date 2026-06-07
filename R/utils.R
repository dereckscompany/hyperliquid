# File: R/utils.R
# General utility functions for the hyperliquid package: base URLs, wallet
# credentials, and client order id generation.

#' Retrieve the Hyperliquid REST Base URL
#'
#' Returns the REST base URL for the selected network. Hyperliquid exposes the
#' entire API behind one host (two paths, `/info` and `/exchange`); only the
#' network differs, and it must be chosen by an explicit flag because the
#' network changes the *signature itself* (phantom-agent source and
#' `hyperliquidChain` tag), so URL sniffing is never safe.
#'
#' @param testnet (scalar<logical>) if `TRUE` return the testnet host, otherwise
#'   the mainnet host. Default `FALSE`.
#' @return (scalar<character>) the REST base URL.
#'
#' @examples
#' get_base_url()
#' get_base_url(testnet = TRUE)
#'
#' @export
get_base_url <- function(testnet = FALSE) {
  assert_args_get_base_url(testnet)
  if (isTRUE(testnet)) {
    return(assert_return_get_base_url("https://api.hyperliquid-testnet.xyz"))
  }
  return(assert_return_get_base_url("https://api.hyperliquid.xyz"))
}

#' Generate a Client Order Id (cloid)
#'
#' Produces a 16-byte random client order id in Hyperliquid's wire form: a
#' `0x`-prefixed string of 32 lowercase hex characters. Bytes come from a CSPRNG
#' ([openssl::rand_bytes()]), not base R's seedable `sample()`.
#'
#' @return (scalar<character>) a cloid, e.g. `"0x1234...cdef"` (32 hex chars).
#'
#' @examples
#' new_cloid()
#'
#' @importFrom openssl rand_bytes
#' @export
new_cloid <- function() {
  hex <- sprintf("%02x", as.integer(openssl::rand_bytes(16L)))
  return(assert_return_new_cloid(paste0("0x", paste(hex, collapse = ""))))
}

#' Normalise a Hyperliquid Private Key to 32 Raw Bytes
#'
#' Accepts a `0x`-prefixed (or bare) 64-hex-character secp256k1 private key
#' string and returns it as a `raw(32)`.
#'
#' @param private_key (scalar<character>) a 64-hex-character key, optional `0x`
#'   prefix.
#' @return (vector<raw, 32>) the private scalar, big-endian.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
normalise_private_key <- function(private_key) {
  assert_args_normalise_private_key(private_key)
  hex <- sub("^0[xX]", "", private_key)
  if (!grepl("^[0-9a-fA-F]{64}$", hex)) {
    rlang::abort(
      "`private_key` must be a 64-character hex string (optionally 0x-prefixed)."
    )
  }
  return(assert_return_normalise_private_key(hex2raw(hex)))
}

#' Retrieve Hyperliquid Wallet Credentials
#'
#' Reads the signing wallet's private key from the environment (or explicit
#' arguments) and derives the wallet address from it. Hyperliquid uses no API
#' keys: requests to `/exchange` are authenticated by an Ethereum wallet
#' signature in the body.
#'
#' Required environment variable: `HYPERLIQUID_PRIVATE_KEY` (a 64-hex-character
#' secp256k1 key). Optional `HYPERLIQUID_ACCOUNT_ADDRESS` names the master
#' account when the key is an **agent/API wallet** acting on its behalf.
#'
#' When no key is present this **warns** (it does not abort): public `/info`
#' market data works without credentials, so a key-less client is still useful.
#'
#' @param private_key (scalar<character>) the signing key. Defaults to
#'   `Sys.getenv("HYPERLIQUID_PRIVATE_KEY")`.
#' @param account_address (scalar<character>) the optional master account
#'   address for an agent wallet. Defaults to
#'   `Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")`.
#' @return (list) named list with:
#' - private_key (vector<raw, 32> | NULL) signing scalar, or `NULL` when absent.
#' - account_address (scalar<character> | NULL) master address, or `NULL`.
#' - wallet_address (scalar<character> | NULL) `0x`-prefixed address derived from
#'   the key, or `NULL` when absent.
#'
#' @examples
#' \dontrun{
#' keys <- get_api_keys()
#' }
#'
#' @importFrom rlang warn
#' @export
get_api_keys <- function(
  private_key = Sys.getenv("HYPERLIQUID_PRIVATE_KEY"),
  account_address = Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")
) {
  assert_args_get_api_keys(private_key, account_address)
  if (!nzchar(private_key)) {
    rlang::warn(paste0(
      "Hyperliquid private key is not set; only public /info endpoints will ",
      "work. Set HYPERLIQUID_PRIVATE_KEY (and optionally ",
      "HYPERLIQUID_ACCOUNT_ADDRESS) or pass them explicitly to sign /exchange ",
      "actions."
    ))
    return(assert_return_get_api_keys(list(
      private_key = NULL,
      account_address = NULL,
      wallet_address = NULL
    )))
  }

  priv_raw <- normalise_private_key(private_key)
  account <- NULL
  if (nzchar(account_address)) {
    account <- account_address
  }
  return(assert_return_get_api_keys(list(
    private_key = priv_raw,
    account_address = account,
    wallet_address = eth_address(priv_raw)
  )))
}
