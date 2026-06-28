# File: R/helpers_parse.R
# Generic response-flattening helpers for the hyperliquid package. They turn the
# raw parsed JSON (numbers as strings, timestamps as epoch milliseconds, nested
# objects, parallel positional arrays, and {time, hash, delta} discriminated
# ledgers) into flat, list-column-free data.tables. Endpoint-specific parsers
# (built next) compose these.

#' Return `x`, or `default` When `x` Is NULL
#'
#' A plainly-named, readable null-coalescing helper: it initialises with the
#' default and updates only when `x` is present. Used for the many inline field
#' defaults where an init-then-update statement cannot be written (i.e. inside a
#' `data.table()` call), in place of a `%||%` operator.
#'
#' @param x A value or NULL.
#' @param default The value to use when `x` is NULL.
#' @return `x` when it is non-NULL, otherwise `default`.
#'
#' @examples
#' coalesce_null(NULL, NA_character_)
#' coalesce_null("BTC", NA_character_)
#'
#' @keywords internal
#' @noRd
coalesce_null <- function(x, default) {
  result <- default
  if (!is.null(x)) {
    result <- x
  }
  return(result)
}

#' Coerce a Possibly-NULL Numeric-String Scalar to Numeric
#'
#' Hyperliquid returns nearly every number as a JSON string. This parses one to
#' a numeric, mapping NULL, an empty string, or a zero-length value to
#' `NA_real_`.
#'
#' @param x A scalar (string or number) or NULL.
#' @return Numeric scalar, or `NA_real_` when absent/blank.
#'
#' @examples
#' num_or_na("123.45")
#' num_or_na("")
#' num_or_na(NULL)
#'
#' @keywords internal
#' @noRd
num_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_real_)
  }
  if (is.character(x) && !nzchar(x)) {
    return(NA_real_)
  }
  return(suppressWarnings(as.numeric(x)))
}

#' Coerce a Possibly-NULL Scalar to Character
#'
#' @param x A scalar or NULL.
#' @return Character scalar, or `NA_character_` when NULL/zero-length.
#'
#' @examples
#' chr_or_na("0xabc")
#' chr_or_na(NULL)
#'
#' @keywords internal
#' @noRd
chr_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA_character_)
  }
  return(as.character(x))
}

#' Coerce a Possibly-NULL Scalar to Logical
#'
#' @param x A scalar or NULL.
#' @return Logical scalar, or `NA` when NULL/zero-length.
#'
#' @examples
#' lgl_or_na(TRUE)
#' lgl_or_na(NULL)
#'
#' @keywords internal
#' @noRd
lgl_or_na <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(NA)
  }
  return(as.logical(x))
}

#' Safely Read the i-th Element of a Positional Array as Numeric
#'
#' Hyperliquid returns several structures as positional arrays (e.g.
#' `metaAndAssetCtxs` = `[meta, ctxs]`, `portfolio` = `[[period, data]]`). A
#' short or partial array would make `x[[i]]` raise a subscript error; this
#' returns `NA_real_` instead when the element is missing, NULL, or blank.
#'
#' @param x A list/vector, or NULL.
#' @param i Integer; the element index.
#' @return `as.numeric(x[[i]])`, or `NA_real_` when absent/blank.
#'
#' @examples
#' nth_num(list("1.5", "2.5"), 2L)
#' nth_num(list("1.5"), 5L)
#'
#' @keywords internal
#' @noRd
nth_num <- function(x, i) {
  if (length(x) < i || is.null(x[[i]]) || identical(x[[i]], "")) {
    return(NA_real_)
  }
  return(suppressWarnings(as.numeric(x[[i]])))
}

#' Safely Read the i-th Element of a Positional Array as Character
#'
#' @param x A list/vector, or NULL.
#' @param i Integer; the element index.
#' @return `as.character(x[[i]])`, or `NA_character_` when absent.
#'
#' @examples
#' nth_chr(list("a", "b"), 1L)
#' nth_chr(list("a"), 9L)
#'
#' @keywords internal
#' @noRd
nth_chr <- function(x, i) {
  if (length(x) < i || is.null(x[[i]])) {
    return(NA_character_)
  }
  return(as.character(x[[i]]))
}

#' Convert camelCase Names to snake_case
#'
#' Converts response field names to R's snake_case convention. Hyperliquid
#' fields are predominantly camelCase (`szDecimals`, `marginTableId`), so this
#' lowercases them while inserting underscores at case boundaries. Only the case
#' changes; the field is never otherwise renamed.
#'
#' @param x Character vector; names to convert.
#' @return Character vector; converted snake_case names.
#'
#' @examples
#' to_snake_case(c("szDecimals", "marginTableId", "coin"))
#'
#' @keywords internal
#' @noRd
to_snake_case <- function(x) {
  out <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  out <- gsub("([A-Z])([A-Z][a-z])", "\\1_\\2", out)
  out <- tolower(out)
  return(out)
}

#' Convert a Named List to a Single-Row data.table
#'
#' Converts a flat named list (from a Hyperliquid JSON object) into a single-row
#' [data.table::data.table]. NULL or empty values become `NA`. Any nested
#' object/array or multi-element value is collapsed to a single JSON string, so
#' the result is guaranteed to contain **no list columns** (and never
#' row-recycles) even if the API returns an unexpectedly nested field. Column
#' names are snake_cased.
#'
#' @param x A named list, or NULL.
#' @return A single-row [data.table::data.table] with snake_case column names;
#'   a zero-row data.table when `x` is NULL or empty.
#'
#' @examples
#' as_dt_row(list(coin = "BTC", szDecimals = 5, ctx = list(a = 1, b = 2)))
#'
#' @keywords internal
#' @noRd
as_dt_row <- function(x) {
  if (is.null(x) || length(x) == 0) {
    return(data.table::data.table()[])
  }
  x <- lapply(x, function(val) {
    if (is.null(val)) {
      return(NA)
    }
    if (is.list(val) && length(val) == 0) {
      return(NA)
    }
    # Enforce the no-list-column contract: collapse any nested object/array or
    # multi-element value to a single JSON string rather than a list column.
    if (is.list(val) || length(val) != 1L) {
      return(as.character(jsonlite::toJSON(val, auto_unbox = TRUE, null = "null")))
    }
    return(val)
  })
  dt <- data.table::as.data.table(x)
  data.table::setnames(dt, to_snake_case(names(dt)))
  return(dt[])
}

#' Convert a List of Named Lists to a data.table
#'
#' Row-binds a list whose elements are named lists (a JSON array of objects)
#' into a [data.table::data.table] with snake_case columns, padding absent
#' fields with `NA` (`fill = TRUE`). This is also the discriminator-stacking
#' primitive: heterogeneous rows that each carry a `type`-style field stack into
#' one table with the union of columns.
#'
#' @param items A list of named lists, or NULL.
#' @return A [data.table::data.table]; zero-row if `items` is NULL or empty.
#'
#' @examples
#' as_dt_list(list(list(a = 1, b = 2), list(a = 3, c = 4)))
#'
#' @keywords internal
#' @noRd
as_dt_list <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  dt <- data.table::rbindlist(lapply(items, as_dt_row), fill = TRUE)
  return(dt[])
}

#' Coerce a Set of Known Columns to Numeric In Place
#'
#' Many Hyperliquid numeric fields arrive as strings. After flattening with
#' `as_dt_row()` / `as_dt_list()`, this coerces the named columns (those that
#' are present) to numeric **by reference** with [data.table::set], leaving
#' columns the response did not include untouched.
#'
#' @param dt A [data.table::data.table] (modified in place).
#' @param cols Character vector; the column names to coerce to numeric.
#' @return The same `dt`, invisibly, with the listed columns coerced.
#'
#' @examples
#' dt <- data.table::data.table(px = c("100.5", ""), sz = c("1", "2"))
#' coerce_numeric_cols(dt, c("px", "sz"))
#'
#' @keywords internal
#' @noRd
coerce_numeric_cols <- function(dt, cols) {
  present <- intersect(cols, names(dt))
  for (col in present) {
    data.table::set(dt, j = col, value = suppressWarnings(as.numeric(dt[[col]])))
  }
  return(dt[])
}

#' Parse a {time, hash, delta} Discriminated Ledger into a data.table
#'
#' Hyperliquid ledger endpoints (e.g. `userNonFundingLedgerUpdates`) return one
#' record per update shaped `{time, hash, delta}`, where `delta` is an object
#' whose `type` field discriminates the variant and whose remaining fields
#' differ per variant. This flattens each record to a row carrying the `time`
#' (as a POSIXct), the `hash`, and the delta's fields (including the `type`
#' discriminator), then stacks the heterogeneous rows with `fill = TRUE` so each
#' variant's columns coexist. No deduplication is performed.
#'
#' @param items A list of `{time, hash, delta}` records, or NULL.
#' @return A [data.table::data.table], one row per record; zero-row when empty.
#'   No list columns.
#'
#' @examples
#' parse_delta_ledger(list(
#'   list(time = 1700000000000, hash = "0xabc",
#'        delta = list(type = "deposit", usdc = "100.5"))
#' ))
#'
#' @keywords internal
#' @noRd
parse_delta_ledger <- function(items) {
  if (is.null(items) || length(items) == 0) {
    return(data.table::data.table()[])
  }
  rows <- lapply(items, function(it) {
    meta_dt <- data.table::data.table(
      time = ms_to_datetime(num_or_na(it$time)),
      hash = chr_or_na(it$hash)
    )
    delta_dt <- as_dt_row(it$delta)
    if (nrow(delta_dt) == 0L) {
      return(meta_dt)
    }
    return(cbind(meta_dt, delta_dt))
  })
  return(data.table::rbindlist(rows, fill = TRUE)[])
}

# ---- Typed empty constructors ----
#
# A few endpoint shapes recur across more than one parser or fetcher, so their
# zero-row schema is defined once here and reused. Single-use empty branches
# inline their own typed zero-row schema at the branch instead -- a helper per
# shape would not earn its keep. The schema-agnostic flattening primitives above
# (`as_dt_row()`, `as_dt_list()`, `parse_delta_ledger()`) have no fixed column
# set and return a bare `data.table()`.
#
# Each constructor closes with `[]` so the returned table prints on the first
# call, and timestamp columns use `ms_to_datetime(numeric(0))`, the same coercion
# the parsers apply, so an empty column's class and tz match a populated one.

#' Typed zero-row candle (OHLCV) schema. Shared by `parse_candles()` and the
#' segmented kline fetcher (`combine_klines()` / `hyperliquid_fetch_klines()`).
#' @keywords internal
#' @noRd
#' @noassert
empty_dt_candles <- function() {
  return(data.table::data.table(
    datetime = ms_to_datetime(numeric(0)),
    open = numeric(0),
    high = numeric(0),
    low = numeric(0),
    close = numeric(0),
    volume = numeric(0),
    trades = numeric(0),
    close_time = ms_to_datetime(numeric(0)),
    interval = character(0),
    coin = character(0)
  )[])
}

#' Typed zero-row funding-history schema. Shared by `parse_funding_history()`
#' and the paginated funding backfill (`hyperliquid_fetch_funding()`).
#' @keywords internal
#' @noRd
#' @noassert
empty_dt_funding_history <- function() {
  return(data.table::data.table(
    coin = character(0),
    funding_rate = numeric(0),
    premium = numeric(0),
    time = ms_to_datetime(numeric(0))
  )[])
}
