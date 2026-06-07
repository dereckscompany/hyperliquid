# Fixtures for HyperliquidMarketData. Each function returns the R list that
# jsonlite::fromJSON(simplifyVector = FALSE) yields for one /info market-data
# response type. Read shapes are trimmed captures of the live mainnet public API
# (POST https://api.hyperliquid.xyz/info), with field names and string/number
# encodings preserved exactly as the API returns them. These also feed the
# shared mock router for the README and vignettes.

# meta -> perp universe. Includes a delisted asset (MATIC) and an isolated-only
# asset carrying marginMode (HOOD) to exercise the sparse logical/string columns.
hl_md_meta <- function() {
  list(
    universe = list(
      list(szDecimals = 5L, name = "BTC", maxLeverage = 40L, marginTableId = 56L),
      list(szDecimals = 4L, name = "ETH", maxLeverage = 25L, marginTableId = 55L),
      list(szDecimals = 1L, name = "MATIC", maxLeverage = 20L, marginTableId = 20L, isDelisted = TRUE),
      list(
        szDecimals = 3L,
        name = "HOOD",
        maxLeverage = 10L,
        marginTableId = 10L,
        onlyIsolated = TRUE,
        marginMode = "noCross"
      )
    ),
    marginTables = list(),
    collateralToken = 0L
  )
}

# spotMeta -> the pair universe and the token table, consumed by two siblings.
hl_md_spot_meta <- function() {
  list(
    universe = list(
      list(tokens = list(1L, 0L), name = "PURR/USDC", index = 0L, isCanonical = TRUE),
      list(tokens = list(2L, 0L), name = "@1", index = 1L, isCanonical = FALSE)
    ),
    tokens = list(
      list(
        name = "USDC",
        szDecimals = 8L,
        weiDecimals = 8L,
        index = 0L,
        tokenId = "0x6d1e7cde53ba9467b783cb7c530ce054",
        isCanonical = TRUE,
        evmContract = list(address = "0x6b9e773128f453f5c2c60935ee2de2cbc5390a24", evm_extra_wei_decimals = -2L),
        fullName = NULL,
        deployerTradingFeeShare = "0.0"
      ),
      list(
        name = "PURR",
        szDecimals = 0L,
        weiDecimals = 5L,
        index = 1L,
        tokenId = "0xc1fb593aeffbeb02f85e0308e9956a90",
        isCanonical = TRUE,
        evmContract = NULL,
        fullName = NULL,
        deployerTradingFeeShare = "0.0"
      )
    )
  )
}

# metaAndAssetCtxs -> [meta, ctxs] positional pair, joined by index.
hl_md_meta_and_asset_ctxs <- function() {
  list(
    list(
      universe = list(
        list(szDecimals = 5L, name = "BTC", maxLeverage = 40L, marginTableId = 56L),
        list(szDecimals = 4L, name = "ETH", maxLeverage = 25L, marginTableId = 55L)
      )
    ),
    list(
      list(
        funding = "0.0000125",
        openInterest = "33122.6367",
        prevDayPx = "60729.0",
        dayNtlVlm = "2636140606.5446190834",
        premium = "-0.0003065208",
        oraclePx = "61986.0",
        markPx = "61964.0",
        midPx = "61966.5",
        impactPxs = list("61966.0", "61967.0"),
        dayBaseVlm = "43271.48724"
      ),
      list(
        funding = "0.0000064122",
        openInterest = "685018.9388",
        prevDayPx = "1548.8",
        dayNtlVlm = "692425434.4373297691",
        premium = "-0.0004604854",
        oraclePx = "1607.0",
        markPx = "1606.2",
        midPx = "1606.15",
        impactPxs = list("1606.1", "1606.26"),
        dayBaseVlm = "441613.2052999999"
      )
    )
  )
}

# spotMetaAndAssetCtxs -> [spotMeta, ctxs]; each ctx carries its own coin.
hl_md_spot_meta_and_asset_ctxs <- function() {
  list(
    list(universe = list(), tokens = list()),
    list(
      list(
        prevDayPx = "0.08889",
        dayNtlVlm = "912632.1060209998",
        markPx = "0.090784",
        midPx = "0.0908055",
        circulatingSupply = "595295911.3807499409",
        coin = "PURR/USDC",
        totalSupply = "595295917.9035300016",
        dayBaseVlm = "10471112.0"
      ),
      list(
        prevDayPx = "9.7168",
        dayNtlVlm = "28631.474477",
        markPx = "9.6794",
        midPx = "9.6738",
        circulatingSupply = "995906.4607351",
        coin = "@1",
        totalSupply = "995906.51156126",
        dayBaseVlm = "2957.81"
      )
    )
  )
}

# allMids -> a {coin: mid} dictionary.
hl_md_all_mids <- function() {
  list(
    BTC = "61958.5",
    ETH = "1605.45",
    "@1" = "9.6738"
  )
}

# l2Book -> {coin, time, levels: [bids, asks]} with 2 levels per side.
hl_md_l2_book <- function() {
  list(
    coin = "BTC",
    time = 1780809622422,
    levels = list(
      list(
        list(px = "61945.0", sz = "0.03164", n = 3L),
        list(px = "61944.0", sz = "0.00085", n = 4L)
      ),
      list(
        list(px = "61946.0", sz = "13.32523", n = 39L),
        list(px = "61947.0", sz = "0.06724", n = 6L)
      )
    )
  )
}

# candleSnapshot -> array of OHLCV objects. Returned here out of order to verify
# the parser sorts ascending by open time.
hl_md_candles <- function() {
  list(
    list(
      t = 1780790400000,
      T = 1780793999999,
      s = "BTC",
      i = "1h",
      o = "60860.0",
      c = "60750.0",
      h = "60974.0",
      l = "60714.0",
      v = "1293.43482",
      n = 15829L
    ),
    list(
      t = 1780786800000,
      T = 1780790399999,
      s = "BTC",
      i = "1h",
      o = "60516.0",
      c = "60861.0",
      h = "60937.0",
      l = "60511.0",
      v = "1167.72245",
      n = 15901L
    )
  )
}

# fundingHistory -> array of {coin, fundingRate, premium, time}.
hl_md_funding_history <- function() {
  list(
    list(coin = "BTC", fundingRate = "0.0000034197", premium = "-0.0004726428", time = 1780552800007),
    list(coin = "BTC", fundingRate = "0.000010114", premium = "-0.0004190877", time = 1780556400059)
  )
}

# predictedFundings -> [coin, [[venue, {rate,...}]]]. The "AI" coin carries a
# venue with a null body and a venue missing fundingIntervalHours.
hl_md_predicted_fundings <- function() {
  list(
    list(
      "BTC",
      list(
        list("BinPerp", list(fundingRate = "-0.00004982", nextFundingTime = 1780819200000, fundingIntervalHours = 4L)),
        list("HlPerp", list(fundingRate = "-0.0000815806", nextFundingTime = 1780808400000, fundingIntervalHours = 1L))
      )
    ),
    list(
      "AI",
      list(
        list("BinPerp", list(fundingRate = "0.0", nextFundingTime = 1780819200000)),
        list("BybitPerp", NULL)
      )
    )
  )
}

# perpDexs -> [null core sentinel, then builder-deployed dexes].
hl_md_perp_dexs <- function() {
  list(
    NULL,
    list(
      name = "xyz",
      fullName = "XYZ",
      deployer = "0x88806a71d74ad0a510b350545c9ae490912f0888",
      oracleUpdater = NULL,
      feeRecipient = "0x9cd0a696c7cbb9d44de99268194cb08e5684e5fe"
    )
  )
}

# recentTrades -> array of trades; users is [buyer, seller]; side is B/A.
hl_md_recent_trades <- function() {
  list(
    list(
      coin = "BTC",
      side = "B",
      px = "61917.0",
      sz = "0.00032",
      time = 1780809632050,
      hash = "0x0000000000000000000000000000000000000000000000000000000000000000",
      tid = 867924607859908,
      users = list("0x28f0233472b6a44e170e002a72845ca100be4a7e", "0x1c1c270b573d55b68b3d14722b5d5d401511bed0")
    ),
    list(
      coin = "BTC",
      side = "A",
      px = "61916.0",
      sz = "0.001",
      time = 1780809631657,
      hash = "0xc21d4ed7bbf8e7c7c397043d26c52302020000bd56fc069965e5fa2a7afcc1b2",
      tid = 344331450499251,
      users = list("0xa62b923a112d50d03e1e096bbd53422490dac104", "0x60b9a6713427c83608d9daecfa06a6d2361f0614")
    )
  )
}

# exchangeStatus -> {specialStatuses, time}; specialStatuses is null in practice.
hl_md_exchange_status <- function() {
  list(specialStatuses = NULL, time = 1780809634220)
}
