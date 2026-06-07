# File: R/impl_klines.R
# Shared candle (kline) fetching implementation used by both
# HyperliquidMarketData and hyperliquid_backfill_klines(). Handles time-range
# segmentation into <= max_candles windows, per-segment /info requests,
# deduplication of the 1-candle overlap, and ascending sort.
#
# This function is instance-free: it takes a `.req_fn` callback shaped exactly
# like HyperliquidBase's private$.request -- `.req_fn(payload, .parser)` -- so it
# works identically for the R6 method and the standalone backfill, in both sync
# and async modes.

#' Combine Segmented Candle Results
#'
#' `rbindlist` of the per-segment tables, deduplicated on the open-time
#' `datetime` (the 1-candle overlap between adjacent segments repeats a candle),
#' sorted ascending.
#'
#' @param results_list List of [data.table::data.table]s, one per segment.
#' @return One [data.table::data.table], deduplicated and ascending by
#'   `datetime`. Empty input yields a zero-row table.
#' @keywords internal
#' @noRd
combine_klines <- function(results_list) {
  dts <- Filter(function(x) nrow(x) > 0L, results_list)
  if (length(dts) == 0L) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(dts)
  dt <- unique(dt, by = "datetime")
  data.table::setorderv(dt, "datetime")
  return(dt[])
}

#' Fetch Hyperliquid Candles over an Arbitrary Time Range
#'
#' Core implementation for fetching OHLCV candles from Hyperliquid's
#' `candleSnapshot` `/info` type. The endpoint returns at most ~5000 candles per
#' call, so the requested `[from, to]` range is segmented into windows of at most
#' `max_candles` candles, each fetched via the supplied `.req_fn`, then
#' deduplicated and sorted.
#'
#' Used by [HyperliquidMarketData]'s candle method and by
#' [hyperliquid_backfill_klines()]; it depends on no R6 instance.
#'
#' @param coin Character; the canonical coin symbol, e.g. `"BTC"`.
#' @param interval Character; one of [HYPERLIQUID_INTERVALS].
#' @param from POSIXct or numeric epoch-milliseconds; range start. Default 24h
#'   ago.
#' @param to POSIXct or numeric epoch-milliseconds; range end. Default now.
#' @param .req_fn Function `(payload, .parser)` returning a
#'   [data.table::data.table] (or a [promises::promise] thereof); performs one
#'   `/info` request through the owning client or a standalone closure.
#' @param is_async Logical; whether `.req_fn` returns promises. Default `FALSE`.
#' @param max_candles Integer; candles per segment (the endpoint cap). Default
#'   `5000L`.
#' @param sleep Numeric; seconds to sleep between segments in sync mode. Default
#'   `0`.
#' @return A [data.table::data.table] of candles sorted ascending by `datetime`,
#'   or a promise thereof.
#'
#' @importFrom lubridate now ddays
#' @keywords internal
#' @noRd
hyperliquid_fetch_klines <- function(
  coin,
  interval,
  from = lubridate::now("UTC") - lubridate::ddays(1),
  to = lubridate::now("UTC"),
  .req_fn,
  is_async = FALSE,
  max_candles = 5000L,
  sleep = 0
) {
  validate_interval(interval)
  interval_seconds <- hyperliquid_interval_to_seconds[[interval]]
  from_ms <- if (is.numeric(from)) floor(from) else datetime_to_ms(from)
  to_ms <- if (is.numeric(to)) floor(to) else datetime_to_ms(to)

  # Split [from, to] into windows of at most max_candles candles, walking
  # forward with a 1-candle overlap so no candle falls in a segment gap; the
  # overlap is removed by combine_klines()'s dedup on datetime.
  window_ms <- max_candles * interval_seconds * 1000
  segments <- list()
  seg_start <- from_ms
  while (seg_start < to_ms) {
    seg_end <- min(seg_start + window_ms, to_ms)
    segments[[length(segments) + 1L]] <- list(startTime = seg_start, endTime = seg_end)
    # Infinite-loop guard: once a segment reaches `to_ms` there is nothing left
    # to fetch, so break before backing the cursor up by one candle (which on a
    # sub-window range would otherwise re-enter the loop forever).
    if (seg_end >= to_ms) {
      break
    }
    seg_start <- seg_end - interval_seconds * 1000
  }

  if (length(segments) == 0L) {
    return(data.table::data.table()[])
  }

  fetch_segment <- function(seg) {
    payload <- list(
      type = "candleSnapshot",
      req = list(
        coin = coin,
        interval = interval,
        startTime = seg$startTime,
        endTime = seg$endTime
      )
    )
    return(.req_fn(payload, parse_candles))
  }

  # Async: build a sequential promise chain over the segments (one at a time to
  # respect rate limits).
  # NOTE: Reduce() is used instead of a for-loop because R closures capture
  # variables by reference (lazy evaluation). A for-loop closure over `seg`
  # would resolve every promise using the LAST segment's value. Reduce() passes
  # `seg` as a function argument, forcing eager evaluation per iteration.
  if (is_async) {
    seed <- promises::promise_resolve(list())
    chain <- Reduce(
      function(acc_promise, seg) {
        return(promises::then(acc_promise, function(acc) {
          return(promises::then(fetch_segment(seg), function(result) {
            return(c(acc, list(result)))
          }))
        }))
      },
      segments,
      accumulate = FALSE,
      init = seed
    )
    return(promises::then(chain, combine_klines))
  }

  # Sync: sequential with optional sleep between segments.
  all_results <- vector("list", length(segments))
  for (i in seq_along(segments)) {
    all_results[[i]] <- fetch_segment(segments[[i]])
    if (i < length(segments) && sleep > 0) {
      Sys.sleep(sleep)
    }
  }
  return(combine_klines(all_results))
}
