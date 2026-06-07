# File: R/parse_marketdata.R
# Endpoint parsers for HyperliquidMarketData. Each takes the raw parsed JSON
# (jsonlite::fromJSON(simplifyVector = FALSE) output) of one /info market-data
# request type and returns ONE flat data.table: snake_case columns, numbers
# coerced from strings, epoch-ms timestamps as POSIXct UTC, positional/parallel
# arrays zipped long, and never a list column. Empty input -> zero-row table.

#' Parse a `meta` Response (Perp Universe)
#'
#' One row per perpetual in `universe`. `marginTables`/`collateralToken` are
#' top-level extras and are ignored here.
#'
#' @param data List; the parsed `{type:"meta"}` response.
#' @return A [data.table::data.table] with columns `name`, `sz_decimals`,
#'   `max_leverage`, `margin_table_id`, `only_isolated`, `is_delisted`,
#'   `margin_mode`.
#' @keywords internal
#' @noRd
parse_meta <- function(data) {
  universe <- data$universe
  if (is.null(universe) || length(universe) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(universe, function(u) {
    return(data.table::data.table(
      name = chr_or_na(u$name),
      sz_decimals = num_or_na(u$szDecimals),
      max_leverage = num_or_na(u$maxLeverage),
      margin_table_id = num_or_na(u$marginTableId),
      only_isolated = lgl_or_na(u$onlyIsolated),
      is_delisted = as.logical(coalesce_null(u$isDelisted, FALSE)),
      margin_mode = chr_or_na(u$marginMode)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse a `spotMeta` Response: the Pair Universe
#'
#' One row per spot pair in `universe`. `tokens` is a `[base, quote]` pair of
#' token indices, split into `token_base` / `token_quote`.
#'
#' @param data List; the parsed `{type:"spotMeta"}` response.
#' @return A [data.table::data.table] with columns `name`, `index`,
#'   `is_canonical`, `token_base`, `token_quote`.
#' @keywords internal
#' @noRd
parse_spot_meta_universe <- function(data) {
  universe <- data$universe
  if (is.null(universe) || length(universe) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(universe, function(u) {
    return(data.table::data.table(
      name = chr_or_na(u$name),
      index = num_or_na(u$index),
      is_canonical = lgl_or_na(u$isCanonical),
      token_base = nth_num(u$tokens, 1L),
      token_quote = nth_num(u$tokens, 2L)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse a `spotMeta` Response: the Token Table
#'
#' One row per token in `tokens`.
#'
#' @param data List; the parsed `{type:"spotMeta"}` response.
#' @return A [data.table::data.table] with columns `name`, `index`,
#'   `sz_decimals`, `wei_decimals`, `token_id`, `is_canonical`.
#' @keywords internal
#' @noRd
parse_spot_tokens <- function(data) {
  tokens <- data$tokens
  if (is.null(tokens) || length(tokens) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(tokens, function(t) {
    return(data.table::data.table(
      name = chr_or_na(t$name),
      index = num_or_na(t$index),
      sz_decimals = num_or_na(t$szDecimals),
      wei_decimals = num_or_na(t$weiDecimals),
      token_id = chr_or_na(t$tokenId),
      is_canonical = lgl_or_na(t$isCanonical)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse a `metaAndAssetCtxs` Response
#'
#' The payload is the positional pair `[meta, ctxs]`; `meta$universe[i]` is
#' joined with `ctxs[i]` by index, one row per perp coin. `impactPxs` is a
#' `[bid, ask]` 2-array.
#'
#' @param data List; the parsed `{type:"metaAndAssetCtxs"}` response.
#' @return A [data.table::data.table] with columns `name`, `sz_decimals`,
#'   `max_leverage`, `day_ntl_vlm`, `funding`, `mark_px`, `mid_px`, `oracle_px`,
#'   `open_interest`, `premium`, `prev_day_px`, `impact_px_bid`, `impact_px_ask`.
#' @keywords internal
#' @noRd
parse_meta_and_asset_ctxs <- function(data) {
  universe <- data[[1]]$universe
  ctxs <- data[[2]]
  if (is.null(universe) || length(universe) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(seq_along(universe), function(i) {
    u <- universe[[i]]
    ctx <- list()
    if (length(ctxs) >= i && !is.null(ctxs[[i]])) {
      ctx <- ctxs[[i]]
    }
    return(data.table::data.table(
      name = chr_or_na(u$name),
      sz_decimals = num_or_na(u$szDecimals),
      max_leverage = num_or_na(u$maxLeverage),
      day_ntl_vlm = num_or_na(ctx$dayNtlVlm),
      funding = num_or_na(ctx$funding),
      mark_px = num_or_na(ctx$markPx),
      mid_px = num_or_na(ctx$midPx),
      oracle_px = num_or_na(ctx$oraclePx),
      open_interest = num_or_na(ctx$openInterest),
      premium = num_or_na(ctx$premium),
      prev_day_px = num_or_na(ctx$prevDayPx),
      impact_px_bid = nth_num(ctx$impactPxs, 1L),
      impact_px_ask = nth_num(ctx$impactPxs, 2L)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse a `spotMetaAndAssetCtxs` Response
#'
#' The payload is the positional pair `[spotMeta, ctxs]`; each context already
#' carries its own `coin`, so one row per spot coin comes straight from `ctxs`.
#'
#' @param data List; the parsed `{type:"spotMetaAndAssetCtxs"}` response.
#' @return A [data.table::data.table] with columns `coin`, `day_ntl_vlm`,
#'   `mark_px`, `mid_px`, `prev_day_px`, `circulating_supply`.
#' @keywords internal
#' @noRd
parse_spot_meta_and_asset_ctxs <- function(data) {
  ctxs <- data[[2]]
  if (is.null(ctxs) || length(ctxs) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(ctxs, function(ctx) {
    return(data.table::data.table(
      coin = chr_or_na(ctx$coin),
      day_ntl_vlm = num_or_na(ctx$dayNtlVlm),
      mark_px = num_or_na(ctx$markPx),
      mid_px = num_or_na(ctx$midPx),
      prev_day_px = num_or_na(ctx$prevDayPx),
      circulating_supply = num_or_na(ctx$circulatingSupply)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse an `allMids` Response
#'
#' The payload is a `{coin: mid}` dictionary; it becomes a long two-column
#' table, one row per coin.
#'
#' @param data Named list; the parsed `{type:"allMids"}` response.
#' @return A [data.table::data.table] with columns `coin`, `mid`.
#' @keywords internal
#' @noRd
parse_all_mids <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  coins <- names(data)
  return(data.table::data.table(
    coin = coins,
    mid = vapply(coins, function(k) num_or_na(data[[k]]), numeric(1L), USE.NAMES = FALSE)
  )[])
}

#' Parse an `l2Book` Response
#'
#' `levels` is the positional pair `[bids, asks]`; both sides are stacked long
#' with a `side` discriminator and a 1-indexed `level` within each side.
#'
#' @param data List; the parsed `{type:"l2Book"}` response.
#' @return A [data.table::data.table] with columns `side`, `level`, `px`, `sz`,
#'   `n`.
#' @keywords internal
#' @noRd
parse_l2_book <- function(data) {
  levels <- data$levels
  if (is.null(levels) || length(levels) == 0L) {
    return(data.table::data.table()[])
  }
  side_names <- c("bid", "ask")
  rows <- list()
  for (s in seq_along(levels)) {
    book_side <- levels[[s]]
    side_label <- side_names[s]
    if (is.null(book_side) || length(book_side) == 0L) {
      next
    }
    for (lvl in seq_along(book_side)) {
      entry <- book_side[[lvl]]
      rows[[length(rows) + 1L]] <- data.table::data.table(
        side = side_label,
        level = lvl,
        px = num_or_na(entry$px),
        sz = num_or_na(entry$sz),
        n = num_or_na(entry$n)
      )
    }
  }
  if (length(rows) == 0L) {
    return(data.table::data.table()[])
  }
  return(data.table::rbindlist(rows)[])
}

#' Parse a `candleSnapshot` Response
#'
#' One row per candle, sorted ascending by open time. Open time `t` becomes the
#' canonical `datetime`; close time `T` becomes `close_time`.
#'
#' @param data List; the parsed `{type:"candleSnapshot"}` response.
#' @return A [data.table::data.table] with columns `datetime`, `open`, `high`,
#'   `low`, `close`, `volume`, `trades`, `close_time`, `interval`, `coin`.
#' @keywords internal
#' @noRd
parse_candles <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(data, function(c) {
    return(data.table::data.table(
      datetime = ms_to_datetime(num_or_na(c$t)),
      open = num_or_na(c$o),
      high = num_or_na(c$h),
      low = num_or_na(c$l),
      close = num_or_na(c$c),
      volume = num_or_na(c$v),
      trades = num_or_na(c$n),
      close_time = ms_to_datetime(num_or_na(c$T)),
      interval = chr_or_na(c$i),
      coin = chr_or_na(c$s)
    ))
  })
  dt <- data.table::rbindlist(rows)
  data.table::setorderv(dt, "datetime")
  return(dt[])
}

#' Parse a `fundingHistory` Response
#'
#' @param data List; the parsed `{type:"fundingHistory"}` response.
#' @return A [data.table::data.table] with columns `coin`, `funding_rate`,
#'   `premium`, `time`.
#' @keywords internal
#' @noRd
parse_funding_history <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(data, function(f) {
    return(data.table::data.table(
      coin = chr_or_na(f$coin),
      funding_rate = num_or_na(f$fundingRate),
      premium = num_or_na(f$premium),
      time = ms_to_datetime(num_or_na(f$time))
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse a `predictedFundings` Response
#'
#' The payload nests as `[coin, [[venue, {rate, ...}]]]`; it is flattened long
#' to one row per (coin, venue). A venue whose body is `null` yields `NA` rate
#' fields.
#'
#' @param data List; the parsed `{type:"predictedFundings"}` response.
#' @return A [data.table::data.table] with columns `coin`, `venue`,
#'   `funding_rate`, `next_funding_time`, `funding_interval_hours`.
#' @keywords internal
#' @noRd
parse_predicted_fundings <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- list()
  for (entry in data) {
    coin <- entry[[1]]
    venues <- entry[[2]]
    for (v in venues) {
      venue <- v[[1]]
      body <- v[[2]]
      rows[[length(rows) + 1L]] <- data.table::data.table(
        coin = chr_or_na(coin),
        venue = chr_or_na(venue),
        funding_rate = num_or_na(body$fundingRate),
        next_funding_time = ms_to_datetime(num_or_na(body$nextFundingTime)),
        funding_interval_hours = num_or_na(body$fundingIntervalHours)
      )
    }
  }
  if (length(rows) == 0L) {
    return(data.table::data.table()[])
  }
  return(data.table::rbindlist(rows)[])
}

#' Parse a `perpDexs` Response
#'
#' The first element is the `null` core-dex sentinel and is skipped; one row per
#' builder-deployed perp dex.
#'
#' @param data List; the parsed `{type:"perpDexs"}` response.
#' @return A [data.table::data.table] with columns `name`, `full_name`,
#'   `deployer`, `oracle_updater`, `fee_recipient`.
#' @keywords internal
#' @noRd
parse_perp_dexs <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- list()
  for (dex in data) {
    if (is.null(dex)) {
      next
    }
    rows[[length(rows) + 1L]] <- data.table::data.table(
      name = chr_or_na(dex$name),
      full_name = chr_or_na(dex$fullName),
      deployer = chr_or_na(dex$deployer),
      oracle_updater = chr_or_na(dex$oracleUpdater),
      fee_recipient = chr_or_na(dex$feeRecipient)
    )
  }
  if (length(rows) == 0L) {
    return(data.table::data.table()[])
  }
  return(data.table::rbindlist(rows)[])
}

#' Parse a `recentTrades` Response
#'
#' `users` is the positional pair `[buyer, seller]`. Side `B`/`A` is mapped to
#' the friendly `buy`/`sell`.
#'
#' @param data List; the parsed `{type:"recentTrades"}` response.
#' @return A [data.table::data.table] with columns `coin`, `side`, `px`, `sz`,
#'   `time`, `hash`, `tid`, `user_buyer`, `user_seller`.
#' @keywords internal
#' @noRd
parse_recent_trades <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  rows <- lapply(data, function(tr) {
    return(data.table::data.table(
      coin = chr_or_na(tr$coin),
      side = unname(coalesce_null(ORDER_SIDE_FROM_WIRE[chr_or_na(tr$side)], NA_character_)),
      px = num_or_na(tr$px),
      sz = num_or_na(tr$sz),
      time = ms_to_datetime(num_or_na(tr$time)),
      hash = chr_or_na(tr$hash),
      tid = num_or_na(tr$tid),
      user_buyer = nth_chr(tr$users, 1L),
      user_seller = nth_chr(tr$users, 2L)
    ))
  })
  return(data.table::rbindlist(rows)[])
}

#' Parse an `exchangeStatus` Response
#'
#' @param data List; the parsed `{type:"exchangeStatus"}` response.
#' @return A single-row [data.table::data.table] with columns `time`,
#'   `special_statuses` (a JSON string, or `NA` when absent).
#' @keywords internal
#' @noRd
parse_exchange_status <- function(data) {
  if (is.null(data) || length(data) == 0L) {
    return(data.table::data.table()[])
  }
  special <- NA_character_
  if (!is.null(data$specialStatuses)) {
    special <- as.character(jsonlite::toJSON(data$specialStatuses, auto_unbox = TRUE, null = "null"))
  }
  return(data.table::data.table(
    time = ms_to_datetime(num_or_na(data$time)),
    special_statuses = special
  )[])
}
