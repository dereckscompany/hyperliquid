# Hyperliquid signing vectors, replayed against the package's internal signing
# functions. Expected constants are copied verbatim from the validated spike
# harness (_research_hyperliquid/spike/run_vectors.R), which reproduces the
# official python and rust SDK test vectors.
#
# Internal (unexported) functions are reached via hyperliquid:::fn.

# ---- helpers -----------------------------------------------------------------

norm_hex <- function(h) {
  h <- tolower(sub("^0x", "", tolower(as.character(h))))
  h <- sub("^0+", "", h)
  if (h == "") {
    h <- "0"
  }
  return(h)
}

expect_sig <- function(sig, exp_r, exp_s, exp_v) {
  expect_equal(norm_hex(sig$r), norm_hex(exp_r))
  expect_equal(norm_hex(sig$s), norm_hex(exp_s))
  expect_equal(sig$v, exp_v)
}

# ---- shared fixtures (constructed exactly as run_vectors.R does) --------------

py_priv <- hyperliquid:::hex2raw("0123456789012345678901234567890123456789012345678901234567890123")

dummy_action <- list(type = "dummy", num = hyperliquid:::float_to_int_for_hashing(1000)) # 1e11 > uint32

gtc_order_action <- hyperliquid:::order_wires_to_order_action(list(
  hyperliquid:::order_request_to_order_wire(
    list(
      coin = "ETH",
      is_buy = TRUE,
      sz = 100,
      limit_px = 100,
      reduce_only = FALSE,
      order_type = list(limit = list(tif = "Gtc")),
      cloid = NULL
    ),
    1
  )
))

# ---- msgpack ground truth ----------------------------------------------------

test_that("msgpack encodes the dummy action to the hand-derived bytes", {
  expect_equal(
    hyperliquid:::raw2hex(hyperliquid:::encode_msgpack(dummy_action)),
    "82a474797065a564756d6d79a36e756dcf000000174876e800"
  )
})

# ---- phantom agent connectionId ----------------------------------------------

test_that("phantom agent connectionId matches the python SDK end-to-end hash", {
  phantom_action <- hyperliquid:::order_wires_to_order_action(list(
    hyperliquid:::order_request_to_order_wire(
      list(
        coin = "ETH",
        is_buy = TRUE,
        sz = 0.0147,
        limit_px = 1670.1,
        reduce_only = FALSE,
        order_type = list(limit = list(tif = "Ioc")),
        cloid = NULL
      ),
      4
    )
  ))
  phantom_hash <- hyperliquid:::action_hash(phantom_action, NULL, 1677777606040, NULL)
  phantom_agent <- hyperliquid:::construct_phantom_agent(phantom_hash, TRUE)
  expect_equal(
    norm_hex(hyperliquid:::raw2hex(phantom_agent$connectionId)),
    norm_hex("0x0fcbeda5ae3c4950a548021552a4fea2226858c4453571bf3f24ba017eac2908")
  )
})

# ---- L1 dummy action ---------------------------------------------------------

test_that("L1 dummy action signs to the python mainnet vector", {
  expect_sig(
    hyperliquid:::sign_l1_action(py_priv, dummy_action, NULL, 0, NULL, TRUE),
    "0x53749d5b30552aeb2fca34b530185976545bb22d0b3ce6f62e31be961a59298",
    "0x755c40ba9bf05223521753995abb2f73ab3229be8ec921f350cb447e384d8ed8",
    27
  )
})

test_that("L1 dummy action signs to the python testnet vector", {
  expect_sig(
    hyperliquid:::sign_l1_action(py_priv, dummy_action, NULL, 0, NULL, FALSE),
    "0x542af61ef1f429707e3c76c5293c80d01f74ef853e34b76efffcb57e574f9510",
    "0x17b8b32f086e8cdede991f1e2c529f5dd5297cbe8128500e00cbaf766204a613",
    28
  )
})

# ---- L1 GTC order ------------------------------------------------------------

test_that("L1 GTC order signs to the python mainnet vector", {
  expect_sig(
    hyperliquid:::sign_l1_action(py_priv, gtc_order_action, NULL, 0, NULL, TRUE),
    "0xd65369825a9df5d80099e513cce430311d7d26ddf477f5b3a33d2806b100d78e",
    "0x2b54116ff64054968aa237c20ca9ff68000f977c93289157748a3162b6ea940e",
    28
  )
})

test_that("L1 GTC order signs to the python testnet vector", {
  expect_sig(
    hyperliquid:::sign_l1_action(py_priv, gtc_order_action, NULL, 0, NULL, FALSE),
    "0x82b2ba28e76b3d761093aaded1b1cdad4960b3af30212b343fb2e6cdfa4e3d54",
    "0x6b53878fc99d26047f4d7e8c90eb98955a109f44209163f52d8dc4278cbbd9f5",
    27
  )
})

# ---- user-signed usdSend / withdraw3 -----------------------------------------

test_that("usdSend signs to the python testnet vector", {
  usd_send_action <- list(
    destination = "0x5e9ee1089755c3435139848e47e6635505d5a13a",
    amount = "1",
    time = 1687816341423
  )
  expect_sig(
    hyperliquid:::sign_usd_transfer_action(py_priv, usd_send_action, FALSE),
    "0x637b37dd731507cdd24f46532ca8ba6eec616952c56218baeff04144e4a77073",
    "0x11a6a24900e6e314136d2592e2f8d502cd89b7c15b198e1bee043c9589f9fad7",
    27
  )
})

test_that("withdraw3 signs to the python testnet vector", {
  withdraw_action <- list(
    destination = "0x5e9ee1089755c3435139848e47e6635505d5a13a",
    amount = "1",
    time = 1687816341423
  )
  expect_sig(
    hyperliquid:::sign_withdraw_from_bridge_action(py_priv, withdraw_action, FALSE),
    "0x8363524c799e90ce9bc41022f7c39b4e9bdba786e5f9c72b20e43e1462c37cf9",
    "0x58b1411a775938b83e29182e8ef74975f9054c8e97ebf5ec2dc8d51bfc893881",
    28
  )
})

# ---- float_to_int_for_hashing ------------------------------------------------

test_that("float_to_int_for_hashing reproduces the spike vectors", {
  f2i <- function(x) as.character(gmp::as.bigz(hyperliquid:::float_to_int_for_hashing(x)))
  expect_equal(f2i(123123123123), "12312312312300000000")
  expect_equal(f2i(0.00001231), "1231")
  expect_equal(f2i(1.033), "103300000")
  expect_error(hyperliquid:::float_to_int_for_hashing(0.000012312312))
})

# ---- float_to_wire -----------------------------------------------------------

test_that("float_to_wire reproduces the spike vectors", {
  expect_equal(hyperliquid:::float_to_wire(0.0147), "0.0147")
  expect_equal(hyperliquid:::float_to_wire(1670.1), "1670.1")
  expect_equal(hyperliquid:::float_to_wire(100), "100")
  expect_equal(hyperliquid:::float_to_wire(103), "103")
  expect_equal(hyperliquid:::float_to_wire(1.033), "1.033")
  expect_equal(hyperliquid:::float_to_wire(0), "0")
  expect_error(hyperliquid:::float_to_wire(0.000000001234))
})
