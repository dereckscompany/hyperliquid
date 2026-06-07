# File: R/HyperliquidStaking.R
# Staking client for Hyperliquid: delegation reads (/info) and the delegate /
# undelegate write (/exchange, user-signed).

#' HyperliquidStaking: Native-Token Staking and Delegation
#'
#' Reads a delegator's staking state and history, and delegates or undelegates
#' the native token to or from a validator. Hyperliquid uses delegated
#' proof-of-stake: stake is delegated to validators, delegations carry a one-day
#' lockup, and rewards accrue every minute and compound daily.
#'
#' Inherits from [HyperliquidBase]. All methods support both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Purpose
#' Surface the staking account: the staked / free balances and pending
#' withdrawals ([get_staking_summary()][HyperliquidStaking]), the active
#' per-validator delegations ([get_staking_delegations()][HyperliquidStaking]),
#' the reward accrual history ([get_staking_rewards()][HyperliquidStaking]), the
#' full delegate/deposit/withdraw event ledger
#' ([get_delegator_history()][HyperliquidStaking]), and the delegate /
#' undelegate action itself ([token_delegate()][HyperliquidStaking]).
#'
#' ### Official Documentation
#' <https://hyperliquid.gitbook.io/hyperliquid-docs/hypercore/staking>
#'
#' ### Default address
#' The read methods default `address` to the instance's acting address
#' (vault, then master account, then the key's own wallet). Pass `address`
#' explicitly to inspect any other delegator.
#'
#' ### Endpoints Covered
#' | Method | type | Auth |
#' |--------|------|------|
#' | get_staking_summary | delegatorSummary | No |
#' | get_staking_delegations | delegations | No |
#' | get_staking_rewards | delegatorRewards | No |
#' | get_delegator_history | delegatorHistory | No |
#' | token_delegate | tokenDelegate | Yes |
#'
#' @examples
#' \dontrun{
#' staking <- HyperliquidStaking$new()
#' staking$get_staking_summary("0x5ac99df645f3414876c816caa18b2d234024b487")
#' staking$get_staking_delegations("0x5ac99df645f3414876c816caa18b2d234024b487")
#'
#' # Delegate 100 wei to a validator (requires a signing key):
#' staking$token_delegate(
#'   validator = "0x5ac99df645f3414876c816caa18b2d234024b487",
#'   wei = 100,
#'   is_undelegate = FALSE
#' )
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
HyperliquidStaking <- R6::R6Class(
  "HyperliquidStaking",
  inherit = HyperliquidBase,
  public = list(
    #' @description Retrieve a delegator's staking summary: the staked and free
    #'   balances, the total pending withdrawal, and the number of pending
    #'   withdrawals.
    #' @param address Character; the delegator's `0x`-prefixed address. Defaults
    #'   to the instance's acting address.
    #' @return A single-row [data.table::data.table] with `delegated`,
    #'   `undelegated`, `total_pending_withdrawal`, `n_pending_withdrawals`, or a
    #'   promise thereof.
    get_staking_summary = function(address = private$.acting_address()) {
      address <- validate_address(address)
      return(private$.info(
        list(type = "delegatorSummary", user = address),
        .parser = parse_staking_summary
      ))
    },

    #' @description Retrieve a delegator's active per-validator delegations.
    #' @param address Character; the delegator's `0x`-prefixed address. Defaults
    #'   to the instance's acting address.
    #' @return A [data.table::data.table] with `validator`, `amount`,
    #'   `locked_until_timestamp`, or a promise thereof.
    get_staking_delegations = function(address = private$.acting_address()) {
      address <- validate_address(address)
      return(private$.info(
        list(type = "delegations", user = address),
        .parser = parse_staking_delegations
      ))
    },

    #' @description Retrieve a delegator's historic staking rewards.
    #' @param address Character; the delegator's `0x`-prefixed address. Defaults
    #'   to the instance's acting address.
    #' @return A [data.table::data.table] with `time`, `source`, `total_amount`,
    #'   or a promise thereof.
    get_staking_rewards = function(address = private$.acting_address()) {
      address <- validate_address(address)
      return(private$.info(
        list(type = "delegatorRewards", user = address),
        .parser = parse_staking_rewards
      ))
    },

    #' @description Retrieve a delegator's comprehensive staking history: the
    #'   delegate / undelegate / deposit / withdraw events. Heterogeneous events
    #'   are stacked with a `delta_type` discriminator.
    #' @param address Character; the delegator's `0x`-prefixed address. Defaults
    #'   to the instance's acting address.
    #' @return A [data.table::data.table] with `time`, `hash`, `delta_type`, and
    #'   the union of the variants' fields (`validator`, `amount`,
    #'   `is_undelegate` where present), or a promise thereof.
    get_delegator_history = function(address = private$.acting_address()) {
      address <- validate_address(address)
      return(private$.info(
        list(type = "delegatorHistory", user = address),
        .parser = parse_delegator_history
      ))
    },

    #' @description Delegate or undelegate native token to or from a validator.
    #'   Delegations carry a one-day lockup; undelegated balances reflect
    #'   instantly. Requires a signing key.
    #' @param validator Character; the validator's `0x`-prefixed address.
    #' @param wei Numeric; the amount in wei -- a finite, strictly-positive whole
    #'   number.
    #' @param is_undelegate Logical; `TRUE` to undelegate (withdraw stake),
    #'   `FALSE` to delegate. Default `FALSE`.
    #' @return A single-row [data.table::data.table] with `status` and
    #'   `response_type`, or a promise thereof.
    token_delegate = function(validator, wei, is_undelegate = FALSE) {
      validator <- validate_address(validator)
      assert::assert_scalar_logical(is_undelegate)
      assert_finite_positive(wei, "wei")
      if (wei != trunc(wei)) {
        rlang::abort(sprintf(
          "`wei` must be a whole number of wei (no fractional part), got: %s",
          format(wei)
        ))
      }
      action <- list(
        validator = validator,
        wei = wei,
        isUndelegate = is_undelegate,
        nonce = next_nonce(),
        type = "tokenDelegate"
      )
      return(private$.submit_user(
        action,
        sign_types = TOKEN_DELEGATE_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:TokenDelegate",
        .parser = parse_token_delegate
      ))
    }
  )
)
