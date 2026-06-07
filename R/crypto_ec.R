# File: R/crypto_ec.R
# secp256k1 over gmp bigz: keys, Ethereum addresses, deterministic ECDSA
# (RFC 6979), and public-key recovery. Pure R on base + gmp + openssl.

# ---- curve constants ---------------------------------------------------------

secp256k1_p <- gmp::as.bigz("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F")
secp256k1_n <- gmp::as.bigz("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")
secp256k1_G <- list(
  x = gmp::as.bigz("0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"),
  y = gmp::as.bigz("0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8")
)

# ---- raw/bigz/hex helpers ----------------------------------------------------

#' Decode a Hex String to Raw Bytes
#' @param h Character; hex string, optional `0x` prefix, odd length tolerated.
#' @return A raw vector.
#' @keywords internal
#' @noRd
hex2raw <- function(h) {
  h <- sub("^0[xX]", "", h)
  if (nchar(h) %% 2 == 1) {
    h <- paste0("0", h)
  }
  starts <- seq(1, nchar(h) - 1, by = 2)
  return(as.raw(strtoi(substring(h, starts, starts + 1), 16L)))
}

#' Encode Raw Bytes as a Lowercase Hex String (no prefix)
#' @param r A raw vector.
#' @return Character; concatenated two-digit hex.
#' @keywords internal
#' @noRd
raw2hex <- function(r) {
  return(paste(as.character(r), collapse = ""))
}

#' Decode Raw Bytes (big-endian) to a `gmp::bigz`
#' @param r A raw vector.
#' @return A scalar `gmp::bigz`.
#' @importFrom gmp as.bigz
#' @keywords internal
#' @noRd
raw2bigz <- function(r) {
  return(gmp::as.bigz(paste0("0x", raw2hex(r))))
}

#' Encode a `gmp::bigz` as 32 Big-Endian Bytes (left zero-padded)
#' @param x A non-negative scalar `gmp::bigz`.
#' @return `raw(32)`.
#' @keywords internal
#' @noRd
bigz2raw32 <- function(x) {
  h <- as.character(x, b = 16)
  h <- gsub(" ", "0", sprintf("%064s", h))
  return(hex2raw(h))
}

# ---- affine point arithmetic mod p -------------------------------------------
# Points are list(x = bigz, y = bigz); NULL is the point at infinity.

#' Add Two secp256k1 Points (affine, mod p)
#' @param P,Q Points `list(x, y)` or `NULL` (point at infinity).
#' @return The sum point, or `NULL`.
#' @importFrom gmp mod.bigz inv.bigz
#' @keywords internal
#' @noRd
ec_add <- function(P, Q) {
  p <- secp256k1_p
  if (is.null(P)) {
    return(Q)
  }
  if (is.null(Q)) {
    return(P)
  }
  if (P$x == Q$x && gmp::mod.bigz(P$y + Q$y, p) == 0) {
    return(NULL) # P + (-P) = infinity
  }
  if (P$x == Q$x) {
    # point doubling: slope = (3x^2) / (2y)   (a = 0 for secp256k1)
    m <- gmp::mod.bigz((3 * P$x^2) * gmp::inv.bigz(2 * P$y, p), p)
  } else {
    m <- gmp::mod.bigz((Q$y - P$y) * gmp::inv.bigz(gmp::mod.bigz(Q$x - P$x, p), p), p)
  }
  x3 <- gmp::mod.bigz(m^2 - P$x - Q$x, p)
  y3 <- gmp::mod.bigz(m * (P$x - x3) - P$y, p)
  return(list(x = x3, y = y3))
}

#' Scalar-Multiply a secp256k1 Point (double-and-add, LSB first)
#' @param k A scalar (`gmp::bigz` or coercible).
#' @param P A point `list(x, y)`.
#' @return The point `k * P`, or `NULL`.
#' @importFrom gmp as.bigz mod.bigz divq.bigz
#' @keywords internal
#' @noRd
ec_mul <- function(k, P) {
  R <- NULL
  k <- gmp::as.bigz(k)
  while (k > 0) {
    if (gmp::mod.bigz(k, 2) == 1) {
      R <- ec_add(R, P)
    }
    P <- ec_add(P, P)
    k <- gmp::divq.bigz(k, 2)
  }
  return(R)
}

# ---- keys and addresses ------------------------------------------------------

#' Derive the Uncompressed SEC1 Public Key from a Private Key
#' @param priv32 `raw(32)`; the private scalar, big-endian.
#' @return `raw(65)`: `0x04 || X(32) || Y(32)`.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
pubkey_from_priv <- function(priv32) {
  d <- raw2bigz(priv32)
  if (d <= 0 || d >= secp256k1_n) {
    rlang::abort("private key out of range")
  }
  Q <- ec_mul(d, secp256k1_G)
  return(c(as.raw(0x04), bigz2raw32(Q$x), bigz2raw32(Q$y)))
}

#' Derive an Ethereum Address from an Uncompressed Public Key
#' @param pub65 `raw(65)`; `0x04 || X || Y`.
#' @return Character; lowercase `0x`-prefixed 20-byte address.
#' @keywords internal
#' @noRd
eth_address_from_pubkey <- function(pub65) {
  # keccak256 of the 64-byte X||Y, take last 20 bytes
  h <- keccak256(pub65[2:65])
  return(paste0("0x", tolower(raw2hex(h[13:32]))))
}

#' Derive an Ethereum Address from a Private Key
#' @param priv32 `raw(32)`; the private scalar, big-endian.
#' @return Character; lowercase `0x`-prefixed 20-byte address.
#' @keywords internal
#' @noRd
eth_address <- function(priv32) {
  return(eth_address_from_pubkey(pubkey_from_priv(priv32)))
}

# ---- RFC 6979 deterministic nonce (HMAC-SHA256 DRBG) -------------------------

#' HMAC-SHA256
#' @param key,data Raw vectors.
#' @return `raw(32)`.
#' @importFrom openssl sha256
#' @keywords internal
#' @noRd
hmac_sha256 <- function(key, data) {
  return(c(openssl::sha256(data, key = key)))
}

#' RFC 6979 Deterministic Nonce (HMAC-SHA256 DRBG)
#'
#' libsecp256k1 (and therefore eth_account / coincurve) seeds the DRBG with
#' `key32 || msg32` directly. Strict RFC 6979 uses
#' `bits2octets(h1) = int2octets(bits2int(h1) mod n)` instead of the raw digest;
#' the two differ only when `digest >= n` (probability ~2^-128).
#'
#' @param digest32 `raw(32)`; the message digest.
#' @param priv32 `raw(32)`; the private scalar, big-endian.
#' @param use_bits2octets Logical; use strict RFC 6979 reduction of the digest.
#' @return A scalar `gmp::bigz` nonce `k` in `(0, n)`.
#' @importFrom gmp mod.bigz
#' @keywords internal
#' @noRd
rfc6979_k <- function(digest32, priv32, use_bits2octets = FALSE) {
  n <- secp256k1_n
  z_oct <- digest32
  if (use_bits2octets) {
    z_oct <- bigz2raw32(gmp::mod.bigz(raw2bigz(digest32), n))
  }
  V <- as.raw(rep(0x01, 32))
  K <- as.raw(rep(0x00, 32))
  K <- hmac_sha256(K, c(V, as.raw(0x00), priv32, z_oct))
  V <- hmac_sha256(K, V)
  K <- hmac_sha256(K, c(V, as.raw(0x01), priv32, z_oct))
  V <- hmac_sha256(K, V)
  repeat {
    V <- hmac_sha256(K, V)
    k <- raw2bigz(V)
    if (k > 0 && k < n) {
      return(k)
    }
    # candidate rejected: reseed and retry (essentially never taken)
    K <- hmac_sha256(K, c(V, as.raw(0x00)))
    V <- hmac_sha256(K, V)
  }
}

# ---- deterministic ECDSA sign with Ethereum recovery id ----------------------

#' Deterministic ECDSA Signature (RFC 6979) with Ethereum Recovery Id
#'
#' Produces a low-s normalised signature (EIP-2) and the `v = 27 + recid`
#' recovery byte used by Ethereum.
#'
#' @param digest32 `raw(32)`; the message digest to sign.
#' @param priv32 `raw(32)`; the private scalar, big-endian.
#' @param use_bits2octets Logical; passed to `rfc6979_k()`.
#' @return `list(r = bigz, s = bigz, v = integer)`.
#' @importFrom gmp mod.bigz inv.bigz divq.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
ecdsa_sign_rfc6979 <- function(digest32, priv32, use_bits2octets = FALSE) {
  n <- secp256k1_n
  d <- raw2bigz(priv32)
  z <- raw2bigz(digest32)
  k <- rfc6979_k(digest32, priv32, use_bits2octets = use_bits2octets)
  R <- ec_mul(k, secp256k1_G)
  r <- gmp::mod.bigz(R$x, n)
  if (r == 0) {
    rlang::abort("ecdsa: r == 0 (astronomically unlikely; would need nonce retry)")
  }
  s <- gmp::mod.bigz(gmp::inv.bigz(k, n) * (z + r * d), n)
  if (s == 0) {
    rlang::abort("ecdsa: s == 0 (astronomically unlikely; would need nonce retry)")
  }
  # recovery id bit 0 = parity of R.y. (Bit 1 would flag R.x >= n, which has
  # probability ~2^-128 -- ignored here, as libsecp256k1 callers also do.)
  recid <- as.integer(gmp::mod.bigz(R$y, 2) == 1)
  # EIP-2 low-s normalisation: replacing s with n - s negates the implied nonce,
  # which mirrors R over the x-axis, so the parity bit flips too.
  if (s > gmp::divq.bigz(n, 2)) {
    s <- n - s
    recid <- 1L - recid
  }
  return(list(r = r, s = s, v = 27L + recid))
}

# ---- public-key recovery (ecrecover) -----------------------------------------

#' Recover the Signing Address from an ECDSA Signature
#'
#' Returns the recovered Ethereum address, or `NULL` if recovery fails.
#'
#' @param digest32 `raw(32)`; the signed message digest.
#' @param r,s Signature scalars (`gmp::bigz` or coercible).
#' @param v Integer; recovery byte (27 or 28).
#' @return Character address, or `NULL`.
#' @importFrom gmp as.bigz mod.bigz divq.bigz inv.bigz powm
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
ecrecover <- function(digest32, r, s, v) {
  p <- secp256k1_p
  n <- secp256k1_n
  G <- secp256k1_G
  r <- gmp::as.bigz(r)
  s <- gmp::as.bigz(s)
  recid <- as.integer(v) - 27L
  if (!recid %in% c(0L, 1L)) {
    rlang::abort("ecrecover: v must be 27 or 28")
  }
  x <- r # (the r >= n branch with x = r + n is ignored, prob ~2^-128)
  y2 <- gmp::mod.bigz(x^3 + 7, p)
  # sqrt mod p via exponentiation: p == 3 (mod 4)
  y <- gmp::powm(y2, gmp::divq.bigz(p + 1, 4), p)
  if (gmp::mod.bigz(y^2 - y2, p) != 0) {
    return(NULL) # x not on curve
  }
  if (as.integer(gmp::mod.bigz(y, 2)) != recid) {
    y <- gmp::mod.bigz(p - y, p)
  }
  Rp <- list(x = x, y = y)
  z <- raw2bigz(digest32)
  rinv <- gmp::inv.bigz(r, n)
  # Q = r^-1 * (s*R - z*G)
  sR <- ec_mul(gmp::mod.bigz(s, n), Rp)
  zG <- ec_mul(gmp::mod.bigz(z, n), G)
  neg_zG <- list(x = zG$x, y = gmp::mod.bigz(p - zG$y, p))
  Q <- ec_mul(rinv, ec_add(sR, neg_zG))
  if (is.null(Q)) {
    return(NULL)
  }
  pub65 <- c(as.raw(0x04), bigz2raw32(Q$x), bigz2raw32(Q$y))
  return(eth_address_from_pubkey(pub65))
}
