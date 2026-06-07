# File: R/backfill.R
# Standalone, instance-free batch backfill to CSV: OHLCV candles across
# symbols x intervals, and complete funding-rate history. Both append
# incrementally (progress survives interruption) and resume from an existing
# file, continuing each series from its last stored row.

#' Backfill Hyperliquid Candle (OHLCV) Data to CSV
#'
#' Downloads historical OHLCV candles for one or more coins and intervals,
#' writing results incrementally to a CSV file. Supports resuming a partially
#' completed backfill by reading the existing file and continuing each
#' `(symbol, interval)` series from its last stored candle.
#'
#' Hyperliquid's `candleSnapshot` returns only the ~5000 most recent candles per
#' interval, so deep intraday history is not available over REST; coarse
#' intervals (`"1d"`, `"1h"`) reach back furthest. Within that cap
#' `hyperliquid_fetch_klines()` segments the range automatically.
#'
#' @param symbols (character) canonical coin symbols (e.g. `c("BTC", "ETH")`).
#'   Must not be NULL or empty.
#' @param intervals (character in HYPERLIQUID_INTERVALS) candle intervals (e.g.
#'   `c("1d", "1h")`). Each must be one of [HYPERLIQUID_INTERVALS]. Default
#'   `"1d"`.
#' @param from (POSIXct | numeric) start of the backfill window. Defaults to one
#'   year ago.
#' @param to (POSIXct | numeric) end of the window. Defaults to the current
#'   time.
#' @param file (scalar<character>) path to the output CSV. Data is appended
#'   incrementally.
#' @param testnet (scalar<logical>) target testnet instead of mainnet. Default
#'   `FALSE`.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between each
#'   `(symbol, interval)` combination to respect rate limits. Default `0.3`.
#' @param verbose (scalar<logical>) if `TRUE`, prints progress via
#'   [rlang::inform()].
#'
#' @return (scalar<character>) the file path (invisibly). Output columns:
#'   `symbol`, `interval`, `datetime`, `open`, `high`, `low`, `close`, `volume`,
#'   `trades`.
#'
#'   Per-combo failures are surfaced as warnings during the run (one
#'   [rlang::warn()] per failed `(symbol, interval)` pair), followed by a final
#'   summary warning if any failed. No failure data is hidden on the return
#'   value.
#'
#' @importFrom lubridate as_datetime now ddays
#' @importFrom rlang abort inform warn
#' @importFrom httr2 req_perform
#' @export
#'
#' @examples
#' \dontrun{
#' hyperliquid_backfill_klines(
#'   symbols = c("BTC", "ETH"),
#'   intervals = c("1d", "1h"),
#'   from = lubridate::as_datetime("2024-01-01"),
#'   file = "hyperliquid_klines.csv"
#' )
#' }
hyperliquid_backfill_klines <- function(
  symbols,
  intervals = "1d",
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file = "hyperliquid_klines.csv",
  testnet = FALSE,
  sleep = 0.3,
  verbose = TRUE
) {
  if (is.null(symbols) || length(symbols) == 0L) {
    rlang::abort("`symbols` must be a non-empty character vector of coins.")
  }
  for (intv in intervals) {
    validate_interval(intv)
  }
  assert_args_hyperliquid_backfill_klines(
    symbols,
    intervals,
    from,
    to,
    file,
    testnet,
    sleep,
    verbose
  )
  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")

  out_cols <- c(
    "symbol",
    "interval",
    "datetime",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "trades"
  )

  # Resume support: read the existing file, refuse to append onto a mismatched
  # schema, and continue each (symbol, interval) from its last stored candle.
  resume <- NULL
  if (file.exists(file)) {
    existing <- tryCatch(data.table::fread(file), error = function(e) NULL)
    if (!is.null(existing) && nrow(existing) > 0L) {
      if (!identical(names(existing), out_cols)) {
        rlang::abort(paste0(
          "Output file '",
          file,
          "' has columns (",
          paste(names(existing), collapse = ", "),
          ") that differ from the expected (",
          paste(out_cols, collapse = ", "),
          "). Refusing to append; remove or fix the file."
        ))
      }
      existing[, datetime := lubridate::as_datetime(datetime, tz = "UTC")]
      resume <- existing[, list(last_dt = max(datetime)), by = list(symbol, interval)]
    }
  }

  # Instance-free sync request closure over the single request funnel.
  base_url <- get_base_url(testnet = testnet)
  req_fn <- function(payload, .parser = identity) {
    return(hyperliquid_build_request(
      base_url = base_url,
      path = "/info",
      body = payload,
      .perform = httr2::req_perform,
      .parser = .parser,
      is_async = FALSE
    ))
  }

  combos <- expand.grid(symbol = symbols, interval = intervals, stringsAsFactors = FALSE)
  total <- nrow(combos)
  failures <- character(0)
  wrote_any <- !is.null(resume)

  for (i in seq_len(total)) {
    sym <- combos$symbol[i]
    intv <- combos$interval[i]

    combo_from <- from
    last_dt <- NULL
    if (!is.null(resume)) {
      match_row <- resume[symbol == sym & interval == intv]
      if (nrow(match_row) > 0L) {
        last_dt <- match_row$last_dt[1L]
        if (last_dt >= to) {
          if (verbose) {
            rlang::inform(sprintf("[%d/%d] %s %s: skipped (already up to date)", i, total, sym, intv))
          }
          next
        }
        combo_from <- last_dt
      }
    }

    dt <- tryCatch(
      hyperliquid_fetch_klines(
        coin = sym,
        interval = intv,
        from = combo_from,
        to = to,
        .req_fn = req_fn,
        is_async = FALSE
      ),
      error = function(e) {
        failures[[length(failures) + 1L]] <<- sprintf("%s/%s", sym, intv)
        rlang::warn(sprintf("[%d/%d] %s %s: FAILED - %s", i, total, sym, intv, conditionMessage(e)))
        return(NULL)
      }
    )

    # Drop the boundary candle already stored on resume.
    if (!is.null(dt) && nrow(dt) > 0L && !is.null(last_dt)) {
      dt <- dt[datetime > last_dt]
    }

    if (!is.null(dt) && nrow(dt) > 0L) {
      dt[, symbol := sym]
      dt[, interval := intv]
      out <- dt[, ..out_cols]
      data.table::fwrite(out, file, append = wrote_any)
      wrote_any <- TRUE
      if (verbose) {
        msg <- sprintf("[%d/%d] %s %s: %d rows", i, total, sym, intv, nrow(out))
        if (!is.null(last_dt)) {
          msg <- paste0(msg, sprintf(" (resumed from %s)", format(last_dt, "%Y-%m-%d")))
        }
        rlang::inform(msg)
      }
    } else if (!is.null(dt) && verbose) {
      rlang::inform(sprintf("[%d/%d] %s %s: 0 rows", i, total, sym, intv))
    }

    if (i < total && sleep > 0) {
      Sys.sleep(sleep)
    }
  }

  if (length(failures) > 0L) {
    rlang::warn(sprintf(
      "hyperliquid_backfill_klines: %d of %d (symbol, interval) combinations failed: %s",
      length(failures),
      total,
      paste(failures, collapse = ", ")
    ))
  }

  return(invisible(assert_return_hyperliquid_backfill_klines(file)))
}

#' Walk `fundingHistory` Forward over a Time Range
#'
#' `fundingHistory` is complete and free on Hyperliquid but returns at most
#' `page_limit` records per call starting at `startTime`. This walks `startTime`
#' forward (each call begins just after the last record returned) until a short
#' page signals the end of available data or the cursor reaches `to`, then
#' deduplicates on `time` and sorts ascending.
#'
#' @param coin (scalar<character>) the canonical coin symbol, e.g. `"BTC"`.
#' @param from (POSIXct | numeric) range start (POSIXct or numeric
#'   epoch-milliseconds).
#' @param to (POSIXct | numeric) range end (POSIXct or numeric
#'   epoch-milliseconds).
#' @param .req_fn (function) `(payload, .parser)` performing one `/info`
#'   request.
#' @param page_limit (scalar<integer in [1, Inf[>) records per page (the
#'   endpoint cap). Default `500L`.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between pages.
#'   Default `0`.
#' @return (FundingHistory) a [data.table::data.table] with columns `coin`,
#'   `funding_rate`, `premium`, `time`, ascending by `time`.
#'
#' @keywords internal
#' @noRd
hyperliquid_fetch_funding <- function(coin, from, to, .req_fn, page_limit = 500L, sleep = 0) {
  validate_coin(coin)
  assert_args_hyperliquid_fetch_funding(coin, from, to, .req_fn, page_limit, sleep)
  from_ms <- if (is.numeric(from)) floor(from) else datetime_to_ms(from)
  to_ms <- if (is.numeric(to)) floor(to) else datetime_to_ms(to)

  acc <- list()
  cursor <- from_ms
  # Infinite-loop guard: the cursor must strictly advance each page; if a page
  # does not move max(time) past `cursor`, stop rather than re-request it.
  repeat {
    payload <- list(type = "fundingHistory", coin = coin, startTime = cursor, endTime = to_ms)
    dt <- .req_fn(payload, parse_funding_history)
    if (is.null(dt) || nrow(dt) == 0L) {
      break
    }
    acc[[length(acc) + 1L]] <- dt
    last_ms <- datetime_to_ms(max(dt$time))
    if (nrow(dt) < page_limit || last_ms <= cursor || last_ms >= to_ms) {
      break
    }
    cursor <- last_ms + 1
    if (sleep > 0) {
      Sys.sleep(sleep)
    }
  }

  if (length(acc) == 0L) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(acc)
  dt <- unique(dt, by = "time")
  data.table::setorderv(dt, "time")
  return(dt[])
}

#' Backfill Hyperliquid Funding-Rate History to CSV
#'
#' Downloads the funding-rate history for one or more coins, writing results
#' incrementally to a CSV file. Unlike candles, Hyperliquid's `fundingHistory` is
#' complete and free, so this walks the full window in `page_limit`-sized time
#' steps. Supports resuming by reading the existing file and continuing each coin
#' from its last stored funding record.
#'
#' @param symbols (character) canonical coin symbols (e.g. `c("BTC", "ETH")`).
#'   Must not be NULL or empty.
#' @param from (POSIXct | numeric) start of the backfill window. Defaults to one
#'   year ago.
#' @param to (POSIXct | numeric) end of the window. Defaults to the current
#'   time.
#' @param file (scalar<character>) path to the output CSV. Data is appended
#'   incrementally.
#' @param testnet (scalar<logical>) target testnet instead of mainnet. Default
#'   `FALSE`.
#' @param sleep (scalar<numeric in [0, Inf[>) seconds to sleep between pages and
#'   between coins to respect rate limits. Default `0.3`.
#' @param verbose (scalar<logical>) if `TRUE`, prints progress via
#'   [rlang::inform()].
#'
#' @return (scalar<character>) the file path (invisibly). Output columns:
#'   `coin`, `funding_rate`, `premium`, `time`.
#'
#'   Per-coin failures are surfaced as warnings during the run, followed by a
#'   final summary warning if any failed. No failure data is hidden on the
#'   return value.
#'
#' @importFrom lubridate as_datetime now ddays
#' @importFrom rlang abort inform warn
#' @importFrom httr2 req_perform
#' @export
#'
#' @examples
#' \dontrun{
#' hyperliquid_backfill_funding(
#'   symbols = c("BTC", "ETH"),
#'   from = lubridate::as_datetime("2024-01-01"),
#'   file = "hyperliquid_funding.csv"
#' )
#' }
hyperliquid_backfill_funding <- function(
  symbols,
  from = lubridate::now("UTC") - lubridate::ddays(365),
  to = lubridate::now("UTC"),
  file = "hyperliquid_funding.csv",
  testnet = FALSE,
  sleep = 0.3,
  verbose = TRUE
) {
  if (is.null(symbols) || length(symbols) == 0L) {
    rlang::abort("`symbols` must be a non-empty character vector of coins.")
  }
  for (s in symbols) {
    validate_coin(s)
  }
  assert_args_hyperliquid_backfill_funding(
    symbols,
    from,
    to,
    file,
    testnet,
    sleep,
    verbose
  )
  from <- lubridate::as_datetime(from, tz = "UTC")
  to <- lubridate::as_datetime(to, tz = "UTC")

  out_cols <- c("coin", "funding_rate", "premium", "time")

  # Resume support: read the existing file, refuse to append onto a mismatched
  # schema, and continue each coin from its last stored funding record.
  resume <- NULL
  if (file.exists(file)) {
    existing <- tryCatch(data.table::fread(file), error = function(e) NULL)
    if (!is.null(existing) && nrow(existing) > 0L) {
      if (!identical(names(existing), out_cols)) {
        rlang::abort(paste0(
          "Output file '",
          file,
          "' has columns (",
          paste(names(existing), collapse = ", "),
          ") that differ from the expected (",
          paste(out_cols, collapse = ", "),
          "). Refusing to append; remove or fix the file."
        ))
      }
      existing[, time := lubridate::as_datetime(time, tz = "UTC")]
      resume <- existing[, list(last_time = max(time)), by = list(coin)]
    }
  }

  base_url <- get_base_url(testnet = testnet)
  req_fn <- function(payload, .parser = identity) {
    return(hyperliquid_build_request(
      base_url = base_url,
      path = "/info",
      body = payload,
      .perform = httr2::req_perform,
      .parser = .parser,
      is_async = FALSE
    ))
  }

  total <- length(symbols)
  failures <- character(0)
  wrote_any <- !is.null(resume)

  for (i in seq_len(total)) {
    sym <- symbols[[i]]

    combo_from <- from
    last_time <- NULL
    if (!is.null(resume)) {
      match_row <- resume[coin == sym]
      if (nrow(match_row) > 0L) {
        last_time <- match_row$last_time[1L]
        if (last_time >= to) {
          if (verbose) {
            rlang::inform(sprintf("[%d/%d] %s: skipped (already up to date)", i, total, sym))
          }
          next
        }
        combo_from <- last_time
      }
    }

    dt <- tryCatch(
      hyperliquid_fetch_funding(
        coin = sym,
        from = combo_from,
        to = to,
        .req_fn = req_fn,
        sleep = sleep
      ),
      error = function(e) {
        failures[[length(failures) + 1L]] <<- sym
        rlang::warn(sprintf("[%d/%d] %s: FAILED - %s", i, total, sym, conditionMessage(e)))
        return(NULL)
      }
    )

    # Drop the boundary record already stored on resume.
    if (!is.null(dt) && nrow(dt) > 0L && !is.null(last_time)) {
      dt <- dt[time > last_time]
    }

    if (!is.null(dt) && nrow(dt) > 0L) {
      out <- dt[, ..out_cols]
      data.table::fwrite(out, file, append = wrote_any)
      wrote_any <- TRUE
      if (verbose) {
        rlang::inform(sprintf("[%d/%d] %s: %d rows", i, total, sym, nrow(out)))
      }
    } else if (!is.null(dt) && verbose) {
      rlang::inform(sprintf("[%d/%d] %s: 0 rows", i, total, sym))
    }

    if (i < total && sleep > 0) {
      Sys.sleep(sleep)
    }
  }

  if (length(failures) > 0L) {
    rlang::warn(sprintf(
      "hyperliquid_backfill_funding: %d of %d coin(s) failed: %s",
      length(failures),
      total,
      paste(failures, collapse = ", ")
    ))
  }

  return(invisible(assert_return_hyperliquid_backfill_funding(file)))
}
