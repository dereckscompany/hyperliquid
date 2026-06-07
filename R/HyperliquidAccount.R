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
    #' @return (promise<data.table>) a [data.table::data.table] with `coin`,
    #'   `total`, `hold`, `entry_ntl`, or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `coin`,
    #'   `oid`, `side`, `limit_px`, `sz`, `timestamp`, or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `coin`,
    #'   `oid`, `side`, `limit_px`, `sz`, `timestamp`, `order_type`,
    #'   `is_trigger`, `trigger_px`, `trigger_condition`, `reduce_only`, `tif`,
    #'   `orig_sz`, `is_position_tpsl`, or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `oid`,
    #'   `coin`, `side`, `limit_px`, `sz`, `orig_sz`, `order_type`, `tif`,
    #'   `reduce_only`, `trigger_px`, `trigger_condition`, `is_trigger`,
    #'   `is_position_tpsl`, `cloid`, `timestamp`, `status`, `status_timestamp`,
    #'   or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `time`,
    #'   `hash`, `coin`, `funding_rate`, `szi`, `usdc`, `n_samples`, or a promise
    #'   thereof.
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
          assert_return_HyperliquidAccount__get_user_non_funding_ledger_updates(parse_non_funding_ledger(x))
        }
      ))
    },

    #' @description Retrieve the account's portfolio value and PnL history, long:
    #'   one row per (period, metric, point).
    #' @param address (scalar<character>) the account's `0x`-prefixed address.
    #'   Defaults to the instance's acting address.
    #' @return (promise<data.table>) a [data.table::data.table] with `period`,
    #'   `metric`, `time`, `value`, or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `period`,
    #'   `vlm`, or a promise thereof.
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
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   `user_add_rate`, `user_cross_rate`, `active_referral_discount`, or a
    #'   promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `date`,
    #'   `exchange`, `user_add`, `user_cross`, or a promise thereof.
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
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   `cum_vlm`, `n_requests_used`, `n_requests_cap`, or a promise thereof.
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
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   `role`, or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with `name`,
    #'   `sub_account_user`, `master`, `account_value`, `total_ntl_pos`,
    #'   `total_raw_usd`, `total_margin_used`, `withdrawable`, or a promise
    #'   thereof.
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
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   `query_status` and the order shape (`oid`, `coin`, `side`, ..., `status`,
    #'   `status_timestamp`), or a promise thereof.
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
    #' @return (promise<data.table>) a [data.table::data.table] with
    #'   `vault_address`, `equity`, `locked_until_timestamp`, or a promise
    #'   thereof.
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
