# File: R/zzz.R
# Package load hook and data.table non-standard-evaluation symbol declarations.

# Suppress R CMD check NOTES for data.table non-standard evaluation symbols.
utils::globalVariables(c(
  ".",
  ".N",
  ".SD",
  ":="
))

#' Package Load Hook
#'
#' Runs the Keccak-256 self-test at load time so a system OpenSSL that lacks the
#' original (pre-FIPS-202) Keccak primitive fails fast rather than silently
#' producing invalid Ethereum signatures. Rare Linux OpenSSL builds strip
#' non-NIST primitives; this guard asserts [openssl::keccak()] returns the
#' canonical empty-string Ethereum vector and aborts otherwise.
#'
#' @param libname Character; the library directory (unused).
#' @param pkgname Character; the package name (unused).
#' @return Invisibly `NULL`; aborts on a Keccak mismatch.
#' @keywords internal
#' @noRd
.onLoad <- function(libname, pkgname) {
  keccak256_self_test()
  return(invisible(NULL))
}
