# File: R/cloid.R
# Client-order-id (cloid) helpers. Hyperliquid's cloid must be a fixed 16-byte
# (128-bit) `0x`-prefixed hex string, so a caller's free-form idempotency tag is
# not a valid cloid and the venue silently rejects it. `is_cloid()` tests the
# format without aborting, and `as_cloid()` maps any tag deterministically onto a
# valid cloid so the same logical id always yields the same cloid (idempotency is
# preserved). The format regex lives once in `CLOID_PATTERN` (R/constants.R),
# shared with the internal order-boundary `validate_cloid()`.

#' Test Whether a Value Is a Valid cloid
#'
#' Vectorised, non-aborting predicate: `TRUE` for each element that matches
#' Hyperliquid's client-order-id format (a `0x` prefix followed by exactly 32 hex
#' characters, i.e. 16 bytes), matched case-insensitively. `NA` in maps to `NA`
#' out. Unlike the internal order-boundary validator this never aborts, so it is
#' safe to use as a filter or a boundary guard. For the canonical (lowercased)
#' form, and to derive a cloid from an arbitrary tag, see [as_cloid()].
#'
#' @param x (character | NA) the values to test.
#' @return (logical | NA) one flag per element: `TRUE` when the element is a
#'   valid cloid, `FALSE` otherwise, and `NA` where `x` is `NA`.
#'
#' @examples
#' is_cloid("0x1234567890abcdef1234567890abcdef")
#' is_cloid(c("0xNOTHEX", NA, new_cloid()))
#'
#' @export
is_cloid <- function(x) {
  assert_args_is_cloid(x)
  matched <- grepl(CLOID_PATTERN, x)
  matched[is.na(x)] <- NA
  return(assert_return_is_cloid(matched))
}

#' Coerce Any Client Tag to a Canonical cloid
#'
#' Deterministically maps any character tag onto a venue-valid cloid, so a
#' free-form idempotency id can be used on Hyperliquid, which accepts only the
#' fixed `0x` + 32-hex (16-byte) form. Each element is mapped as follows:
#'
#' - a value that is already a valid cloid (any case) is returned lowercased and
#'   otherwise unchanged (the canonical form);
#' - any other tag becomes `"0x"` followed by the first 16 bytes of
#'   `openssl::sha256(charToRaw(x))` rendered as 32 lowercase hex characters;
#' - `NA` maps to `NA`.
#'
#' The mapping is deterministic: the same tag always yields the same cloid, which
#' is exactly what makes it usable as an idempotency key, and the 128-bit width
#' makes collisions negligible.
#'
#' The hash step is **one-way**: a tag that is not already a cloid cannot be
#' recovered from its cloid. Recover the original by **lookup** on your side
#' (match the venue-returned cloid against `as_cloid()` of your candidate ids, or
#' keep a local tag -> cloid map), never by decoding. There is deliberately no
#' `cloid_decode()`.
#'
#' @param x (character | NA) the client tags to coerce.
#' @return (character | NA) one canonical cloid per element, and `NA` where `x`
#'   is `NA`. Idempotent: `as_cloid(as_cloid(x))` equals `as_cloid(x)`.
#'
#' @examples
#' as_cloid("my-run-42:BTC:entry")
#' as_cloid("0xABCDEF7890ABCDEF1234567890ABCDEF")
#'
#' @export
as_cloid <- function(x) {
  assert_args_as_cloid(x)
  canonical <- tolower(x)
  to_hash <- !is.na(x) & !grepl(CLOID_PATTERN, x)
  canonical[to_hash] <- vapply(x[to_hash], cloid_from_tag, character(1L), USE.NAMES = FALSE)
  return(assert_return_as_cloid(canonical))
}

#' Map One Client Tag to a Canonical cloid
#'
#' Hashes a single tag to the venue form: `"0x"` plus the first 16 bytes of its
#' SHA-256 digest rendered as 32 lowercase hex characters. Deterministic and
#' one-way. Called only by [as_cloid()], which handles the `NA` and
#' already-a-cloid cases before it reaches here.
#'
#' @param tag Character; a single non-`NA` tag that is not already a cloid.
#' @return Character; the derived `0x`-prefixed 32-hex-character cloid.
#'
#' @importFrom openssl sha256
#' @keywords internal
#' @noRd
cloid_from_tag <- function(tag) {
  digest <- as.character(openssl::sha256(charToRaw(tag)))
  return(paste0("0x", substr(digest, 1L, 32L)))
}
