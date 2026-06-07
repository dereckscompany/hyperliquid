# File: R/sign.R
# Faithful R port of hyperliquid-python-sdk's signing.py: action hashing, L1
# (exchange) signing, user-signed actions, and order-wire construction.

# ---- float helpers -----------------------------------------------------------

#' Convert a Float to its Hyperliquid Wire String
#'
#' Mirrors the Python SDK: format with 8 decimals, error if that rounds the
#' value, then strip trailing zeros (Decimal normalize) without exponent
#' notation.
#'
#' @param x Numeric scalar; a price or size.
#' @return Character; the value as a normalised decimal string.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
float_to_wire <- function(x) {
  old <- options(OutDec = ".", scipen = 999)
  on.exit(options(old), add = TRUE)
  rounded <- sprintf("%.8f", x)
  if (abs(as.numeric(rounded) - x) >= 1e-12) {
    rlang::abort(paste0("float_to_wire causes rounding: ", x))
  }
  if (rounded == "-0") {
    rounded <- "0" # mirrors python's (unreachable) check on the %.8f string
  }
  # Decimal normalize == strip trailing zeros in the fraction, then any bare dot
  out <- rounded
  if (grepl("\\.", out)) {
    out <- sub("0+$", "", out)
    out <- sub("\\.$", "", out)
  }
  if (out == "-0") {
    out <- "0" # defensive: python would actually return "-0" here, but
    # -0.0 never occurs in practice; normalised for sanity
  }
  return(out)
}

#' Scale a Float to an Integer by a Power of Ten
#'
#' Python receives whole values as ints and multiplies by `10^power` in EXACT
#' integer arithmetic; only fractional values take the float path. This mirror
#' routes whole doubles through gmp (exact) and fractional doubles through double
#' arithmetic with the same rounding guard.
#'
#' @param x Numeric scalar.
#' @param power Integer; the power of ten to scale by.
#' @return A double when the result fits a double exactly, otherwise a
#'   `gmp::bigz`.
#' @importFrom gmp as.bigz
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
float_to_int <- function(x, power) {
  if (is.numeric(x) && x == trunc(x)) {
    z <- gmp::as.bigz(x) * gmp::as.bigz(10)^power
    if (abs(z) < gmp::as.bigz(2)^53) {
      return(as.numeric(z)) # exact as a double
    }
    return(z) # too big for a double -- keep exact bigz
  }
  with_decimals <- x * 10^power
  if (abs(round(with_decimals) - with_decimals) >= 1e-3) {
    rlang::abort(paste0("float_to_int causes rounding: ", x))
  }
  return(round(with_decimals)) # R round() is half-to-even, same as python
}

#' Scale a Float to an Integer with 8 Decimals (hashing)
#' @param x Numeric scalar.
#' @return A double or `gmp::bigz`.
#' @keywords internal
#' @noRd
float_to_int_for_hashing <- function(x) {
  return(float_to_int(x, 8))
}

#' Scale a Float to a USD Integer (6 Decimals)
#' @param x Numeric scalar.
#' @return A double or `gmp::bigz`.
#' @keywords internal
#' @noRd
float_to_usd_int <- function(x) {
  return(float_to_int(x, 6))
}

# ---- action hash (msgpack || nonce || vault || expires) ----------------------

#' Encode a Whole Double as 8 Big-Endian Bytes
#' @param x Integer-valued numeric in `[0, 2^53)`.
#' @return `raw(8)`.
#' @keywords internal
#' @noRd
u64_be_raw <- function(x) {
  hi <- x %/% 4294967296
  lo <- x %% 4294967296
  return(c(mp_u32_be(hi), mp_u32_be(lo)))
}

#' Decode an Ethereum Address to Raw Bytes
#' @param address Character; `0x`-prefixed hex address.
#' @return A raw vector.
#' @keywords internal
#' @noRd
address_to_bytes <- function(address) {
  return(hex2raw(address))
}

#' Compute the Hyperliquid Action Hash
#'
#' `keccak(msgpack(action) || nonce(8 BE) || vault-flag[+addr] || [0x00 ||
#' expires(8 BE)])`.
#'
#' @param action The action value to encode via msgpack.
#' @param vault_address Character or `NULL`; the vault/sub-account address.
#' @param nonce Numeric; the action nonce (milliseconds).
#' @param expires_after Numeric or `NULL`; optional expiry timestamp.
#' @return `raw(32)`; the action hash.
#' @keywords internal
#' @noRd
action_hash <- function(action, vault_address, nonce, expires_after = NULL) {
  data <- encode_msgpack(action)
  data <- c(data, u64_be_raw(nonce))
  if (is.null(vault_address)) {
    data <- c(data, as.raw(0x00))
  } else {
    data <- c(data, as.raw(0x01), address_to_bytes(vault_address))
  }
  if (!is.null(expires_after)) {
    data <- c(data, as.raw(0x00), u64_be_raw(expires_after))
  }
  return(ethsign::keccak256(data))
}

# ---- L1 (exchange) action signing --------------------------------------------

#' Construct the Phantom Agent for L1 Signing
#' @param hash `raw(32)`; the action hash (the `connectionId`).
#' @param is_mainnet Logical; selects the `source` tag (`"a"`/`"b"`).
#' @return A named list `list(source, connectionId)`.
#' @keywords internal
#' @noRd
construct_phantom_agent <- function(hash, is_mainnet) {
  source <- "b"
  if (is_mainnet) {
    source <- "a"
  }
  return(list(source = source, connectionId = hash))
}

AGENT_FIELDS <- list(
  list(name = "source", type = "string"),
  list(name = "connectionId", type = "bytes32")
)

ZERO_ADDRESS <- "0x0000000000000000000000000000000000000000"

#' Compute the L1 (Exchange) Signing Digest
#'
#' Hashes the phantom agent under the fixed `Exchange` EIP-712 domain via
#' [ethsign::eip712_digest()]. The phantom agent's `connectionId` is the
#' `raw(32)` action hash, encoded as the `bytes32` field.
#'
#' @param action The action value.
#' @param vault_address Character or `NULL`.
#' @param nonce Numeric; the action nonce.
#' @param expires_after Numeric or `NULL`.
#' @param is_mainnet Logical.
#' @return `raw(32)`; the digest to sign.
#' @keywords internal
#' @noRd
l1_signing_digest <- function(action, vault_address, nonce, expires_after, is_mainnet) {
  hash <- action_hash(action, vault_address, nonce, expires_after)
  phantom_agent <- construct_phantom_agent(hash, is_mainnet)
  return(ethsign::eip712_digest(
    list(name = "Exchange", version = "1", chainId = 1337, verifyingContract = ZERO_ADDRESS),
    "Agent",
    AGENT_FIELDS,
    phantom_agent
  ))
}

#' Sign an L1 (Exchange) Action
#' @param signer An [ethsign::EthSigner]; the wallet signer.
#' @inheritParams l1_signing_digest
#' @return `list(r, s, v)` in Hyperliquid's wire shape (from
#'   [ethsign::as_rsv()]).
#' @keywords internal
#' @noRd
sign_l1_action <- function(signer, action, vault_address, nonce, expires_after, is_mainnet) {
  digest <- l1_signing_digest(action, vault_address, nonce, expires_after, is_mainnet)
  return(ethsign::as_rsv(signer$sign_digest(digest)))
}

# ---- user-signed actions (HyperliquidSignTransaction domain) -----------------

USD_SEND_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "time", type = "uint64")
)

WITHDRAW_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "time", type = "uint64")
)

USD_CLASS_TRANSFER_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "toPerp", type = "bool"),
  list(name = "nonce", type = "uint64")
)

SPOT_TRANSFER_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "token", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "time", type = "uint64")
)

SEND_ASSET_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "destination", type = "string"),
  list(name = "sourceDex", type = "string"),
  list(name = "destinationDex", type = "string"),
  list(name = "token", type = "string"),
  list(name = "amount", type = "string"),
  list(name = "fromSubAccount", type = "string"),
  list(name = "nonce", type = "uint64")
)

APPROVE_AGENT_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "agentAddress", type = "address"),
  list(name = "agentName", type = "string"),
  list(name = "nonce", type = "uint64")
)

APPROVE_BUILDER_FEE_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "maxFeeRate", type = "string"),
  list(name = "builder", type = "address"),
  list(name = "nonce", type = "uint64")
)

TOKEN_DELEGATE_SIGN_TYPES <- list(
  list(name = "hyperliquidChain", type = "string"),
  list(name = "validator", type = "address"),
  list(name = "wei", type = "uint64"),
  list(name = "isUndelegate", type = "bool"),
  list(name = "nonce", type = "uint64")
)

#' Sign a User-Signed Action
#'
#' Mutates the action as signing.py does: a fixed `signatureChainId` and an
#' environment-dependent `hyperliquidChain` tag, then signs over the
#' HyperliquidSignTransaction EIP-712 domain via [ethsign::eip712_digest()].
#' Extra action keys (e.g. `type`) are ignored by the digest.
#'
#' @param signer An [ethsign::EthSigner]; the wallet signer.
#' @param action Named list; the action message.
#' @param sign_types Unnamed list of `list(name, type)`.
#' @param primary_type Character; the EIP-712 primary type.
#' @param is_mainnet Logical.
#' @return `list(r, s, v)` in Hyperliquid's wire shape (from
#'   [ethsign::as_rsv()]).
#' @importFrom gmp as.bigz
#' @keywords internal
#' @noRd
sign_user_signed_action <- function(signer, action, sign_types, primary_type, is_mainnet) {
  action$signatureChainId <- "0x66eee"
  action$hyperliquidChain <- "Testnet"
  if (is_mainnet) {
    action$hyperliquidChain <- "Mainnet"
  }
  chain_id <- gmp::as.bigz(strtoi("66eee", 16L))
  digest <- ethsign::eip712_digest(
    list(
      name = "HyperliquidSignTransaction",
      version = "1",
      chainId = chain_id,
      verifyingContract = ZERO_ADDRESS
    ),
    primary_type,
    sign_types,
    action
  )
  return(ethsign::as_rsv(signer$sign_digest(digest)))
}

# ---- order wire construction -------------------------------------------------

#' Convert an Order Type to its Wire Representation
#'
#' Key insertion order matters for msgpack: for triggers it is `isMarket`,
#' `triggerPx`, `tpsl`.
#'
#' @param order_type Named list with a `limit` or `trigger` element.
#' @return A named list in wire shape.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
order_type_to_wire <- function(order_type) {
  if ("limit" %in% names(order_type)) {
    return(list(limit = order_type$limit))
  }
  if ("trigger" %in% names(order_type)) {
    return(list(
      trigger = list(
        isMarket = order_type$trigger$isMarket,
        triggerPx = float_to_wire(order_type$trigger$triggerPx),
        tpsl = order_type$trigger$tpsl
      )
    ))
  }
  rlang::abort("Invalid order type")
}

#' Convert an Order Request to its Wire Representation
#'
#' Emits the exact key order Hyperliquid expects: `a`, `b`, `p`, `s`, `r`, `t`,
#' and optionally `c` (cloid).
#'
#' @param order Named list; an order request (`is_buy`, `limit_px`, `sz`,
#'   `reduce_only`, `order_type`, optional `cloid`).
#' @param asset Integer; the asset id.
#' @return A named list in order-wire shape.
#' @keywords internal
#' @noRd
order_request_to_order_wire <- function(order, asset) {
  wire <- list(
    a = asset,
    b = order$is_buy,
    p = float_to_wire(order$limit_px),
    s = float_to_wire(order$sz),
    r = order$reduce_only,
    t = order_type_to_wire(order$order_type)
  )
  if (!is.null(order$cloid)) {
    wire$c <- order$cloid # cloid is already its raw "0x..." 16-byte hex string
  }
  return(wire)
}

#' Assemble Order Wires into an Order Action
#'
#' Emits the exact key order: `type`, `orders`, `grouping`, and optionally
#' `builder`.
#'
#' @param order_wires Unnamed list of order wires.
#' @param builder Named list or `NULL`; optional builder fee spec.
#' @param grouping Character; order grouping (default `"na"`).
#' @return A named list in order-action shape.
#' @keywords internal
#' @noRd
order_wires_to_order_action <- function(order_wires, builder = NULL, grouping = "na") {
  action <- list(
    type = "order",
    orders = order_wires,
    grouping = grouping
  )
  if (!is.null(builder)) {
    action$builder <- builder
  }
  return(action)
}
