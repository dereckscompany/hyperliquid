# File: tests/testthat/fixtures-account.R
# Fixture data for the HyperliquidAccount domain. Each function returns the R
# list that jsonlite::fromJSON(simplifyVector = FALSE) yields for one /info
# response. READ-endpoint fixtures are trimmed but faithful captures of the live
# mainnet public API (POST https://api.hyperliquid.xyz/info), captured against
# the HLP child vault 0x010461c14e146ac35fe42271bdc1134ee31c703a (fills, orders,
# positions), the HLP parent 0xdfc24b077bc1425ad1dea75bcb6f8158e10df303
# (portfolio, vault equities), and a retail address for spot balances and the
# non-funding ledger variety.

fixture_clearinghouse_state <- function() {
  return(list(
    "marginSummary" = list(
      "accountValue" = "2976574.9037540001",
      "totalNtlPos" = "3239785.2171609998",
      "totalRawUsd" = "3647125.0284449998",
      "totalMarginUsed" = "161989.260803"
    ),
    "crossMarginSummary" = list(
      "accountValue" = "2976574.9037540001",
      "totalNtlPos" = "3239785.2171609998",
      "totalRawUsd" = "3647125.0284449998",
      "totalMarginUsed" = "161989.260803"
    ),
    "crossMaintenanceMarginUsed" = "32397.852092",
    "withdrawable" = "2652596.3820770001",
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
          "returnOnEquity" = "0.0910495312",
          "liquidationPx" = NULL,
          "marginUsed" = "1894.97652",
          "maxLeverage" = 50,
          "cumFunding" = list(
            "allTime" = "-613013.0522030001",
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
          "returnOnEquity" = "0.0043838684",
          "liquidationPx" = "7863059.5308084209",
          "marginUsed" = "29.78451",
          "maxLeverage" = 50,
          "cumFunding" = list(
            "allTime" = "-484219.215542",
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
        "total" = "13967.93682455",
        "hold" = "-5.92201599",
        "entryNtl" = "0.0",
        "spotHold" = "0.0",
        "ltv" = "0.0",
        "supplied" = "13967.93682455"
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
      "hash" = "0x0d3fdb3600e5d56a0eb9043d26c359020299001b9be8f43cb1088688bfe9af54",
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
      "hash" = "0xb35e4a190053fac6b4d8043d26c35302054600fe9b5719985726f56bbf57d4b1",
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
      "hash" = "0x75fa9b7b8fa0de087774043d2593790205c500612aa3fcda19c346ce4ea4b7f3",
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
      "hash" = "0x459c804723800a524716043d25937a0201ee002cbe832924e9652b99e283e43c",
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
      "hash" = "0x75cda569c73365c3df48d6827f113c1f3af074e3902e206602696ac7a858ee3d",
      "delta" = list(
        "type" = "deposit",
        "usdc" = "1000.0"
      )
    ),
    list(
      "time" = 1701855040159,
      "hash" = "0x9f46063de5c0aa1550290352cd527e406e6fee881f1a6896c1975a058aad9324",
      "delta" = list(
        "type" = "withdraw",
        "usdc" = "1000.0",
        "nonce" = 0,
        "fee" = "0.0"
      )
    ),
    list(
      "time" = 1713247326676,
      "hash" = "0x82435945866f6295e46b04087f609c02022b00f9f0475fda679166962873ca75",
      "delta" = list(
        "type" = "accountClassTransfer",
        "usdc" = "5000.0",
        "toPerp" = FALSE
      )
    ),
    list(
      "time" = 1716966554603,
      "hash" = "0xe358d763ec548152ac76040a2da9f50149009151ce8462187427dd36603dc308",
      "delta" = list(
        "type" = "spotTransfer",
        "token" = "USDC",
        "amount" = "1000.0",
        "usdcValue" = "1000.0",
        "user" = "0xf06787919a792e966899fe4ee0562f5a62f0f611",
        "destination" = "0x2aaa85bf636d937de5f5f5469213df2737fd030c",
        "fee" = "1.0",
        "nativeTokenFee" = "0.0",
        "nonce" = NULL,
        "feeToken" = ""
      )
    ),
    list(
      "time" = 1704228321560,
      "hash" = "0x1e0a80bad26dcc1c85820406f262d9019900bed76e30f68a945266902730a78b",
      "delta" = list(
        "type" = "vaultDeposit",
        "vault" = "0xdfc24b077bc1425ad1dea75bcb6f8158e10df303",
        "usdc" = "1500.0"
      )
    ),
    list(
      "time" = 1719221607872,
      "hash" = "0x65125df2ac08a2c7fbd3040c35c60b010500e479418fcd8dfe1a9f35d6f107a7",
      "delta" = list(
        "type" = "liquidation",
        "liquidatedNtlPos" = "54187.21188",
        "accountValue" = "356.952084",
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
            "337097050.2698649764"
          ),
          list(
            1780723519209,
            "337096856.0099570155"
          )
        ),
        "pnlHistory" = list(
          list(
            1780722446769,
            "0.0"
          ),
          list(
            1780723519209,
            "19805.730092"
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
            "33814370.0411399975"
          )
        ),
        "pnlHistory" = list(
          list(
            1714607953536,
            "0.0"
          ),
          list(
            1715212533532,
            "46963553.4511509985"
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
        "userCross" = "7824407.5",
        "userAdd" = "24294497.2399999984",
        "exchange" = "4662736618.3999996185"
      ),
      list(
        "date" = "2026-05-25",
        "userCross" = "8038495.5700000003",
        "userAdd" = "27655961.629999999",
        "exchange" = "3776704106.4200000763"
      )
    ),
    "userCrossRate" = "0.00028",
    "userAddRate" = "0.0",
    "activeReferralDiscount" = "0.0"
  ))
}

fixture_user_rate_limit <- function() {
  return(list(
    "cumVlm" = "190895644047.9899902344",
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
      "subAccountUser" = "0x4cd2393c90a4e769972a9862540492b4bc19695c",
      "master" = "0x023a3d058020fb76cca98f01b3c48c8938a22355",
      "clearinghouseState" = list(
        "marginSummary" = list(
          "accountValue" = "50041.813241",
          "totalNtlPos" = "564.00245",
          "totalRawUsd" = "50605.815691",
          "totalMarginUsed" = "28.200122"
        ),
        "crossMarginSummary" = list(
          "accountValue" = "50041.813241",
          "totalNtlPos" = "564.00245",
          "totalRawUsd" = "50605.815691",
          "totalMarginUsed" = "28.200122"
        ),
        "crossMaintenanceMarginUsed" = "8.008514",
        "withdrawable" = "49985.412996",
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
              "positionValue" = "436.20465",
              "unrealizedPnl" = "90.159492",
              "returnOnEquity" = "3.4257459734",
              "liquidationPx" = "7071249.3736100169",
              "marginUsed" = "21.810232",
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
            "total" = "23383.53574",
            "hold" = "0.0",
            "entryNtl" = "0.0"
          )
        )
      )
    ),
    list(
      "name" = "hyperliquid_1s3",
      "subAccountUser" = "0x2eddf3aa5c4df34f9263a98b564bec3b4ec78179",
      "master" = "0x023a3d058020fb76cca98f01b3c48c8938a22355",
      "clearinghouseState" = list(
        "marginSummary" = list(
          "accountValue" = "4581524.7700629998",
          "totalNtlPos" = "16567257.1122210007",
          "totalRawUsd" = "15746315.0516860001",
          "totalMarginUsed" = "1521768.8570419999"
        ),
        "crossMarginSummary" = list(
          "accountValue" = "4581524.7700629998",
          "totalNtlPos" = "16567257.1122210007",
          "totalRawUsd" = "15746315.0516860001",
          "totalMarginUsed" = "1521768.8570419999"
        ),
        "crossMaintenanceMarginUsed" = "744317.568065",
        "withdrawable" = "2788861.0905010002",
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
              "positionValue" = "58876.49061",
              "unrealizedPnl" = "3480.48126",
              "returnOnEquity" = "1.1163086198",
              "liquidationPx" = "4044590.2710128045",
              "marginUsed" = "2943.82453",
              "maxLeverage" = 40,
              "cumFunding" = list(
                "allTime" = "11724.093137",
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
            "total" = "330249.81399404",
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
      "vaultAddress" = "0x010461c14e146ac35fe42271bdc1134ee31c703a",
      "equity" = "2977223.0296200002",
      "lockedUntilTimestamp" = 1773918054764
    ),
    list(
      "vaultAddress" = "0x2e3d94f0562703b25c83308a05046ddaf9a8dd14",
      "equity" = "999999.999999",
      "lockedUntilTimestamp" = 1779335307791
    )
  ))
}

fixture_user_vault_equities_empty <- function() {
  return(list())
}
