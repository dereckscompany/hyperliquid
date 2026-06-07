# File: R/HyperliquidTransfers.R
# Signed /exchange transfer client: collateral movement, on-chain sends,
# withdrawals, sub-account and vault transfers.

#' HyperliquidTransfers: Collateral Movement, Sends, and Withdrawals
#'
#' ### Purpose
#' Signed `/exchange` actions that move funds: between the spot and perp wallets
#' of one account (`usd_class_transfer`), to another address on Hyperliquid
#' (`usd_send`, `spot_send`, `send_asset`), out to the bridge
#' (`withdraw`), and between an account and its sub-accounts or a vault
#' (`sub_account_transfer`, `sub_account_spot_transfer`, `vault_transfer`). All
#' require a wallet signing key.
#'
#' Inherits from [HyperliquidBase]. Every method supports both synchronous and
#' asynchronous execution depending on the `async` argument at construction.
#'
#' ### Signing
#' Most transfers are **user-signed** actions over the
#' `HyperliquidSignTransaction` EIP-712 domain (each carries its own
#' `time`/`nonce` field, and `vaultAddress` is forced null on the wire). The
#' sub-account and vault transfers are **L1** actions hashed and signed over the
#' Exchange domain. Amounts denominated in USD for sub-account/vault transfers
#' are scaled to micro-USD integers (x1e6) before signing.
#'
#' ### Official Documentation
#' <https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/exchange-endpoint>
#'
#' ### Endpoints Covered
#' | Method | type | Auth |
#' |--------|------|------|
#' | usd_class_transfer | usdClassTransfer | Yes |
#' | usd_send | usdSend | Yes |
#' | spot_send | spotSend | Yes |
#' | withdraw | withdraw3 | Yes |
#' | send_asset | sendAsset | Yes |
#' | sub_account_transfer | subAccountTransfer | Yes |
#' | sub_account_spot_transfer | subAccountSpotTransfer | Yes |
#' | vault_transfer | vaultTransfer | Yes |
#'
#' @examples
#' \dontrun{
#' transfers <- HyperliquidTransfers$new()
#' # Move $100 of collateral from the spot wallet into the perp wallet:
#' transfers$usd_class_transfer(100, to_perp = TRUE)
#' # Send 25 USDC to another address:
#' transfers$usd_send(25, "0x5e9ee1089755c3435139848e47e6635505d5a13a")
#' }
#'
#' @import data.table
#' @export
HyperliquidTransfers <- R6::R6Class(
  "HyperliquidTransfers",
  inherit = HyperliquidBase,
  public = list(
    #' @description Move USDC collateral between the spot and perp wallets of the
    #'   acting account (no on-chain transfer; an internal class switch). When the
    #'   client was constructed with a `vault_address`, the amount string carries
    #'   a `subaccount:<vault>` suffix so the move applies to that sub-account
    #'   (mirrors the reference SDK).
    #' @param amount (scalar<numeric in ]0, Inf[>) the USDC amount to move.
    #' @param to_perp (scalar<logical>) `TRUE` moves spot -> perp, `FALSE` perp ->
    #'   spot.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    usd_class_transfer = function(amount, to_perp) {
      assert_args_HyperliquidTransfers__usd_class_transfer(amount, to_perp)
      nonce <- next_nonce()
      str_amount <- as.character(amount)
      if (!is.null(private$.vault_address)) {
        str_amount <- paste0(str_amount, " subaccount:", private$.vault_address)
      }
      action <- list(
        type = "usdClassTransfer",
        amount = str_amount,
        toPerp = to_perp,
        nonce = nonce
      )
      return(private$.submit_user(
        action,
        sign_types = USD_CLASS_TRANSFER_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:UsdClassTransfer",
        .parser = function(x) {
          assert_return_HyperliquidTransfers__usd_class_transfer(parse_transfer_ack(x))
        }
      ))
    },

    #' @description Send USDC to another address on Hyperliquid (an internal
    #'   transfer, not a bridge withdrawal).
    #' @param amount (scalar<numeric in ]0, Inf[>) the USDC amount to send.
    #' @param destination (scalar<character>) the recipient's 0x-prefixed address.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    usd_send = function(amount, destination) {
      assert_args_HyperliquidTransfers__usd_send(amount, destination)
      destination <- validate_address(destination)
      time <- next_nonce()
      action <- list(
        destination = destination,
        amount = as.character(amount),
        time = time,
        type = "usdSend"
      )
      return(private$.submit_user(
        action,
        sign_types = USD_SEND_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:UsdSend",
        .parser = function(x) {
          assert_return_HyperliquidTransfers__usd_send(parse_transfer_ack(x))
        }
      ))
    },

    #' @description Send a spot token to another address on Hyperliquid.
    #' @param amount (scalar<numeric in ]0, Inf[>) the token amount to send.
    #' @param destination (scalar<character>) the recipient's 0x-prefixed address.
    #' @param token (scalar<character>) the token in `NAME:0x<tokenId>` form, e.g.
    #'   `"PURR:0xc1fb593aeffbeb02f85e0308e9956a90"`.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    spot_send = function(amount, destination, token) {
      assert_args_HyperliquidTransfers__spot_send(amount, destination, token)
      destination <- validate_address(destination)
      private$.validate_token(token)
      time <- next_nonce()
      action <- list(
        destination = destination,
        amount = as.character(amount),
        token = token,
        time = time,
        type = "spotSend"
      )
      return(private$.submit_user(
        action,
        sign_types = SPOT_TRANSFER_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:SpotSend",
        .parser = function(x) {
          assert_return_HyperliquidTransfers__spot_send(parse_transfer_ack(x))
        }
      ))
    },

    #' @description Withdraw USDC from Hyperliquid out to the bridge (an on-chain
    #'   withdrawal to the destination address; a fee applies).
    #' @param amount (scalar<numeric in ]0, Inf[>) the USDC amount to withdraw.
    #' @param destination (scalar<character>) the recipient's 0x-prefixed address.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    withdraw = function(amount, destination) {
      assert_args_HyperliquidTransfers__withdraw(amount, destination)
      destination <- validate_address(destination)
      time <- next_nonce()
      action <- list(
        destination = destination,
        amount = as.character(amount),
        time = time,
        type = "withdraw3"
      )
      return(private$.submit_user(
        action,
        sign_types = WITHDRAW_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:Withdraw",
        .parser = function(x) {
          assert_return_HyperliquidTransfers__withdraw(parse_transfer_ack(x))
        }
      ))
    },

    #' @description Send a token between dexes and/or to another address. For the
    #'   default perp dex use the empty string `""`; for spot use `"spot"`. The
    #'   token must match the collateral token when transferring to or from a perp
    #'   dex. When the client carries a `vault_address` it is sent as the
    #'   `fromSubAccount`.
    #' @param destination (scalar<character>) the recipient's 0x-prefixed address.
    #' @param source_dex (scalar<character>) the source dex name (`""` for the
    #'   default perp dex, `"spot"` for spot).
    #' @param destination_dex (scalar<character>) the destination dex name.
    #' @param token (scalar<character>) the token in `NAME:0x<tokenId>` form.
    #' @param amount (scalar<numeric in ]0, Inf[>) the amount to send.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    send_asset = function(destination, source_dex, destination_dex, token, amount) {
      assert_args_HyperliquidTransfers__send_asset(
        destination, source_dex, destination_dex, token, amount
      )
      destination <- validate_address(destination)
      private$.validate_token(token)
      nonce <- next_nonce()
      action <- list(
        type = "sendAsset",
        destination = destination,
        sourceDex = source_dex,
        destinationDex = destination_dex,
        token = token,
        amount = as.character(amount),
        fromSubAccount = coalesce_null(private$.vault_address, ""),
        nonce = nonce
      )
      return(private$.submit_user(
        action,
        sign_types = SEND_ASSET_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:SendAsset",
        .parser = function(x) {
          assert_return_HyperliquidTransfers__send_asset(parse_transfer_ack(x))
        }
      ))
    },

    #' @description Transfer USDC perp collateral between the acting account and
    #'   one of its sub-accounts (an L1 action). The amount is scaled to a
    #'   micro-USD integer before signing.
    #' @param sub_account_user (scalar<character>) the sub-account's 0x-prefixed
    #'   address.
    #' @param is_deposit (scalar<logical>) `TRUE` deposits into the sub-account,
    #'   `FALSE` withdraws from it.
    #' @param usd (scalar<numeric in ]0, Inf[>) the USD amount.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    sub_account_transfer = function(sub_account_user, is_deposit, usd) {
      assert_args_HyperliquidTransfers__sub_account_transfer(
        sub_account_user, is_deposit, usd
      )
      sub_account_user <- validate_address(sub_account_user)
      action <- list(
        type = "subAccountTransfer",
        subAccountUser = sub_account_user,
        isDeposit = is_deposit,
        usd = float_to_usd_int(usd)
      )
      return(private$.submit_l1(action, .parser = function(x) {
        assert_return_HyperliquidTransfers__sub_account_transfer(parse_transfer_ack(x))
      }))
    },

    #' @description Transfer a spot token between the acting account and one of
    #'   its sub-accounts (an L1 action).
    #' @param sub_account_user (scalar<character>) the sub-account's 0x-prefixed
    #'   address.
    #' @param is_deposit (scalar<logical>) `TRUE` deposits into the sub-account,
    #'   `FALSE` withdraws from it.
    #' @param token (scalar<character>) the token in `NAME:0x<tokenId>` form.
    #' @param amount (scalar<numeric in ]0, Inf[>) the token amount.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    sub_account_spot_transfer = function(sub_account_user, is_deposit, token, amount) {
      assert_args_HyperliquidTransfers__sub_account_spot_transfer(
        sub_account_user, is_deposit, token, amount
      )
      sub_account_user <- validate_address(sub_account_user)
      private$.validate_token(token)
      action <- list(
        type = "subAccountSpotTransfer",
        subAccountUser = sub_account_user,
        isDeposit = is_deposit,
        token = token,
        amount = as.character(amount)
      )
      return(private$.submit_l1(action, .parser = function(x) {
        assert_return_HyperliquidTransfers__sub_account_spot_transfer(parse_transfer_ack(x))
      }))
    },

    #' @description Deposit into or withdraw from a vault (an L1 action). The
    #'   amount is scaled to a micro-USD integer before signing.
    #' @param vault_address (scalar<character>) the vault's 0x-prefixed address.
    #' @param is_deposit (scalar<logical>) `TRUE` deposits into the vault,
    #'   `FALSE` withdraws from it.
    #' @param usd (scalar<numeric in ]0, Inf[>) the USD amount.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    vault_transfer = function(vault_address, is_deposit, usd) {
      assert_args_HyperliquidTransfers__vault_transfer(vault_address, is_deposit, usd)
      vault_address <- validate_address(vault_address)
      action <- list(
        type = "vaultTransfer",
        vaultAddress = vault_address,
        isDeposit = is_deposit,
        usd = float_to_usd_int(usd)
      )
      return(private$.submit_l1(action, .parser = function(x) {
        assert_return_HyperliquidTransfers__vault_transfer(parse_transfer_ack(x))
      }))
    }
  ),
  private = list(
    # Token wire string guard. Tokens take the `NAME:0x<tokenId>` form; resolving
    # the id is the caller's responsibility, so this only enforces a non-empty
    # scalar string with an actionable example.
    .validate_token = function(token) {
      assert::assert_scalar_character(token)
      if (!nzchar(token)) {
        rlang::abort(
          "`token` must be a non-empty string in NAME:0x<tokenId> form, e.g. \"PURR:0xc1fb593aeffbeb02f85e0308e9956a90\"."
        )
      }
      return(invisible(token))
    }
  )
)
