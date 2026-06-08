# Retrieve the Hyperliquid REST Base URL

Returns the REST base URL for the selected network. Hyperliquid exposes
the entire API behind one host (two paths, `/info` and `/exchange`);
only the network differs, and it must be chosen by an explicit flag
because the network changes the *signature itself* (phantom-agent source
and `hyperliquidChain` tag), so URL sniffing is never safe.

## Usage

``` r
get_base_url(testnet = FALSE)
```

## Arguments

- testnet:

  (scalar\<logical\>) if `TRUE` return the testnet host, otherwise the
  mainnet host. Default `FALSE`.

## Value

(scalar\<character\>) the REST base URL.

## Examples

``` r
get_base_url()
#> [1] "https://api.hyperliquid.xyz"
get_base_url(testnet = TRUE)
#> [1] "https://api.hyperliquid-testnet.xyz"
```
