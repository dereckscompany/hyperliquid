# Fixtures for the trading domain. Each function returns the R list that
# jsonlite::fromJSON(simplifyVector = FALSE) yields for the corresponding
# /exchange response (or /info read used by the market_* chains), so the class
# methods can be exercised offline with no network.
#
# Shapes are hand-crafted from the reference SDK response envelopes documented in
# _research_hyperliquid/hyperliquid-python-sdk/hyperliquid/exchange.py:
#  - order / batchModify -> {response:{type:"order", data:{statuses:[...]}}},
#    one status per order: {resting:{oid}}, {filled:{totalSz,avgPx,oid}}, or
#    {error:"..."}.
#  - cancel / cancelByCloid -> {response:{type:"cancel", data:{statuses:[...]}}},
#    each status the string "success" or an {error:"..."} object.
#  - scheduleCancel / updateLeverage / updateIsolatedMargin / approveAgent /
#    approveBuilderFee -> the bare {status:"ok", response:{type:"default"}} ack.
# The allMids and clearinghouseState reads feed market_open / market_close.

# ---- order / batchModify acks ------------------------------------------------

# A single resting order.
fixture_order_resting <- function() {
  return(list(
    status = "ok",
    response = list(
      type = "order",
      data = list(statuses = list(
        list(resting = list(oid = 77738308))
      ))
    )
  ))
}

# A single fully-filled order.
fixture_order_filled <- function() {
  return(list(
    status = "ok",
    response = list(
      type = "order",
      data = list(statuses = list(
        list(filled = list(totalSz = "0.02", avgPx = "1891.4", oid = 77747314))
      ))
    )
  ))
}

# A mix of resting, filled, and errored statuses (a 3-order batch).
fixture_order_mixed <- function() {
  return(list(
    status = "ok",
    response = list(
      type = "order",
      data = list(statuses = list(
        list(resting = list(oid = 77738308)),
        list(filled = list(totalSz = "0.02", avgPx = "1891.4", oid = 77747314)),
        list(error = "Order must have minimum value of $10.")
      ))
    )
  ))
}

# ---- cancel / cancelByCloid acks ---------------------------------------------

fixture_cancel_success <- function() {
  return(list(
    status = "ok",
    response = list(
      type = "cancel",
      data = list(statuses = list("success"))
    )
  ))
}

# ---- simple default ack ------------------------------------------------------

# The shared success ack for scheduleCancel / updateLeverage /
# updateIsolatedMargin / approveAgent / approveBuilderFee.
fixture_action_default <- function() {
  return(list(status = "ok", response = list(type = "default")))
}

# ---- /info reads feeding the market_* chains ---------------------------------

# allMids returns a {coin: midPriceString} object.
fixture_all_mids <- function() {
  return(list(
    BTC = "61958.5",
    `PURR/USDC` = "0.0907"
  ))
}

# clearinghouseState carries assetPositions; here a single short BTC position
# (szi = -0.5) so market_close derives is_buy = TRUE and sz = 0.5.
fixture_clearinghouse_state <- function() {
  return(list(
    marginSummary = list(
      accountValue = "1000.0",
      totalNtlPos = "30000.0",
      totalRawUsd = "1000.0",
      totalMarginUsed = "500.0"
    ),
    assetPositions = list(
      list(
        type = "oneWay",
        position = list(
          coin = "BTC",
          szi = "-0.5",
          entryPx = "60000.0",
          positionValue = "30000.0",
          unrealizedPnl = "100.0",
          leverage = list(type = "cross", value = 10),
          marginUsed = "3000.0",
          maxLeverage = 40
        )
      )
    ),
    time = 1700000000000
  ))
}
