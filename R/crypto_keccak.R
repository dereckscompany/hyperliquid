# File: R/crypto_keccak.R
# Keccak-256 (original, pre-FIPS-202 Keccak as used by Ethereum) via openssl.

#' Compute Keccak-256 of Raw Bytes or a UTF-8 String
#'
#' Ethereum uses the original Keccak (the pre-FIPS-202 padding scheme), NOT
#' SHA3-256. [openssl::keccak()] (openssl >= 2.3) implements original Keccak, so
#' it is the hashing primitive used throughout this package's signing path.
#'
#' @param x A raw vector, or a character scalar (encoded as UTF-8 before
#'   hashing).
#' @return A plain `raw(32)` digest (the `"hash"` class attribute is stripped).
#'
#' @importFrom openssl keccak
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
keccak256 <- function(x) {
  if (is.character(x)) {
    x <- charToRaw(enc2utf8(x))
  }
  if (!is.raw(x)) {
    rlang::abort("keccak256: input must be raw or character")
  }
  # c() strips the "hash" class attribute -> plain raw(32)
  return(c(openssl::keccak(x, size = 256)))
}

#' Verify openssl Provides Original Keccak-256
#'
#' Fails fast if [openssl::keccak()] is not the original Keccak primitive, by
#' checking the canonical empty-string Ethereum test vector. Invoked from
#' `.onLoad()` so a wrong hashing primitive aborts at package load rather than
#' silently producing bad signatures.
#'
#' @return Invisibly `TRUE`; aborts on mismatch.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
keccak256_self_test <- function() {
  got <- paste(as.character(keccak256(raw(0))), collapse = "")
  want <- "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  if (!identical(got, want)) {
    rlang::abort(paste0(
      "keccak256 self-test FAILED: openssl::keccak is not original Keccak-256 (got ",
      got,
      ")"
    ))
  }
  return(invisible(TRUE))
}
