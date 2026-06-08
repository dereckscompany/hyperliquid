# Retrieve Hyperliquid Wallet Credentials

Reads the signing wallet's private key from the environment (or explicit
arguments) and derives the wallet address from it. Hyperliquid uses no
API keys: requests to `/exchange` are authenticated by an Ethereum
wallet signature in the body.

## Usage

``` r
get_api_keys(
  private_key = Sys.getenv("HYPERLIQUID_PRIVATE_KEY"),
  account_address = Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")
)
```

## Arguments

- private_key:

  (scalar\<character\>) the signing key. Defaults to
  `Sys.getenv("HYPERLIQUID_PRIVATE_KEY")`.

- account_address:

  (scalar\<character\>) the optional master account address for an agent
  wallet. Defaults to `Sys.getenv("HYPERLIQUID_ACCOUNT_ADDRESS")`.

## Value

(list) named list with:

- private_key (vector\<raw, 32\> \| NULL) signing scalar, or `NULL` when
  absent.

- account_address (scalar\<character\> \| NULL) master address, or
  `NULL`.

- wallet_address (scalar\<character\> \| NULL) `0x`-prefixed address
  derived from the key, or `NULL` when absent.

## Details

Required environment variable: `HYPERLIQUID_PRIVATE_KEY` (a
64-hex-character secp256k1 key). Optional `HYPERLIQUID_ACCOUNT_ADDRESS`
names the master account when the key is an **agent/API wallet** acting
on its behalf.

When no key is present this **warns** (it does not abort): public
`/info` market data works without credentials, so a key-less client is
still useful.

## Examples

``` r
if (FALSE) { # \dontrun{
keys <- get_api_keys()
} # }
```
