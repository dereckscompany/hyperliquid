# Coerce Any Client Tag to a Canonical cloid

Deterministically maps any character tag onto a venue-valid cloid, so a
free-form idempotency id can be used on Hyperliquid, which accepts only
the fixed `0x` + 32-hex (16-byte) form. Each element is mapped as
follows:

## Usage

``` r
as_cloid(x)
```

## Arguments

- x:

  (character \| NA) the client tags to coerce.

## Value

(character \| NA) one canonical cloid per element, and `NA` where `x` is
`NA`. Idempotent: `as_cloid(as_cloid(x))` equals `as_cloid(x)`.

## Details

- a value that is already a valid cloid (any case) is returned
  lowercased and otherwise unchanged (the canonical form);

- any other tag becomes `"0x"` followed by the first 16 bytes of
  `openssl::sha256(charToRaw(x))` rendered as 32 lowercase hex
  characters;

- `NA` maps to `NA`.

The mapping is deterministic: the same tag always yields the same cloid,
which is exactly what makes it usable as an idempotency key, and the
128-bit width makes collisions negligible.

The hash step is **one-way**: a tag that is not already a cloid cannot
be recovered from its cloid. Recover the original by **lookup** on your
side (match the venue-returned cloid against `as_cloid()` of your
candidate ids, or keep a local tag -\> cloid map), never by decoding.
There is deliberately no `cloid_decode()`.

## Examples

``` r
as_cloid("my-run-42:BTC:entry")
#> [1] "0x1aee9a1a26767d85d5dcb6d0514b5961"
as_cloid("0xABCDEF7890ABCDEF1234567890ABCDEF")
#> [1] "0xabcdef7890abcdef1234567890abcdef"
```
