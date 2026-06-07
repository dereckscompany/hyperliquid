# File: R/crypto_msgpack.R
# Minimal msgpack encoder, byte-compatible with msgpack-python's packb() for the
# value shapes Hyperliquid actions actually use.
#
# Supported R -> msgpack mapping:
#   named list   -> fixmap / map16          (INSERTION ORDER preserved, like a Python dict)
#   unnamed list -> fixarray / array16
#   character    -> fixstr / str8 / str16   (UTF-8)
#   logical      -> 0xc3 (true) / 0xc2 (false)
#   NULL         -> 0xc0
#   numeric whole / integer -> minimal-width int family, exactly like Python ints
#
# CRITICAL wire-format fact: every numeric inside a Hyperliquid action is an
# integer (Python int). Prices/sizes are pre-converted to STRINGS by
# float_to_wire before they ever reach msgpack. So a non-whole double here is a
# bug upstream -> hard error, never float64.
#
# uint64 byte extraction uses split arithmetic (x %/% 2^32, x %% 2^32) which is
# exact for whole doubles below 2^53 -- covers all real Hyperliquid values
# (nonces ~1.7e12, oids ~1e11, px*1e8 <= ~1e13).

# ---- byte helpers ------------------------------------------------------------

#' Encode an Unsigned Byte
#' @param v Integer-valued numeric in `[0, 255]`.
#' @return `raw(1)`.
#' @keywords internal
#' @noRd
mp_u8 <- function(v) {
  return(as.raw(v))
}

#' Encode a Big-Endian 16-bit Unsigned Integer
#' @param v Integer-valued numeric in `[0, 65535]`.
#' @return `raw(2)`.
#' @keywords internal
#' @noRd
mp_u16_be <- function(v) {
  return(as.raw(c(v %/% 256, v %% 256)))
}

#' Encode a Big-Endian 32-bit Unsigned Integer
#' @param v Integer-valued numeric in `[0, 2^32 - 1]`.
#' @return `raw(4)`.
#' @keywords internal
#' @noRd
mp_u32_be <- function(v) {
  return(as.raw(c(
    (v %/% 16777216) %% 256,
    (v %/% 65536) %% 256,
    (v %/% 256) %% 256,
    v %% 256
  )))
}

#' Encode a Big-Endian 64-bit Unsigned Integer
#'
#' Splits into two exact 32-bit halves using double arithmetic, which is exact
#' for whole doubles below 2^53.
#'
#' @param v Integer-valued numeric in `[0, 2^53)`.
#' @return `raw(8)`.
#' @keywords internal
#' @noRd
mp_u64_be <- function(v) {
  hi <- v %/% 4294967296
  lo <- v %% 4294967296
  return(c(mp_u32_be(hi), mp_u32_be(lo)))
}

# ---- scalar encoders ---------------------------------------------------------

#' Encode a Whole Number as a Minimal-Width msgpack Integer
#'
#' Mirrors msgpack-python's minimal-width choice for Python ints. Values whose
#' magnitude reaches 2^53 cannot be represented exactly by a double and abort
#' (the bigz path in `mp_encode_bigz()` handles those instead).
#'
#' @param x A whole double (or integer).
#' @return A raw vector holding the msgpack integer encoding.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
mp_encode_int <- function(x) {
  x <- as.numeric(x)
  if (x >= 0) {
    if (x < 128) {
      return(as.raw(x)) # positive fixint
    }
    if (x < 256) {
      return(c(as.raw(0xcc), mp_u8(x))) # uint8
    }
    if (x < 65536) {
      return(c(as.raw(0xcd), mp_u16_be(x))) # uint16
    }
    if (x < 4294967296) {
      return(c(as.raw(0xce), mp_u32_be(x))) # uint32
    }
    if (x >= 2^53) {
      rlang::abort(paste0("msgpack: integer ", x, " >= 2^53, double cannot represent it exactly"))
    }
    return(c(as.raw(0xcf), mp_u64_be(x))) # uint64
  }
  # negative
  if (x >= -32) {
    return(as.raw(256 + x)) # negative fixint 0xe0..0xff
  }
  if (x >= -128) {
    return(c(as.raw(0xd0), as.raw(256 + x))) # int8 (two's complement)
  }
  if (x >= -32768) {
    return(c(as.raw(0xd1), mp_u16_be(x + 65536))) # int16
  }
  if (x >= -2147483648) {
    return(c(as.raw(0xd2), mp_u32_be(x + 4294967296))) # int32
  }
  if (x <= -(2^53)) {
    rlang::abort(paste0("msgpack: integer ", x, " <= -2^53, double cannot represent it exactly"))
  }
  # BUGFIX: the original int64 negative path emitted mp_u64_be(x + 2^64), but
  # 18446744073709551616 (2^64) is not exactly representable as a double, so for
  # x in (-2^53, -2^31) the sum lost precision and produced wrong bytes. Split
  # into exact two's-complement 32-bit halves instead -- every intermediate stays
  # below 2^53 and is therefore exact:
  #   hi = floor(x / 2^32) + 2^32 ,  lo = x mod 2^32
  hi <- (x %/% 4294967296) + 4294967296
  lo <- x %% 4294967296
  return(c(as.raw(0xd3), mp_u32_be(hi), mp_u32_be(lo))) # int64
}

#' Encode a Character Scalar as a msgpack String
#' @param x A character scalar (encoded as UTF-8).
#' @return A raw vector holding the msgpack string encoding.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
mp_encode_str <- function(x) {
  b <- charToRaw(enc2utf8(x))
  n <- length(b)
  if (n <= 31) {
    return(c(as.raw(bitwOr(0xa0L, n)), b)) # fixstr
  }
  if (n <= 255) {
    return(c(as.raw(0xd9), mp_u8(n), b)) # str8
  }
  if (n <= 65535) {
    return(c(as.raw(0xda), mp_u16_be(n), b)) # str16
  }
  rlang::abort("msgpack: string longer than 65535 bytes not supported in spike")
}

#' Encode an Exact Integer (`gmp::bigz`) as a msgpack Integer
#'
#' Exact-integer path for values whose magnitude reaches 2^53 (beyond what a
#' double represents exactly). Values that fit a double are routed back through
#' `mp_encode_int()`.
#'
#' @param x A scalar `gmp::bigz`.
#' @return A raw vector holding the msgpack integer encoding.
#'
#' @importFrom gmp as.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
mp_encode_bigz <- function(x) {
  if (abs(x) < gmp::as.bigz(2)^53) {
    return(mp_encode_int(as.numeric(x))) # fits a double exactly -> reuse
  }
  if (x >= 0) {
    if (x >= gmp::as.bigz(2)^64) {
      rlang::abort("msgpack: integer exceeds uint64")
    }
    h <- as.character(x, b = 16)
    h <- gsub(" ", "0", sprintf("%016s", h))
    starts <- seq(1, 15, by = 2)
    return(c(as.raw(0xcf), as.raw(strtoi(substring(h, starts, starts + 1), 16L))))
  }
  if (x < -(gmp::as.bigz(2)^63)) {
    rlang::abort("msgpack: integer below int64 minimum")
  }
  return(c(as.raw(0xd3), mp_encode_bigz(x + gmp::as.bigz(2)^64)[-1])) # two's complement
}

# ---- recursive encoder -------------------------------------------------------

#' Recursively Encode an R Value as msgpack Bytes
#'
#' Maps named lists to maps (insertion order preserved), unnamed lists to
#' arrays, and scalars to their msgpack counterparts. Non-whole numerics abort
#' because every numeric in a Hyperliquid action must already be an integer
#' (prices and sizes arrive as strings from `float_to_wire()`).
#'
#' @param x A nestable R value: `NULL`, scalar, named/unnamed list, or `bigz`.
#' @return A raw vector holding the msgpack encoding.
#'
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
encode_msgpack <- function(x) {
  if (is.null(x)) {
    return(as.raw(0xc0)) # nil
  }
  if (inherits(x, "bigz")) {
    if (length(x) != 1) {
      rlang::abort("msgpack: only scalar bigz supported")
    }
    return(mp_encode_bigz(x))
  }
  if (is.list(x)) {
    nm <- names(x)
    n <- length(x)
    is_map <- !is.null(nm) && all(nzchar(nm))
    if (!is.null(nm) && !is_map && any(nzchar(nm))) {
      rlang::abort("msgpack: list with mixed named/unnamed elements")
    }
    if (is_map) {
      # map header
      if (n <= 15) {
        head <- as.raw(bitwOr(0x80L, n)) # fixmap
      } else if (n <= 65535) {
        head <- c(as.raw(0xde), mp_u16_be(n)) # map16
      } else {
        rlang::abort("msgpack: map too large for spike")
      }
      body <- raw(0)
      for (i in seq_len(n)) {
        # keys are encoded in insertion order (Python dict semantics)
        body <- c(body, mp_encode_str(nm[i]), encode_msgpack(x[[i]]))
      }
      return(c(head, body))
    }
    # array header
    if (n <= 15) {
      head <- as.raw(bitwOr(0x90L, n)) # fixarray
    } else if (n <= 65535) {
      head <- c(as.raw(0xdc), mp_u16_be(n)) # array16
    } else {
      rlang::abort("msgpack: array too large for spike")
    }
    body <- raw(0)
    for (i in seq_len(n)) {
      body <- c(body, encode_msgpack(x[[i]]))
    }
    return(c(head, body))
  }
  if (length(x) != 1) {
    rlang::abort(paste0("msgpack: only scalar atomic values supported (got length ", length(x), ")"))
  }
  if (is.character(x)) {
    return(mp_encode_str(x))
  }
  if (is.logical(x)) {
    if (is.na(x)) {
      rlang::abort("msgpack: NA logical not supported")
    }
    if (x) {
      return(as.raw(0xc3))
    }
    return(as.raw(0xc2))
  }
  if (is.numeric(x)) {
    if (is.na(x) || !is.finite(x)) {
      rlang::abort("msgpack: non-finite numeric")
    }
    if (x != trunc(x)) {
      # In this wire format ALL numerics in actions are ints; prices and sizes
      # arrive as strings (float_to_wire). A fractional double here means a
      # caller bug -- abort instead of emitting float64.
      rlang::abort(paste0(
        "msgpack: non-whole numeric ", x, " -- Hyperliquid actions carry only ints; ",
        "convert floats with float_to_wire() first"
      ))
    }
    return(mp_encode_int(x))
  }
  rlang::abort(paste0("msgpack: unsupported type ", paste(class(x), collapse = "/")))
}
