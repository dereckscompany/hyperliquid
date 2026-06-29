# File: R/HyperliquidAccount.R
# User-scoped account client for Hyperliquid. Every method is an unauthenticated
# POST to /info, discriminated by the body `type`, that reads the state and
# history of one account; no signing is involved.

#' HyperliquidAccount: User-Scoped Account Reads
#'
#' ### Purpose
#' Reads the full state and history of one Hyperliquid account from the `/info`
#' endpoint: perp positions and margin summary, spot balances, open orders
#' (plain and frontend-detailed), fills, historical orders, funding and
#' non-funding ledgers, portfolio value/PnL/volume, fee schedule and daily
#' volume, request rate limit, account role, sub-accounts, single-order status,
#' and vault equities. Every method is unauthenticated and needs no wallet key.
#'
#' Inherits from [HyperliquidBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction; in
#' async mode each returns a [promises::promise] resolving to the same
#' [data.table::data.table].
#'
#' ### Default address
#' Every read defaults `address` to the instance's acting address (vault, then
#' master account, then the key's own wallet). Pass `address` explicitly to
#' inspect any other account.
#'
#' ### Official Documentation
#' <https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint/perpetuals>
#'
#' ### Endpoints Covered
#' | Method | type | Auth |
#' |--------|------|------|
#' | get_positions | clearinghouseState | No |
#' | get_margin_summary | clearinghouseState | No |
#' | get_spot_balances | spotClearinghouseState | No |
#' | get_open_orders | openOrders | No |
#' | get_frontend_open_orders | frontendOpenOrders | No |
#' | get_user_fills | userFills | No |
#' | get_user_fills_by_time | userFillsByTime | No |
#' | get_historical_orders | historicalOrders | No |
#' | get_user_funding | userFunding | No |
#' | get_user_non_funding_ledger_updates | userNonFundingLedgerUpdates | No |
#' | get_portfolio | portfolio | No |
#' | get_portfolio_volume | portfolio | No |
#' | get_user_fees | userFees | No |
#' | get_user_volume | userFees | No |
#' | get_user_rate_limit | userRateLimit | No |
#' | get_user_role | userRole | No |
#' | get_sub_accounts | subAccounts | No |
#' | get_order_status | orderStatus | No |
#' | get_user_vault_equities | userVaultEquities | No |
#'
#' @examples
#' \dontrun{
#' account <- HyperliquidAccount$new()
#' addr <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"
#' account$get_positions(addr)
#' account$get_margin_summary(addr)
#' account$get_user_fills_by_time(addr, start = lubridate::now("UTC") - lubridate::days(1))
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
HyperliquidAccount <- R6::R6Class(
  "HyperliquidAccount",
  inherit = HyperliquidBase,
  public = list(
    #' @description Retrieve the account's open perpetual positions, one row per
    #'   position.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<Position>) a [data.table::data.table] with `coin`, `szi`,
    #'   `entry_px`, `position_value`, `unrealized_pnl`, `return_on_equity`,
    #'   `leverage_type`, `leverage_value`, `liquidation_px`, `margin_used`, or a
    #'   promise thereof.
    get_positions = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_positions(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "clearinghouseState", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_positions(parse_positions(x))
      ))
    },

    #' @description Retrieve the account's cross-margin summary. Sibling of
    #'   [get_positions()][HyperliquidAccount], which parses the positions from the same payload.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<MarginSummary>) a single-row [data.table::data.table]
    #'   with `account_value`, `total_ntl_pos`, `total_raw_usd`,
    #'   `total_margin_used`, `withdrawable`, `cross_account_value`,
    #'   `cross_total_ntl_pos`, `cross_total_raw_usd`, `cross_total_margin_used`,
    #'   or a promise thereof.
    get_margin_summary = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_margin_summary(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "clearinghouseState", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_margin_summary(parse_margin_summary(x))
      ))
    },

    #' @description Retrieve the account's spot token balances, one row per
    #'   balance.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per spot
    #'   balance (or a promise thereof):
    #'   - coin (character) the token symbol.
    #'   - total (numeric) the total balance.
    #'   - hold (numeric) the held (non-withdrawable) balance.
    #'   - entry_ntl (numeric) the entry notional (cost basis).
    get_spot_balances = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_spot_balances(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "spotClearinghouseState", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_spot_balances(parse_spot_balances(x))
      ))
    },

    #' @description Retrieve the account's resting orders, one row per order.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   resting order (or a promise thereof):
    #'   - coin (character) the coin symbol.
    #'   - oid (numeric) the order id.
    #'   - side (character) the order side (`"buy"` or `"sell"`).
    #'   - limit_px (numeric) the limit price.
    #'   - sz (numeric) the remaining size.
    #'   - timestamp (POSIXct) the order's placement time.
    get_open_orders = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_open_orders(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "openOrders", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_open_orders(parse_open_orders(x))
      ))
    },

    #' @description Retrieve the account's resting orders with the frontend's
    #'   richer detail (order type, trigger fields, reduce-only, tif). Sibling of
    #'   [get_open_orders()][HyperliquidAccount] with more columns.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   resting order (or a promise thereof):
    #'   - coin (character) the coin symbol.
    #'   - oid (numeric) the order id.
    #'   - side (character) the order side (`"buy"` or `"sell"`).
    #'   - limit_px (numeric) the limit price.
    #'   - sz (numeric) the remaining size.
    #'   - timestamp (POSIXct) the order's placement time.
    #'   - order_type (character) the order type, e.g. `"Limit"`.
    #'   - is_trigger (logical) whether the order is a trigger order.
    #'   - trigger_px (numeric) the trigger price (`0` when not a trigger).
    #'   - trigger_condition (character) the trigger condition (`"N/A"` when
    #'     not a trigger).
    #'   - reduce_only (logical) whether the order is reduce-only.
    #'   - tif (character | NA) the time-in-force, `NA` when not applicable.
    #'   - orig_sz (numeric) the original (pre-fill) size.
    #'   - is_position_tpsl (logical) whether the order is a position TP/SL.
    get_frontend_open_orders = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_frontend_open_orders(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "frontendOpenOrders", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_frontend_open_orders(parse_frontend_open_orders(x))
      ))
    },

    #' @description Retrieve the account's most recent fills (retention is the
    #'   ~10,000 most-recent fills).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<Fill>) a [data.table::data.table] with `coin`, `px`,
    #'   `sz`, `side`, `time`, `start_position`, `dir`, `closed_pnl`, `hash`,
    #'   `oid`, `crossed`, `fee`, `fee_token`, `tid`, or a promise thereof.
    get_user_fills = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_fills(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userFills", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_fills(parse_user_fills(x))
      ))
    },

    #' @description Retrieve the account's fills within a time range (up to 2,000
    #'   per call), same shape as [get_user_fills()][HyperliquidAccount].
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @param start (POSIXct | numeric) range start (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @param end (POSIXct | numeric | NULL) range end (POSIXct, numeric
    #'   epoch-milliseconds, or `NULL`). Default `NULL` (up to now).
    #' @param aggregate_by_time (scalar<logical>) if `TRUE`, partial fills of one
    #'   order at the same time are aggregated. Default `FALSE`.
    #' @return (promise<Fill>) a [data.table::data.table] with the same columns as
    #'   [get_user_fills()][HyperliquidAccount], or a promise thereof.
    get_user_fills_by_time = function(
      address = private$.acting_address(),
      start,
      end = NULL,
      aggregate_by_time = FALSE
    ) {
      assert_args_HyperliquidAccount__get_user_fills_by_time(address, start, end, aggregate_by_time)
      address <- validate_address(address)
      payload <- list(
        type = "userFillsByTime",
        user = address,
        startTime = if (is.numeric(start)) floor(start) else datetime_to_ms(start),
        aggregateByTime = aggregate_by_time
      )
      if (!is.null(end)) {
        payload$endTime <- if (is.numeric(end)) floor(end) else datetime_to_ms(end)
      }
      return(private$.info(
        payload,
        .parser = function(x) assert_return_HyperliquidAccount__get_user_fills_by_time(parse_user_fills(x))
      ))
    },

    #' @description Retrieve the account's historical orders, one row per status
    #'   transition (the same `oid` recurs across its lifecycle; not deduplicated).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   status transition (or a promise thereof):
    #'   - oid (numeric) the order id.
    #'   - coin (character) the coin symbol.
    #'   - side (character) the order side (`"buy"` or `"sell"`).
    #'   - limit_px (numeric) the limit price.
    #'   - sz (numeric) the remaining size.
    #'   - orig_sz (numeric) the original (pre-fill) size.
    #'   - order_type (character) the order type, e.g. `"Limit"`.
    #'   - tif (character | NA) the time-in-force, `NA` when not applicable.
    #'   - reduce_only (logical) whether the order is reduce-only.
    #'   - trigger_px (numeric) the trigger price (`0` when not a trigger).
    #'   - trigger_condition (character) the trigger condition (`"N/A"` when
    #'     not a trigger).
    #'   - is_trigger (logical) whether the order is a trigger order.
    #'   - is_position_tpsl (logical) whether the order is a position TP/SL.
    #'   - cloid (character | NA) the client order id, `NA` when none.
    #'   - timestamp (POSIXct) the order's placement time.
    #'   - status (character) the transition status, e.g. `"open"`, `"filled"`,
    #'     `"canceled"`.
    #'   - status_timestamp (POSIXct) the time of the status transition.
    get_historical_orders = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_historical_orders(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "historicalOrders", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_historical_orders(parse_historical_orders(x))
      ))
    },

    #' @description Retrieve the account's funding-payment history within a time
    #'   range, one row per payment.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @param start (POSIXct | numeric) range start (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @param end (POSIXct | numeric | NULL) range end (POSIXct, numeric
    #'   epoch-milliseconds, or `NULL`). Default `NULL` (up to now).
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   funding payment (or a promise thereof):
    #'   - time (POSIXct) the payment time.
    #'   - hash (character) the on-chain hash.
    #'   - coin (character) the coin symbol.
    #'   - funding_rate (numeric) the funding rate applied.
    #'   - szi (numeric) the signed position size at the sample.
    #'   - usdc (numeric) the USDC amount paid or received.
    #'   - n_samples (numeric) the number of samples in the payment.
    get_user_funding = function(address = private$.acting_address(), start, end = NULL) {
      assert_args_HyperliquidAccount__get_user_funding(address, start, end)
      address <- validate_address(address)
      payload <- list(
        type = "userFunding",
        user = address,
        startTime = if (is.numeric(start)) floor(start) else datetime_to_ms(start)
      )
      if (!is.null(end)) {
        payload$endTime <- if (is.numeric(end)) floor(end) else datetime_to_ms(end)
      }
      return(private$.info(
        payload,
        .parser = function(x) assert_return_HyperliquidAccount__get_user_funding(parse_user_funding(x))
      ))
    },

    #' @description Retrieve the account's non-funding ledger updates
    #'   (deposits, withdrawals, transfers, liquidations) within a time range.
    #'   Heterogeneous events stack with a `delta_type` discriminator.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @param start (POSIXct | numeric) range start (POSIXct or numeric
    #'   epoch-milliseconds).
    #' @param end (POSIXct | numeric | NULL) range end (POSIXct, numeric
    #'   epoch-milliseconds, or `NULL`). Default `NULL` (up to now).
    #' @return (promise<data.table>) a [data.table::data.table] led by `time`,
    #'   `hash`, `delta_type`, `usdc`, then the union of the variants' fields, or
    #'   a promise thereof.
    get_user_non_funding_ledger_updates = function(
      address = private$.acting_address(),
      start,
      end = NULL
    ) {
      assert_args_HyperliquidAccount__get_user_non_funding_ledger_updates(address, start, end)
      address <- validate_address(address)
      payload <- list(
        type = "userNonFundingLedgerUpdates",
        user = address,
        startTime = if (is.numeric(start)) floor(start) else datetime_to_ms(start)
      )
      if (!is.null(end)) {
        payload$endTime <- if (is.numeric(end)) floor(end) else datetime_to_ms(end)
      }
      return(private$.info(
        payload,
        .parser = function(x) {
          return(assert_return_HyperliquidAccount__get_user_non_funding_ledger_updates(parse_non_funding_ledger(x)))
        }
      ))
    },

    #' @description Retrieve the account's portfolio value and PnL history, long:
    #'   one row per (period, metric, point).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   (period, metric, point) (or a promise thereof):
    #'   - period (character) the period, e.g. `"day"`, `"perpAllTime"`.
    #'   - metric (character) the metric (`"account_value"` or `"pnl"`).
    #'   - time (POSIXct) the sample time.
    #'   - value (numeric) the sampled value.
    get_portfolio = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_portfolio(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "portfolio", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_portfolio(parse_portfolio(x))
      ))
    },

    #' @description Retrieve the account's per-period traded volume. Sibling of
    #'   [get_portfolio()][HyperliquidAccount] over the same payload.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   period (or a promise thereof):
    #'   - period (character) the period, e.g. `"day"`, `"perpAllTime"`.
    #'   - vlm (numeric) the traded volume for the period.
    get_portfolio_volume = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_portfolio_volume(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "portfolio", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_portfolio_volume(parse_portfolio_volume(x))
      ))
    },

    #' @description Retrieve the account's current fee schedule.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a single-row [data.table::data.table] (or a
    #'   promise thereof):
    #'   - user_add_rate (numeric) the maker (add-liquidity) fee rate.
    #'   - user_cross_rate (numeric) the taker (crossing) fee rate.
    #'   - active_referral_discount (numeric) the active referral discount.
    get_user_fees = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_fees(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userFees", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_fees(parse_user_fees(x))
      ))
    },

    #' @description Retrieve the account's daily traded volume. Sibling of
    #'   [get_user_fees()][HyperliquidAccount] over the same payload.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per day
    #'   (or a promise thereof):
    #'   - date (character) the calendar day (`YYYY-MM-DD`).
    #'   - exchange (numeric) the exchange-wide volume that day.
    #'   - user_add (numeric) the user's maker (add) volume that day.
    #'   - user_cross (numeric) the user's taker (crossing) volume that day.
    get_user_volume = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_volume(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userFees", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_volume(parse_user_volume(x))
      ))
    },

    #' @description Retrieve the account's current request rate-limit state.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a single-row [data.table::data.table] (or a
    #'   promise thereof):
    #'   - cum_vlm (numeric) the cumulative traded volume.
    #'   - n_requests_used (numeric) the number of requests used.
    #'   - n_requests_cap (numeric) the request cap.
    get_user_rate_limit = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_rate_limit(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userRateLimit", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_rate_limit(parse_user_rate_limit(x))
      ))
    },

    #' @description Retrieve the account's role (e.g. `"user"`, `"vault"`,
    #'   `"agent"`, `"subAccount"`).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a single-row [data.table::data.table] (or a
    #'   promise thereof):
    #'   - role (character) the account role, e.g. `"user"`, `"vault"`,
    #'     `"agent"`, `"subAccount"`.
    get_user_role = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_role(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userRole", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_role(parse_user_role(x))
      ))
    },

    #' @description Retrieve the account's sub-accounts (returns a zero-row table
    #'   when the account has none).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   sub-account (or a promise thereof):
    #'   - name (character) the sub-account name.
    #'   - sub_account_user (character) the sub-account's `0x` address.
    #'   - master (character) the master account's `0x` address.
    #'   - account_value (numeric) the sub-account's account value.
    #'   - total_ntl_pos (numeric) the total notional position.
    #'   - total_raw_usd (numeric) the total raw USD.
    #'   - total_margin_used (numeric) the total margin used.
    #'   - withdrawable (numeric) the withdrawable balance.
    get_sub_accounts = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_sub_accounts(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "subAccounts", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_sub_accounts(parse_sub_accounts(x))
      ))
    },

    #' @description Retrieve the status of a single order by its order id or
    #'   client order id.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @param oid_or_cloid (scalar<numeric> | scalar<character>) numeric order
    #'   id, or character `0x`-prefixed client order id (cloid).
    #' @return (promise<data.table>) a single-row [data.table::data.table] (or a
    #'   promise thereof). When the order is not found (`query_status` is
    #'   `"unknownOid"`) every order column is `NA`:
    #'   - query_status (character) the lookup status (`"order"` or
    #'     `"unknownOid"`).
    #'   - oid (numeric | NA) the order id.
    #'   - coin (character | NA) the coin symbol.
    #'   - side (character | NA) the order side (`"buy"` or `"sell"`).
    #'   - limit_px (numeric | NA) the limit price.
    #'   - sz (numeric | NA) the remaining size.
    #'   - orig_sz (numeric | NA) the original (pre-fill) size.
    #'   - order_type (character | NA) the order type, e.g. `"Limit"`.
    #'   - tif (character | NA) the time-in-force.
    #'   - reduce_only (logical | NA) whether the order is reduce-only.
    #'   - trigger_px (numeric | NA) the trigger price.
    #'   - trigger_condition (character | NA) the trigger condition.
    #'   - is_trigger (logical | NA) whether the order is a trigger order.
    #'   - is_position_tpsl (logical | NA) whether the order is a position TP/SL.
    #'   - cloid (character | NA) the client order id.
    #'   - timestamp (POSIXct | NA) the order's placement time.
    #'   - status (character | NA) the order's status, e.g. `"open"`,
    #'     `"filled"`, `"canceled"`.
    #'   - status_timestamp (POSIXct | NA) the time of the status.
    get_order_status = function(address = private$.acting_address(), oid_or_cloid) {
      assert_args_HyperliquidAccount__get_order_status(address, oid_or_cloid)
      address <- validate_address(address)
      return(private$.info(
        list(type = "orderStatus", user = address, oid = oid_or_cloid),
        .parser = function(x) assert_return_HyperliquidAccount__get_order_status(parse_order_status(x))
      ))
    },

    #' @description Retrieve the account's equity in each vault it has deposited
    #'   into, one row per vault.
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table], one row per vault
    #'   (or a promise thereof):
    #'   - vault_address (character) the vault's `0x` address.
    #'   - equity (numeric) the user's equity in the vault.
    #'   - locked_until_timestamp (POSIXct) when the equity unlocks.
    get_user_vault_equities = function(address = private$.acting_address()) {
      assert_args_HyperliquidAccount__get_user_vault_equities(address)
      address <- validate_address(address)
      return(private$.info(
        list(type = "userVaultEquities", user = address),
        .parser = function(x) assert_return_HyperliquidAccount__get_user_vault_equities(parse_user_vault_equities(x))
      ))
    }
  )
)
