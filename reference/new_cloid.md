# Generate a Client Order Id (cloid)

Produces a 16-byte random client order id in Hyperliquid's wire form: a
`0x`-prefixed string of 32 lowercase hex characters. Bytes come from a
CSPRNG
([`openssl::rand_bytes()`](https://jeroen.r-universe.dev/openssl/reference/rand_bytes.html)),
not base R's seedable [`sample()`](https://rdrr.io/r/base/sample.html).

## Usage

``` r
new_cloid()
```

## Value

(scalar\<character\>) a cloid, e.g. `"0x1234...cdef"` (32 hex chars).

## Examples

``` r
new_cloid()
#> [1] "0xe95ecf4d8d247754df817c3c9129cd63"
```
