# File: R/HyperliquidTrading.R
# Signed /exchange trading client: order placement, modification, cancellation,
# scheduled cancels, leverage/margin updates, and agent/builder-fee approvals.

#' HyperliquidTrading: Order Placement, Cancellation, and Account Controls
#'
#' ### Purpose
#' Signed `/exchange` trading actions: place and modify limit/trigger orders
#' (single or bulk), open and close positions at market via an aggressive
#' immediate-or-cancel limit, cancel by order id or client order id (single or
#' bulk), schedule a dead-man's-switch cancel-all, set per-asset leverage and
#' isolated margin, and approve an agent (API) wallet or a builder fee. Every
#' method requires a wallet signing key.
#'
#' Inherits from [HyperliquidBase]. Order/cancel actions are **L1** actions
#' hashed and signed over the Exchange domain (asset ids and key insertion order
#' are part of the signature, so both are reproduced exactly). The two
#' approvals are **user-signed** actions over the `HyperliquidSignTransaction`
#' EIP-712 domain.
#'
#' ### Sync vs Async
#' Most methods support both modes via the `async` argument at construction. The
#' exceptions are [market_open()][HyperliquidTrading] and
#' [market_close()][HyperliquidTrading]: they chain a read (the mid price, and
#' for closes the open position) before the write, so they are **sync-preferred**
#' and assume the chained `/info` read resolves synchronously.
#'
#' ### Official Documentation
#' <https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/exchange-endpoint>
#'
#' ### Endpoints Covered
#' | Method | type | Auth |
#' |--------|------|------|
#' | place_order | order | Yes |
#' | bulk_orders | order | Yes |
#' | market_open | order | Yes |
#' | market_close | order | Yes |
#' | modify_order | batchModify | Yes |
#' | bulk_modify | batchModify | Yes |
#' | cancel_order | cancel | Yes |
#' | bulk_cancel | cancel | Yes |
#' | cancel_by_cloid | cancelByCloid | Yes |
#' | bulk_cancel_by_cloid | cancelByCloid | Yes |
#' | schedule_cancel | scheduleCancel | Yes |
#' | update_leverage | updateLeverage | Yes |
#' | update_isolated_margin | updateIsolatedMargin | Yes |
#' | approve_agent | approveAgent | Yes |
#' | approve_builder_fee | approveBuilderFee | Yes |
#'
#' @examples
#' \dontrun{
#' trading <- HyperliquidTrading$new()
#' # A resting post-only bid:
#' trading$place_order("BTC", is_buy = TRUE, sz = 0.001, limit_px = 50000,
#'   order_type = list(limit = list(tif = "Alo")))
#' # Open and then close a long at market:
#' trading$market_open("BTC", is_buy = TRUE, sz = 0.001)
#' trading$market_close("BTC")
#' # Cancel one order, then arm a 1-minute dead-man's switch:
#' trading$cancel_order("BTC", oid = 123456789)
#' trading$schedule_cancel(lubridate::now("UTC") + lubridate::seconds(60))
#' }
#'
#' @import data.table
#' @importFrom R6 R6Class
#' @export
HyperliquidTrading <- R6::R6Class(
  "HyperliquidTrading",
  inherit = HyperliquidBase,
  public = list(
    #' @description Place a single order. A thin wrapper over [bulk_orders()][HyperliquidTrading].
    #'   Builder fees are never applied automatically: a `builder` is attached
    #'   only when you pass one explicitly.
    #' @param name (scalar<character>) the coin or friendly name, e.g. `"BTC"`.
    #' @param is_buy (scalar<logical>) `TRUE` for a bid, `FALSE` for an ask.
    #' @param sz (scalar<numeric in ]0, Inf[>) the order size in coin units.
    #' @param limit_px (scalar<numeric in ]0, Inf[>) the limit price.
    #' @param order_type (list) either
    #'   `list(limit = list(tif = "Gtc"|"Ioc"|"Alo"))` or
    #'   `list(trigger = list(triggerPx = , isMarket = , tpsl = "tp"|"sl"))`.
    #' @param reduce_only (scalar<logical>) `TRUE` to only reduce an existing
    #'   position. Default `FALSE`.
    #' @param cloid (scalar<character> | NULL) an optional client order id from
    #'   [new_cloid()]. Default `NULL`.
    #' @param builder (list?) an optional builder fee spec
    #'   `list(b = <address>, f = <tenths-of-bps>)`. Default `NULL`.
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status, or a promise thereof.
    place_order = function(
      name,
      is_buy,
      sz,
      limit_px,
      order_type,
      reduce_only = FALSE,
      cloid = NULL,
      builder = NULL
    ) {
      assert_args_HyperliquidTrading__place_order(
        name, is_buy, sz, limit_px, order_type, reduce_only, cloid, builder
      )
      order <- list(
        coin = name,
        is_buy = is_buy,
        sz = sz,
        limit_px = limit_px,
        order_type = order_type,
        reduce_only = reduce_only
      )
      if (!is.null(cloid)) {
        order$cloid <- cloid
      }
      return(self$bulk_orders(list(order), builder = builder))
    },

    #' @description Place a batch of orders in one signed action. Each order is
    #'   validated, its coin resolved to an asset id, and converted to its wire
    #'   shape; the wires are assembled into one `order` action.
    #' @param orders (list) unnamed list of order specs; each a named list with
    #'   `coin`, `is_buy`, `sz`, `limit_px`, `order_type`, `reduce_only`, and
    #'   optional `cloid` (same fields as [place_order()][HyperliquidTrading]).
    #' @param builder (list?) an optional builder fee spec
    #'   `list(b = <address>, f = <tenths-of-bps>)`. The address is lowercased.
    #'   Default `NULL`.
    #' @param grouping (scalar<character>) one of `"na"`, `"normalTpsl"`,
    #'   `"positionTpsl"`. Default `"na"`.
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status, or a promise thereof.
    bulk_orders = function(orders, builder = NULL, grouping = "na") {
      assert_args_HyperliquidTrading__bulk_orders(orders, builder, grouping)
      wires <- lapply(orders, function(order) {
        return(private$.order_to_wire(order))
      })
      if (!is.null(builder)) {
        builder$b <- tolower(builder$b)
      }
      action <- order_wires_to_order_action(wires, builder, grouping)
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__bulk_orders(parse_order_response(x)))
      }))
    },

    #' @description Open a position at market: read the current mid, compute an
    #'   aggressive immediate-or-cancel limit price `mid * (1 +/- slippage)`, and
    #'   submit it. Sync-preferred: it chains a mid-price read before the write.
    #' @param name (scalar<character>) the coin or friendly name, e.g. `"BTC"`.
    #' @param is_buy (scalar<logical>) `TRUE` to open long, `FALSE` to open
    #'   short.
    #' @param sz (scalar<numeric in ]0, Inf[>) the order size in coin units.
    #' @param slippage (scalar<numeric in ]0, Inf[>) the price tolerance
    #'   fraction. Default `0.05` (5%).
    #' @param cloid (scalar<character> | NULL) an optional client order id.
    #'   Default `NULL`.
    #' @param builder (list?) an optional builder fee spec. Default `NULL`.
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status.
    market_open = function(name, is_buy, sz, slippage = 0.05, cloid = NULL, builder = NULL) {
      assert_args_HyperliquidTrading__market_open(name, is_buy, sz, slippage, cloid, builder)
      validate_coin(name)
      px <- private$.slippage_price(name, is_buy, slippage)
      return(self$place_order(
        name,
        is_buy = is_buy,
        sz = sz,
        limit_px = px,
        order_type = list(limit = list(tif = "Ioc")),
        reduce_only = FALSE,
        cloid = cloid,
        builder = builder
      ))
    },

    #' @description Close a position at market: read the open position to find its
    #'   signed size, take the opposite side, and submit a reduce-only aggressive
    #'   immediate-or-cancel limit. Sync-preferred: it chains the position read and
    #'   a mid-price read before the write.
    #' @param name (scalar<character>) the coin or friendly name, e.g. `"BTC"`.
    #' @param sz (scalar<numeric in ]0, Inf[> | NULL) the size to close. `NULL`
    #'   (default) closes the whole position (`abs(szi)`).
    #' @param slippage (scalar<numeric in ]0, Inf[>) the price tolerance
    #'   fraction. Default `0.05` (5%).
    #' @param cloid (scalar<character> | NULL) an optional client order id.
    #'   Default `NULL`.
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status.
    #' @importFrom rlang abort
    market_close = function(name, sz = NULL, slippage = 0.05, cloid = NULL) {
      assert_args_HyperliquidTrading__market_close(name, sz, slippage, cloid)
      validate_coin(name)
      coin <- self$name_to_coin(name)
      state <- private$.info(
        list(type = "clearinghouseState", user = private$.acting_address()),
        .parser = identity
      )
      szi <- private$.position_szi(state, coin)
      if (is.null(szi)) {
        rlang::abort(paste0(
          "No open position for '", coin, "' to close. Open one with market_open()."
        ))
      }
      is_buy <- szi < 0
      close_sz <- coalesce_null(sz, abs(szi))
      assert_finite_positive(close_sz, "sz")
      px <- private$.slippage_price(name, is_buy, slippage)
      return(self$place_order(
        name,
        is_buy = is_buy,
        sz = close_sz,
        limit_px = px,
        order_type = list(limit = list(tif = "Ioc")),
        reduce_only = TRUE,
        cloid = cloid
      ))
    },

    #' @description Modify a single resting order in place. A thin wrapper over
    #'   [bulk_modify()][HyperliquidTrading].
    #' @param oid (scalar<numeric>) the resting order's id (oid).
    #' @param name (scalar<character>) the coin or friendly name.
    #' @param is_buy (scalar<logical>) the (possibly new) side.
    #' @param sz (scalar<numeric in ]0, Inf[>) the (possibly new) size.
    #' @param limit_px (scalar<numeric in ]0, Inf[>) the (possibly new) price.
    #' @param order_type (list) the order type (see
    #'   [place_order()][HyperliquidTrading]).
    #' @param reduce_only (scalar<logical>) default `FALSE`.
    #' @param cloid (scalar<character> | NULL) an optional client order id.
    #'   Default `NULL`.
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status, or a promise thereof.
    modify_order = function(
      oid,
      name,
      is_buy,
      sz,
      limit_px,
      order_type,
      reduce_only = FALSE,
      cloid = NULL
    ) {
      assert_args_HyperliquidTrading__modify_order(
        oid, name, is_buy, sz, limit_px, order_type, reduce_only, cloid
      )
      order <- list(
        coin = name,
        is_buy = is_buy,
        sz = sz,
        limit_px = limit_px,
        order_type = order_type,
        reduce_only = reduce_only
      )
      if (!is.null(cloid)) {
        order$cloid <- cloid
      }
      return(self$bulk_modify(list(list(oid = oid, order = order))))
    },

    #' @description Modify a batch of resting orders in one signed `batchModify`
    #'   action.
    #' @param modifies (list) unnamed list of modify specs; each a named list
    #'   with `oid` (numeric) and `order` (an order spec, see
    #'   [place_order()][HyperliquidTrading]).
    #' @return (promise<OrderResult>) a [data.table::data.table], one row per
    #'   status, or a promise thereof.
    bulk_modify = function(modifies) {
      assert_args_HyperliquidTrading__bulk_modify(modifies)
      wires <- lapply(modifies, function(modify) {
        return(list(oid = modify$oid, order = private$.order_to_wire(modify$order)))
      })
      action <- list(type = "batchModify", modifies = wires)
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__bulk_modify(parse_order_response(x)))
      }))
    },

    #' @description Cancel a single order by its order id. A thin wrapper over
    #'   [bulk_cancel()][HyperliquidTrading].
    #' @param name (scalar<character>) the coin or friendly name.
    #' @param oid (scalar<numeric>) the order id to cancel.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   cancel, or a promise thereof.
    cancel_order = function(name, oid) {
      assert_args_HyperliquidTrading__cancel_order(name, oid)
      return(self$bulk_cancel(list(list(coin = name, oid = oid))))
    },

    #' @description Cancel a single order by its client order id. A thin wrapper
    #'   over [bulk_cancel_by_cloid()][HyperliquidTrading].
    #' @param name (scalar<character>) the coin or friendly name.
    #' @param cloid (scalar<character>) the client order id (`0x`-prefixed 32 hex
    #'   chars).
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   cancel, or a promise thereof.
    cancel_by_cloid = function(name, cloid) {
      assert_args_HyperliquidTrading__cancel_by_cloid(name, cloid)
      return(self$bulk_cancel_by_cloid(list(list(coin = name, cloid = cloid))))
    },

    #' @description Cancel a batch of orders by order id in one signed `cancel`
    #'   action. Each cancel resolves its coin to an asset id (the wire `a`) and
    #'   carries the oid (the wire `o`).
    #' @param cancels (list) unnamed list of cancel specs; each a named list with
    #'   `coin` and `oid`.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   cancel, or a promise thereof.
    bulk_cancel = function(cancels) {
      assert_args_HyperliquidTrading__bulk_cancel(cancels)
      items <- lapply(cancels, function(cancel) {
        validate_coin(cancel$coin)
        return(list(a = self$name_to_asset(cancel$coin), o = cancel$oid))
      })
      action <- list(type = "cancel", cancels = items)
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__bulk_cancel(parse_cancel_response(x)))
      }))
    },

    #' @description Cancel a batch of orders by client order id in one signed
    #'   `cancelByCloid` action. Each cancel carries the asset id (the wire
    #'   `asset`) and the cloid.
    #' @param cancels (list) unnamed list of cancel specs; each a named list with
    #'   `coin` and `cloid`.
    #' @return (promise<data.table>) a [data.table::data.table], one row per
    #'   cancel, or a promise thereof.
    bulk_cancel_by_cloid = function(cancels) {
      assert_args_HyperliquidTrading__bulk_cancel_by_cloid(cancels)
      items <- lapply(cancels, function(cancel) {
        validate_coin(cancel$coin)
        cloid <- validate_cloid(cancel$cloid)
        return(list(asset = self$name_to_asset(cancel$coin), cloid = cloid))
      })
      action <- list(type = "cancelByCloid", cancels = items)
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__bulk_cancel_by_cloid(parse_cancel_response(x)))
      }))
    },

    #' @description Arm or disarm a dead-man's switch: schedule a time at which
    #'   all open orders are cancelled. The time must be at least 5 seconds in the
    #'   future; pass `NULL` to clear a pending schedule. Max 10 triggers per UTC
    #'   day.
    #' @param time (POSIXct | numeric | NULL) when to cancel all orders (POSIXct,
    #'   numeric epoch-milliseconds, or `NULL`). `NULL` (default) clears any
    #'   pending schedule.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    schedule_cancel = function(time = NULL) {
      assert_args_HyperliquidTrading__schedule_cancel(time)
      action <- list(type = "scheduleCancel")
      if (!is.null(time)) {
        action$time <- if (is.numeric(time)) floor(time) else datetime_to_ms(time)
      }
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__schedule_cancel(parse_action_status(x)))
      }))
    },

    #' @description Set the leverage for a coin, cross or isolated.
    #' @param name (scalar<character>) the coin or friendly name.
    #' @param leverage (scalar<count in [1, Inf[>) a finite, strictly-positive
    #'   whole number (accepts an integer or a whole-valued double).
    #' @param is_cross (scalar<logical>) `TRUE` for cross margin, `FALSE` for
    #'   isolated. Default `TRUE`.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    update_leverage = function(name, leverage, is_cross = TRUE) {
      assert_args_HyperliquidTrading__update_leverage(name, leverage, is_cross)
      validate_coin(name)
      action <- list(
        type = "updateLeverage",
        asset = self$name_to_asset(name),
        isCross = is_cross,
        leverage = leverage
      )
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__update_leverage(parse_action_status(x)))
      }))
    },

    #' @description Add or remove isolated margin for a coin. The USD amount is
    #'   scaled to a micro-USD integer (x1e6) before signing. A positive `amount`
    #'   adds margin; a negative `amount` removes it (SDK parity).
    #' @param name (scalar<character>) the coin or friendly name.
    #' @param amount (scalar<numeric>) the USD amount of margin to move -- a
    #'   finite, non-zero scalar. Positive adds margin, negative removes it.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    #' @importFrom rlang abort
    update_isolated_margin = function(name, amount) {
      assert_args_HyperliquidTrading__update_isolated_margin(name, amount)
      validate_coin(name)
      if (!is.finite(amount) || amount == 0) {
        rlang::abort(sprintf(
          "`amount` must be a single finite, non-zero number (negative removes margin), got: %s",
          format(amount)
        ))
      }
      action <- list(
        type = "updateIsolatedMargin",
        asset = self$name_to_asset(name),
        isBuy = TRUE,
        ntli = float_to_usd_int(amount)
      )
      return(private$.submit_l1(action, .parser = function(x) {
        return(assert_return_HyperliquidTrading__update_isolated_margin(parse_action_status(x)))
      }))
    },

    #' @description Approve a fresh agent (API) wallet for this account. A new
    #'   secp256k1 key is generated locally, its address approved on-chain, and
    #'   the **secret is returned to you** -- store it securely, as it is the only
    #'   time it is exposed and it can sign trading actions for this account until
    #'   revoked.
    #'
    #'   Mirrors the reference SDK: when `name` is `NULL` the action is signed with
    #'   an empty `agentName`. (The SDK then strips the empty field from the posted
    #'   body; this client instead posts `agentName = ""`, which is
    #'   signature-equivalent because the server defaults a missing `agentName` to
    #'   the empty string -- the EIP-712 digest is identical either way.)
    #' @param name (scalar<character> | NULL) an optional human-readable agent
    #'   name. Default `NULL`.
    #' @return (promise<data.table>) a single-row [data.table::data.table] with
    #'   `agent_address`, `agent_key` (the new hex secret), and `status`, or a
    #'   promise thereof.
    #' @importFrom openssl rand_bytes
    approve_agent = function(name = NULL) {
      assert_args_HyperliquidTrading__approve_agent(name)
      private$.require_signing_key()
      agent_raw <- openssl::rand_bytes(32L)
      agent_key <- paste0("0x", paste(sprintf("%02x", as.integer(agent_raw)), collapse = ""))
      agent_address <- eth_address(agent_raw)
      action <- list(
        type = "approveAgent",
        agentAddress = agent_address,
        agentName = coalesce_null(name, ""),
        nonce = next_nonce()
      )
      return(private$.submit_user(
        action,
        sign_types = APPROVE_AGENT_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:ApproveAgent",
        .parser = function(resp) {
          return(assert_return_HyperliquidTrading__approve_agent(data.table::data.table(
            agent_address = agent_address,
            agent_key = agent_key,
            status = chr_or_na(resp$status)
          )))
        }
      ))
    },

    #' @description Approve a maximum builder fee for a builder address, allowing
    #'   that builder to attach a fee (up to `max_fee_rate`) to your orders.
    #' @param builder (scalar<character>) the builder's `0x`-prefixed address.
    #' @param max_fee_rate (scalar<character>) the max fee as a percent string,
    #'   e.g. `"0.001%"`.
    #' @return (promise<TransferAck>) a single-row [data.table::data.table] with
    #'   `status` and `response_type`, or a promise thereof.
    approve_builder_fee = function(builder, max_fee_rate) {
      assert_args_HyperliquidTrading__approve_builder_fee(builder, max_fee_rate)
      builder <- validate_address(builder)
      action <- list(
        maxFeeRate = max_fee_rate,
        builder = builder,
        nonce = next_nonce(),
        type = "approveBuilderFee"
      )
      return(private$.submit_user(
        action,
        sign_types = APPROVE_BUILDER_FEE_SIGN_TYPES,
        primary_type = "HyperliquidTransaction:ApproveBuilderFee",
        .parser = function(x) {
          return(assert_return_HyperliquidTrading__approve_builder_fee(parse_action_status(x)))
        }
      ))
    }
  ),
  private = list(
    # Validate an order spec and convert it to its wire shape. Shared by
    # bulk_orders and bulk_modify so the validation and asset resolution are
    # identical for new and modified orders.
    .order_to_wire = function(order) {
      validate_coin(order$coin)
      assert_finite_positive(order$sz, "sz")
      assert_finite_positive(order$limit_px, "limit_px")
      if (!is.null(order$cloid)) {
        order$cloid <- validate_cloid(order$cloid)
      }
      return(order_request_to_order_wire(order, self$name_to_asset(order$coin)))
    },

    # Compute an aggressive marketable limit price. Mirrors exchange.py
    # _slippage_price: read the mid when no price is given, skew it by the
    # slippage fraction, round to 5 significant figures, then to (6 for perps,
    # 8 for spot) minus the asset's size decimals. Spot assets are id >= 10000.
    # SYNC path: the all_mids read is treated as a value, not a promise.
    .slippage_price = function(name, is_buy, slippage, px = NULL) {
      coin <- self$name_to_coin(name)
      asset <- self$name_to_asset(name)
      if (is.null(px)) {
        mids <- private$.info(list(type = "allMids"), .parser = parse_all_mids)
        px <- mids[["mid"]][match(coin, mids[["coin"]])]
        if (length(px) == 0L || is.na(px)) {
          rlang::abort(paste0("No mid price available for '", coin, "'."))
        }
      }
      is_spot <- asset >= 10000
      px <- px * if (isTRUE(is_buy)) (1 + slippage) else (1 - slippage)
      decimals <- (if (is_spot) 8 else 6) - self$sz_decimals(asset)
      return(round(signif(px, 5), decimals))
    },

    # Find the signed position size (szi) for a coin in a clearinghouseState
    # response, or NULL when there is no open position for that coin.
    .position_szi = function(state, coin) {
      for (position in state$assetPositions) {
        item <- position$position
        if (identical(item$coin, coin)) {
          return(as.numeric(item$szi))
        }
      }
      return(NULL)
    }
  )
)
