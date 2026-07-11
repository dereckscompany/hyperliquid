# Test Whether a Value Is a Valid cloid

Vectorised, non-aborting predicate: `TRUE` for each element that matches
Hyperliquid's client-order-id format (a `0x` prefix followed by exactly
32 hex characters, i.e. 16 bytes), matched case-insensitively. `NA` in
maps to `NA` out. Unlike the internal order-boundary validator this
never aborts, so it is safe to use as a filter or a boundary guard. For
the canonical (lowercased) form, and to derive a cloid from an arbitrary
tag, see
[`as_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/as_cloid.md).

## Usage

``` r
is_cloid(x)
```

## Arguments

- x:

  (character \| NA) the values to test.

## Value

(logical \| NA) one flag per element: `TRUE` when the element is a valid
cloid, `FALSE` otherwise, and `NA` where `x` is `NA`.

## Examples

``` r
is_cloid("0x1234567890abcdef1234567890abcdef")
#> [1] TRUE
is_cloid(c("0xNOTHEX", NA, new_cloid()))
#> [1] FALSE    NA  TRUE
```
