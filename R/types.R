# File: R/types.R
# Reusable roxyassert `@type` record shapes for the flat data.tables the
# endpoint parsers (R/parse_*.R) emit. Each public client method documents its
# `@return` as `promise<Shape>` (which collapses to the resolved `Shape` for the
# synchronous default), and the contract roclet expands the shape into the
# generated `assert_return_*` helper.
#
# Column types mirror the parsers EXACTLY, not a notional schema: every numeric
# field flows through `num_or_na()` (a double), so size decimals, leverages,
# trade counts and order ids are `numeric`, not `integer`; the only `integer`
# columns are the ones a parser builds with `seq_along()` (`L2Level$level`) or
# `as.integer()` (`StakingSummary$n_pending_withdrawals`). A column is `| NA`
# only where the value is semantically optional (an unset entry/liquidation
# price, a not-yet-resting order id), matching the sibling tradebot-core shapes.

#' Hyperliquid return shapes
#'
#' @description Reusable roxyassert `@type` record shapes for the `data.table`s
#' returned by the Hyperliquid client classes. `@genassert` emits a standalone
#' `assert_type_<Shape>()` validator for each shape and `@exportassert` exports
#' them (alongside this block's `assert_args_*`/`assert_return_*`), so callers
#' and the backtester can validate any value against a Hyperliquid shape as a
#' conformance oracle.
#'
#' Shapes: `PerpMeta`, `Candles`, `L2Level`, `Position`, `MarginSummary`,
#' `Fill`, `OrderResult`, `FundingHistory`, `StakingSummary`, `TransferAck`.
#'
#' @name hyperliquid_shapes
#' @genassert
#' @exportassert
#'
#' @type PerpMeta (data.table) one row per perpetual (from `parse_meta()`):
#' - name (character) the coin symbol.
#' - sz_decimals (numeric) size decimals.
#' - max_leverage (numeric) maximum leverage.
#' - margin_table_id (numeric) margin-table id.
#' - only_isolated (logical | NA) isolated-only flag, `NA` when absent.
#' - is_delisted (logical) whether the perp is delisted.
#' - margin_mode (character | NA) margin mode, `NA` when absent.
#'
#' @type Candles (data.table) one row per OHLCV candle (from `parse_candles()`):
#' - datetime (POSIXct) candle open time.
#' - open (numeric) open price.
#' - high (numeric) high price.
#' - low (numeric) low price.
#' - close (numeric) close price.
#' - volume (numeric) traded volume.
#' - trades (numeric) number of trades.
#' - close_time (POSIXct) candle close time.
#' - interval (character) the interval code.
#' - coin (character) the coin symbol.
#'
#' @type L2Level (data.table) one row per book level (from `parse_l2_book()`):
#' - side (character) `"bid"` or `"ask"`.
#' - level (integer) 1-indexed level within the side.
#' - px (numeric) level price.
#' - sz (numeric) level size.
#' - n (numeric) number of orders at the level.
#'
#' @type Position (data.table) one row per open position (from
#'   `parse_positions()`):
#' - coin (character) the coin symbol.
#' - szi (numeric) signed position size.
#' - entry_px (numeric | NA) average entry price, `NA` when absent.
#' - position_value (numeric) current notional value.
#' - unrealized_pnl (numeric) unrealized profit/loss.
#' - return_on_equity (numeric) return on equity.
#' - leverage_type (character) `"cross"` or `"isolated"`.
#' - leverage_value (numeric) the position leverage.
#' - liquidation_px (numeric | NA) liquidation price, `NA` when none.
#' - margin_used (numeric) collateral locked.
#'
#' @type MarginSummary (data.table) the one-row cross-margin summary (from
#'   `parse_margin_summary()`):
#' - account_value (numeric) overall account value.
#' - total_ntl_pos (numeric) total notional position.
#' - total_raw_usd (numeric) total raw USD.
#' - total_margin_used (numeric) total margin used.
#' - withdrawable (numeric) withdrawable balance.
#' - cross_account_value (numeric) cross account value.
#' - cross_total_ntl_pos (numeric) cross total notional position.
#' - cross_total_raw_usd (numeric) cross total raw USD.
#' - cross_total_margin_used (numeric) cross total margin used.
#'
#' @type Fill (data.table) one row per fill (from `parse_user_fills()`):
#' - coin (character) the coin symbol.
#' - px (numeric) fill price.
#' - sz (numeric) fill size.
#' - side (character) `"buy"` or `"sell"`.
#' - time (POSIXct) fill time.
#' - start_position (numeric) signed position size before the fill.
#' - dir (character) the human-readable direction label.
#' - closed_pnl (numeric) realized pnl on the closing portion.
#' - hash (character) the on-chain hash.
#' - oid (numeric) the order id.
#' - crossed (logical) whether the fill crossed the spread (taker).
#' - fee (numeric) the fee charged.
#' - fee_token (character) the asset the fee was charged in.
#' - tid (numeric) the trade id.
#'
#' @type OrderResult (data.table) one row per submitted order's status (from
#'   `parse_order_statuses()`):
#' - status (character) the status discriminator (`"resting"`, `"filled"`,
#'   `"error"`, ...).
#' - oid (numeric | NA) the order id, `NA` for an error/non-resting status.
#' - total_sz (numeric | NA) total filled size, `NA` unless filled.
#' - avg_px (numeric | NA) average fill price, `NA` unless filled.
#' - error (character | NA) the error message, `NA` on success.
#'
#' @type FundingHistory (data.table) one row per funding sample (from
#'   `parse_funding_history()`):
#' - coin (character) the coin symbol.
#' - funding_rate (numeric) the funding rate.
#' - premium (numeric) the premium.
#' - time (POSIXct) the sample time.
#'
#' @type StakingSummary (data.table) the one-row staking summary (from
#'   `parse_staking_summary()`):
#' - delegated (numeric) staked balance.
#' - undelegated (numeric) free balance.
#' - total_pending_withdrawal (numeric) total pending withdrawal.
#' - n_pending_withdrawals (integer) number of pending withdrawals.
#'
#' @type TransferAck (data.table) the one-row action acknowledgement shared by
#'   every `/exchange` action that returns a bare `{status, response:{type}}`
#'   envelope (transfers, staking delegate, schedule-cancel, leverage/margin
#'   updates, builder-fee approval; from `parse_transfer_ack()` and siblings):
#' - status (character) the action status (e.g. `"ok"`).
#' - response_type (character) the response type discriminator (e.g.
#'   `"default"`).
NULL
