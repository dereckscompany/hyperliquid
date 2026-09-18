# File: tests/testthat/fixtures-account.R
# Fixture data for the HyperliquidAccount domain. Each function returns the R
# list that jsonlite::fromJSON(simplifyVector = FALSE) yields for one /info
# response. Every fixture is AUTHORED SYNTHETIC DATA, hand-written to be
# shape-faithful to Hyperliquid's own documented /info responses (same keys,
# nesting, and value types as the real API) -- it is never captured from a live
# account, not even scrubbed. Addresses follow a patterned scheme
# (`0x000...000N`), on-chain hashes are `0x` followed by 62 zeros and a two-digit
# suffix, order/trade ids are small invented integers, and balances/prices are
# round numbers on an invented scale. This is a public repository; nothing here
# may ever be replaced with a live capture, scrubbed or otherwise (fleet
# fixture-authoring rule, ratified 2026-07-05, re-ratified 2026-09-17). These
# same address placeholders are shared with tests/testthat/fixtures/*.json (the
# JSON fixtures the mock router serves), so a query for one of these addresses
# returns consistent data whichever fixture path a test exercises.

fixture_clearinghouse_state <- function() {
  return(list(
    "marginSummary" = list(
      "accountValue" = "100000.0",
      "totalNtlPos" = "150000.0",
      "totalRawUsd" = "160000.0",
      "totalMarginUsed" = "5000.0"
    ),
    "crossMarginSummary" = list(
      "accountValue" = "100000.0",
      "totalNtlPos" = "150000.0",
      "totalRawUsd" = "160000.0",
      "totalMarginUsed" = "5000.0"
    ),
    "crossMaintenanceMarginUsed" = "2000.0",
    "withdrawable" = "95000.0",
    "assetPositions" = list(
      list(
        "type" = "oneWay",
        "position" = list(
          "coin" = "BTC",
          "szi" = "0.61148",
          "leverage" = list(
            "type" = "cross",
            "value" = 20
          ),
          "entryPx" = "61699.1",
          "positionValue" = "37899.5304",
          "unrealizedPnl" = "171.754814",
          "returnOnEquity" = "0.09",
          "liquidationPx" = NULL,
          "marginUsed" = "1894.97652",
          "maxLeverage" = 50,
          "cumFunding" = list(
            "allTime" = "-500.0",
            "sinceOpen" = "48.50261",
            "sinceChange" = "0.0"
          )
        )
      ),
      list(
        "type" = "oneWay",
        "position" = list(
          "coin" = "ETH",
          "szi" = "-0.3708",
          "leverage" = list(
            "type" = "cross",
            "value" = 20
          ),
          "entryPx" = "1606.85",
          "positionValue" = "595.6902",
          "unrealizedPnl" = "0.1306",
          "returnOnEquity" = "0.005",
          "liquidationPx" = "6500000.0",
          "marginUsed" = "29.78451",
          "maxLeverage" = 50,
          "cumFunding" = list(
            "allTime" = "-400.0",
            "sinceOpen" = "0.0",
            "sinceChange" = "0.0"
          )
        )
      )
    ),
    "time" = 1780809593699
  ))
}

fixture_clearinghouse_state_empty <- function() {
  return(list(
    "marginSummary" = list(
      "accountValue" = "0.0",
      "totalNtlPos" = "0.0",
      "totalRawUsd" = "0.0",
      "totalMarginUsed" = "0.0"
    ),
    "crossMarginSummary" = list(
      "accountValue" = "0.0",
      "totalNtlPos" = "0.0",
      "totalRawUsd" = "0.0",
      "totalMarginUsed" = "0.0"
    ),
    "crossMaintenanceMarginUsed" = "0.0",
    "withdrawable" = "0.0",
    "assetPositions" = list(),
    "time" = 1780809593699
  ))
}

fixture_spot_balances <- function() {
  return(list(
    "balances" = list(
      list(
        "coin" = "USDC",
        "token" = 0,
        "total" = "10000.0",
        "hold" = "-5.0",
        "entryNtl" = "0.0",
        "spotHold" = "0.0",
        "ltv" = "0.0",
        "supplied" = "10000.0"
      ),
      list(
        "coin" = "PURR",
        "token" = 1,
        "total" = "0.0",
        "hold" = "0.0",
        "entryNtl" = "0.0"
      ),
      list(
        "coin" = "HFUN",
        "token" = 2,
        "total" = "0.0",
        "hold" = "0.0",
        "entryNtl" = "0.0"
      )
    )
  ))
}

fixture_spot_balances_empty <- function() {
  return(list(
    "balances" = list()
  ))
}

fixture_open_orders <- function() {
  return(list(
    list(
      "coin" = "MERL",
      "side" = "B",
      "limitPx" = "0.020781",
      "sz" = "37035.0",
      "oid" = 461291857939,
      "timestamp" = 1780809597698,
      "origSz" = "37035.0"
    ),
    list(
      "coin" = "AERO",
      "side" = "A",
      "limitPx" = "0.33001",
      "sz" = "583.0",
      "oid" = 461291857943,
      "timestamp" = 1780809597698,
      "origSz" = "583.0"
    )
  ))
}

fixture_open_orders_empty <- function() {
  return(list())
}

fixture_frontend_open_orders <- function() {
  return(list(
    list(
      "coin" = "SOL",
      "side" = "A",
      "limitPx" = "64.367",
      "sz" = "6.75",
      "oid" = 461291918938,
      "timestamp" = 1780809600395,
      "triggerCondition" = "N/A",
      "isTrigger" = FALSE,
      "triggerPx" = "0.0",
      "children" = list(),
      "isPositionTpsl" = FALSE,
      "reduceOnly" = FALSE,
      "orderType" = "Limit",
      "origSz" = "6.75",
      "tif" = "Alo",
      "cloid" = NULL
    ),
    list(
      "coin" = "ETH",
      "side" = "A",
      "limitPx" = "1606.4",
      "sz" = "0.3844",
      "oid" = 461291918934,
      "timestamp" = 1780809600395,
      "triggerCondition" = "N/A",
      "isTrigger" = FALSE,
      "triggerPx" = "0.0",
      "children" = list(),
      "isPositionTpsl" = FALSE,
      "reduceOnly" = FALSE,
      "orderType" = "Limit",
      "origSz" = "0.3844",
      "tif" = "Alo",
      "cloid" = NULL
    )
  ))
}

fixture_user_fills <- function() {
  return(list(
    list(
      "coin" = "IOTA",
      "px" = "0.045274",
      "sz" = "371.0",
      "side" = "B",
      "time" = 1780809599202,
      "startPosition" = "259108.0",
      "dir" = "Open Long",
      "closedPnl" = "0.0",
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000001",
      "oid" = 461291888494,
      "crossed" = TRUE,
      "fee" = "0.0",
      "tid" = 450054518611160,
      "feeToken" = "USDC",
      "twapId" = NULL
    ),
    list(
      "coin" = "PENDLE",
      "px" = "1.2453",
      "sz" = "253.0",
      "side" = "A",
      "time" = 1780809598801,
      "startPosition" = "-26314.0",
      "dir" = "Open Short",
      "closedPnl" = "0.0",
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000002",
      "oid" = 461291857900,
      "crossed" = FALSE,
      "fee" = "0.0",
      "tid" = 178929375705502,
      "feeToken" = "USDC",
      "twapId" = NULL
    )
  ))
}

fixture_user_fills_empty <- function() {
  return(list())
}

fixture_user_fills_by_time <- function() {
  return(list(
    list(
      "coin" = "SKR",
      "px" = "0.009933",
      "sz" = "1618.0",
      "side" = "B",
      "time" = 1780804265326,
      "startPosition" = "4591789.0",
      "dir" = "Open Long",
      "closedPnl" = "0.0",
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000003",
      "oid" = 461238665707,
      "crossed" = TRUE,
      "fee" = "0.0",
      "tid" = 1059038358247479,
      "feeToken" = "USDC",
      "twapId" = NULL
    ),
    list(
      "coin" = "PURR",
      "px" = "0.087747",
      "sz" = "195.0",
      "side" = "A",
      "time" = 1780804265395,
      "startPosition" = "65806.0",
      "dir" = "Close Long",
      "closedPnl" = "-0.542685",
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000004",
      "oid" = 461238666387,
      "crossed" = TRUE,
      "fee" = "0.0",
      "tid" = 593913440474032,
      "feeToken" = "USDC",
      "twapId" = NULL
    )
  ))
}

fixture_historical_orders <- function() {
  return(list(
    list(
      "order" = list(
        "coin" = "STRK",
        "side" = "B",
        "limitPx" = "0.03254",
        "sz" = "12682.9",
        "oid" = 461291892194,
        "timestamp" = 1780809599506,
        "triggerCondition" = "N/A",
        "isTrigger" = FALSE,
        "triggerPx" = "0.0",
        "children" = list(),
        "isPositionTpsl" = FALSE,
        "reduceOnly" = FALSE,
        "orderType" = "Limit",
        "origSz" = "12682.9",
        "tif" = "Alo",
        "cloid" = NULL
      ),
      "status" = "canceled",
      "statusTimestamp" = 1780809599981
    ),
    list(
      "order" = list(
        "coin" = "STRK",
        "side" = "B",
        "limitPx" = "0.03254",
        "sz" = "12682.9",
        "oid" = 461291892194,
        "timestamp" = 1780809599506,
        "triggerCondition" = "N/A",
        "isTrigger" = FALSE,
        "triggerPx" = "0.0",
        "children" = list(),
        "isPositionTpsl" = FALSE,
        "reduceOnly" = FALSE,
        "orderType" = "Limit",
        "origSz" = "12682.9",
        "tif" = "Alo",
        "cloid" = NULL
      ),
      "status" = "open",
      "statusTimestamp" = 1780809599506
    ),
    list(
      "order" = list(
        "coin" = "IOTA",
        "side" = "B",
        "limitPx" = "0.045274",
        "sz" = "0.0",
        "oid" = 461291888494,
        "timestamp" = 1780809599202,
        "triggerCondition" = "N/A",
        "isTrigger" = FALSE,
        "triggerPx" = "0.0",
        "children" = list(),
        "isPositionTpsl" = FALSE,
        "reduceOnly" = FALSE,
        "orderType" = "Limit",
        "origSz" = "371.0",
        "tif" = "Ioc",
        "cloid" = NULL
      ),
      "status" = "filled",
      "statusTimestamp" = 1780809599202
    )
  ))
}

fixture_historical_orders_empty <- function() {
  return(list())
}

fixture_user_funding <- function() {
  return(list(
    list(
      "time" = 1735689600000,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000000",
      "delta" = list(
        "type" = "funding",
        "coin" = "AAVE",
        "usdc" = "148.912547",
        "szi" = "-431.91958333",
        "fundingRate" = "0.00004551",
        "nSamples" = 24
      )
    ),
    list(
      "time" = 1735689600000,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000000",
      "delta" = list(
        "type" = "funding",
        "coin" = "ACE",
        "usdc" = "26.873315",
        "szi" = "-43298.37416667",
        "fundingRate" = "0.0000125",
        "nSamples" = 24
      )
    )
  ))
}

fixture_user_funding_empty <- function() {
  return(list())
}

fixture_non_funding_ledger <- function() {
  return(list(
    list(
      "time" = 1706647333387,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000005",
      "delta" = list(
        "type" = "deposit",
        "usdc" = "1000.0"
      )
    ),
    list(
      "time" = 1701855040159,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000006",
      "delta" = list(
        "type" = "withdraw",
        "usdc" = "1000.0",
        "nonce" = 0,
        "fee" = "0.0"
      )
    ),
    list(
      "time" = 1713247326676,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000007",
      "delta" = list(
        "type" = "accountClassTransfer",
        "usdc" = "5000.0",
        "toPerp" = FALSE
      )
    ),
    list(
      "time" = 1716966554603,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000008",
      "delta" = list(
        "type" = "spotTransfer",
        "token" = "USDC",
        "amount" = "1000.0",
        "usdcValue" = "1000.0",
        "user" = "0x0000000000000000000000000000000000000003",
        "destination" = "0x0000000000000000000000000000000000000004",
        "fee" = "1.0",
        "nativeTokenFee" = "0.0",
        "nonce" = NULL,
        "feeToken" = ""
      )
    ),
    list(
      "time" = 1704228321560,
      "hash" = "0x0000000000000000000000000000000000000000000000000000000000000009",
      "delta" = list(
        "type" = "vaultDeposit",
        "vault" = "0x0000000000000000000000000000000000000002",
        "usdc" = "1500.0"
      )
    ),
    list(
      "time" = 1719221607872,
      "hash" = "0x000000000000000000000000000000000000000000000000000000000000000a",
      "delta" = list(
        "type" = "liquidation",
        "liquidatedNtlPos" = "50000.0",
        "accountValue" = "500.0",
        "leverageType" = "Isolated",
        "liquidatedPositions" = list(
          list(
            "coin" = "ETH",
            "szi" = "16.5908"
          )
        )
      )
    )
  ))
}

fixture_non_funding_ledger_empty <- function() {
  return(list())
}

fixture_portfolio <- function() {
  return(list(
    list(
      "day",
      list(
        "accountValueHistory" = list(
          list(
            1780722446769,
            "500000.0"
          ),
          list(
            1780723519209,
            "500100.0"
          )
        ),
        "pnlHistory" = list(
          list(
            1780722446769,
            "0.0"
          ),
          list(
            1780723519209,
            "20000.0"
          )
        ),
        "vlm" = "0.0"
      )
    ),
    list(
      "perpAllTime",
      list(
        "accountValueHistory" = list(
          list(
            1714607953536,
            "0.0"
          ),
          list(
            1715212533532,
            "1000000.0"
          )
        ),
        "pnlHistory" = list(
          list(
            1714607953536,
            "0.0"
          ),
          list(
            1715212533532,
            "1200000.0"
          )
        ),
        "vlm" = "0.0"
      )
    )
  ))
}

fixture_user_fees <- function() {
  return(list(
    "dailyUserVlm" = list(
      list(
        "date" = "2026-05-24",
        "userCross" = "7000000.0",
        "userAdd" = "24000000.0",
        "exchange" = "4600000000.0"
      ),
      list(
        "date" = "2026-05-25",
        "userCross" = "7100000.0",
        "userAdd" = "27000000.0",
        "exchange" = "3700000000.0"
      )
    ),
    "userCrossRate" = "0.00028",
    "userAddRate" = "0.0",
    "activeReferralDiscount" = "0.0"
  ))
}

fixture_user_rate_limit <- function() {
  return(list(
    "cumVlm" = "190000000000.0",
    "nRequestsUsed" = 51346860978,
    "nRequestsCap" = 190895654047,
    "nRequestsSurplus" = 0
  ))
}

fixture_user_role <- function() {
  return(list(
    "role" = "vault"
  ))
}

fixture_sub_accounts_null <- function() {
  return(NULL)
}

fixture_sub_accounts <- function() {
  return(list(
    list(
      "name" = "hyperliquid_1s2",
      "subAccountUser" = "0x0000000000000000000000000000000000000005",
      "master" = "0x0000000000000000000000000000000000000006",
      "clearinghouseState" = list(
        "marginSummary" = list(
          "accountValue" = "50000.0",
          "totalNtlPos" = "600.0",
          "totalRawUsd" = "50500.0",
          "totalMarginUsed" = "25.0"
        ),
        "crossMarginSummary" = list(
          "accountValue" = "50000.0",
          "totalNtlPos" = "600.0",
          "totalRawUsd" = "50500.0",
          "totalMarginUsed" = "25.0"
        ),
        "crossMaintenanceMarginUsed" = "10.0",
        "withdrawable" = "49500.0",
        "assetPositions" = list(
          list(
            "type" = "oneWay",
            "position" = list(
              "coin" = "BTC",
              "szi" = "-0.00705",
              "leverage" = list(
                "type" = "cross",
                "value" = 20
              ),
              "entryPx" = "74661.5",
              "positionValue" = "500.0",
              "unrealizedPnl" = "100.0",
              "returnOnEquity" = "3.0",
              "liquidationPx" = "7000000.0",
              "marginUsed" = "20.0",
              "maxLeverage" = 40,
              "cumFunding" = list(
                "allTime" = "-3.138913",
                "sinceOpen" = "-0.511572",
                "sinceChange" = "-0.800986"
              )
            )
          )
        ),
        "time" = 1780809879828
      ),
      "spotState" = list(
        "balances" = list(
          list(
            "coin" = "USDC",
            "token" = 0,
            "total" = "20000.0",
            "hold" = "0.0",
            "entryNtl" = "0.0"
          )
        )
      )
    ),
    list(
      "name" = "hyperliquid_1s3",
      "subAccountUser" = "0x0000000000000000000000000000000000000007",
      "master" = "0x0000000000000000000000000000000000000006",
      "clearinghouseState" = list(
        "marginSummary" = list(
          "accountValue" = "500000.0",
          "totalNtlPos" = "1500000.0",
          "totalRawUsd" = "1400000.0",
          "totalMarginUsed" = "140000.0"
        ),
        "crossMarginSummary" = list(
          "accountValue" = "500000.0",
          "totalNtlPos" = "1500000.0",
          "totalRawUsd" = "1400000.0",
          "totalMarginUsed" = "140000.0"
        ),
        "crossMaintenanceMarginUsed" = "70000.0",
        "withdrawable" = "280000.0",
        "assetPositions" = list(
          list(
            "type" = "oneWay",
            "position" = list(
              "coin" = "BTC",
              "szi" = "-0.95157",
              "leverage" = list(
                "type" = "cross",
                "value" = 20
              ),
              "entryPx" = "65530.6",
              "positionValue" = "55000.0",
              "unrealizedPnl" = "3000.0",
              "returnOnEquity" = "1.0",
              "liquidationPx" = "4000000.0",
              "marginUsed" = "2500.0",
              "maxLeverage" = 40,
              "cumFunding" = list(
                "allTime" = "10000.0",
                "sinceOpen" = "-108.169544",
                "sinceChange" = "-8.412"
              )
            )
          )
        ),
        "time" = 1780809879828
      ),
      "spotState" = list(
        "balances" = list(
          list(
            "coin" = "USDC",
            "token" = 0,
            "total" = "300000.0",
            "hold" = "15101.6371",
            "entryNtl" = "0.0"
          )
        )
      )
    )
  ))
}

fixture_order_status <- function() {
  return(list(
    "status" = "order",
    "order" = list(
      "order" = list(
        "coin" = "AERO",
        "side" = "A",
        "limitPx" = "0.33001",
        "sz" = "583.0",
        "oid" = 461291857943,
        "timestamp" = 1780809597698,
        "triggerCondition" = "N/A",
        "isTrigger" = FALSE,
        "triggerPx" = "0.0",
        "children" = list(),
        "isPositionTpsl" = FALSE,
        "reduceOnly" = FALSE,
        "orderType" = "Limit",
        "origSz" = "583.0",
        "tif" = "Alo",
        "cloid" = NULL
      ),
      "status" = "canceled",
      "statusTimestamp" = 1780809599916
    )
  ))
}

fixture_order_status_unknown <- function() {
  return(list(
    "status" = "unknownOid"
  ))
}

fixture_user_vault_equities <- function() {
  return(list(
    list(
      "vaultAddress" = "0x0000000000000000000000000000000000000001",
      "equity" = "100000.0",
      "lockedUntilTimestamp" = 1773918054764
    ),
    list(
      "vaultAddress" = "0x0000000000000000000000000000000000000008",
      "equity" = "999999.999999",
      "lockedUntilTimestamp" = 1779335307791
    )
  ))
}

fixture_user_vault_equities_empty <- function() {
  return(list())
}
