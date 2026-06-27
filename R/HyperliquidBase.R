# File: R/HyperliquidBase.R
# Abstract R6 base class for all Hyperliquid API client classes.

#' HyperliquidBase: Abstract Base Class for Hyperliquid API Clients
#'
#' Provides shared infrastructure for all Hyperliquid R6 classes: wallet
#' credentials, network selection, sync/async execution mode, the request
#' funnel ([hyperliquid_build_request()]), and lazy exchange-metadata caching.
#'
#' It **inherits [connectcore::RestClient]**, the shared transport base, for the
#' credential storage, sync/async perform function, and the overridable
#' `.parse_envelope()` error seam — which it overrides with Hyperliquid's
#' two-failure-shape parser (`parse_hyperliquid_response()`). The `.sign()` seam
#' is left at its no-op default: Hyperliquid does not sign the HTTP request but
#' the **body** (a wallet signature embedded as a `signature` field, built and
#' attached by `.submit_l1()` / `.submit_user()` before the funnel), so request
#' signing does not apply. The body-signed wire contract is honoured by routing
#' the pre-serialised, byte-exact JSON through connectcore's shared funnel as a
#' **raw body** (`body_format = "raw"`), so the connector owns no transport: the
#' request build, perform, sync/async branch, and monotonic nonce all come from
#' connectcore. Only the body serialisation and error envelope stay
#' Hyperliquid-specific ([hyperliquid_build_request()]).
#'
#' ### Sync vs Async
#' The `async` parameter controls execution mode for all API methods:
#' - `async = FALSE` (default): methods return results directly.
#' - `async = TRUE`: methods return [promises::promise] objects that resolve to
#'   the same types.
#'
#' Async mode requires the `promises` package (a `Suggests`). Consume promises
#' with [coro::async()] and `await()` or [promises::then()]; to drive the event
#' loop in a script use the (optional) `later` package, e.g.
#' `while (!later::loop_empty()) later::run_now()`.
#'
#' ### Hosts
#' The entire REST API lives behind one host with two POST paths: `/info`
#' (public reads, unauthenticated) and `/exchange` (writes, authenticated by a
#' wallet signature in the body). Only the network differs between mainnet and
#' testnet, and it is chosen by the explicit `testnet` flag, never by URL
#' sniffing: the network changes the signature itself (phantom-agent source and
#' `hyperliquidChain` tag). See [get_base_url()].
#'
#' ### Design
#' This class is not meant to be instantiated directly. Subclasses (e.g.
#' `HyperliquidMarketData`, `HyperliquidTrading`) inherit from it and define
#' public methods that delegate to `private$.info()` (reads) or
#' `private$.exchange()` (signed writes). Each subclass method passes a
#' `.parser` closure and is otherwise sync/async-unaware.
#'
#' @section Fields:
#' All fields are private. `.keys`, `.is_async`, and `.perform` are inherited
#' from [connectcore::RestClient]; the rest are Hyperliquid-specific:
#' - `.keys`: List; wallet credentials from [get_api_keys()] (inherited).
#' - `.signer`: [ethsign::EthSigner] or `NULL`; the wallet signer built from the
#'   key (used to sign /exchange actions), or `NULL` when no key is set.
#' - `.base_url`: Character; REST base URL for the selected network (inherited).
#' - `.is_async`: Logical; whether the instance is in async mode (inherited).
#' - `.perform`: Function; [httr2::req_perform] or [httr2::req_perform_promise]
#'   (inherited).
#' - `.testnet`: Logical; whether the instance targets testnet.
#' - `.vault_address`: Character or `NULL`; vault/sub-account to act for.
#' - `.account_address`: Character or `NULL`; master account for an agent wallet.
#' - `.meta_cache`: List or `NULL`; cached asset-lookup tables (lazy).
#'
#' @importFrom R6 R6Class
#' @importFrom httr2 req_perform
#' @export
HyperliquidBase <- R6::R6Class(
  "HyperliquidBase",
  inherit = connectcore::RestClient,
  public = list(
    #' @description
    #' Initialise a HyperliquidBase object.
    #'
    #' @param keys (list) wallet credentials from [get_api_keys()]. Defaults to
    #'   `get_api_keys()`.
    #' @param testnet (scalar<logical>) target testnet instead of mainnet.
    #'   Default `FALSE`.
    #' @param async (scalar<logical>) if `TRUE`, methods return promises. Default
    #'   `FALSE`.
    #' @param vault_address (scalar<character> | NULL) a vault or sub-account
    #'   address to act on behalf of (threaded into the action hash and payload
    #'   of signed actions). Default `NULL`.
    #' @return (class<HyperliquidBase>) invisible self.
    initialize = function(
      keys = get_api_keys(),
      testnet = FALSE,
      async = FALSE,
      vault_address = NULL
    ) {
      assert_args_HyperliquidBase__initialize(keys, testnet, async, vault_address)

      # Inherit credential storage, the sync/async perform function, base URL,
      # and the .parse_envelope error seam from connectcore::RestClient. The body
      # is built and signed before the funnel and sent byte-verbatim via
      # body_format = "raw"; the instance-level default is "none" because every
      # call passes its own pre-serialised raw body explicitly.
      super$initialize(
        keys = keys,
        base_url = get_base_url(testnet = isTRUE(testnet)),
        async = isTRUE(async),
        body_format = "none",
        user_agent = "dereckscompany/hyperliquid"
      )

      private$.signer <- if (!is.null(keys$private_key)) {
        ethsign::eth_signer(private_key = keys$private_key)
      } else {
        NULL
      }
      private$.testnet <- isTRUE(testnet)
      private$.vault_address <- vault_address
      private$.account_address <- keys$account_address

      return(invisible(assert_return_HyperliquidBase__initialize(self)))
    },

    #' @description
    #' Force a refetch of exchange metadata, replacing the cached asset-lookup
    #' tables. Metadata is otherwise fetched lazily on first need; call this
    #' after a new asset is listed.
    #' @return (class<HyperliquidBase>) invisible self.
    refresh_meta = function() {
      private$.meta_cache <- private$.fetch_meta_maps()
      return(invisible(assert_return_HyperliquidBase__refresh_meta(self)))
    },

    #' @description
    #' Resolve a friendly name (or canonical coin symbol) to its integer asset
    #' id, fetching and caching metadata on first need.
    #' @param name (scalar<character>) a friendly name or canonical coin symbol.
    #' @return (scalar<count>) the integer asset id used in signed actions. Perp
    #'   ids are an R integer (`0L`, `1L`, ...) while spot ids are a double
    #'   (`10000`, ...), so the honest type is `count` (a non-negative whole
    #'   number, integer or double), not `numeric`/double.
    name_to_asset = function(name) {
      assert_args_HyperliquidBase__name_to_asset(name)
      # Return is deliberately NOT wired: the generated assert_scalar_double
      # contract is stale (lowered from the old `scalar<numeric>`) and rejects
      # the integer perp ids that build_asset_maps() produces. The corrected
      # `scalar<count>` @return regenerates to assert_scalar_count on the next
      # document().
      return(meta_name_to_asset(private$.ensure_meta(), name))
    },

    #' @description
    #' Resolve a friendly name to its canonical coin symbol, fetching and
    #' caching metadata on first need.
    #' @param name (scalar<character>) a friendly name or canonical coin symbol.
    #' @return (scalar<character>) the canonical coin symbol.
    name_to_coin = function(name) {
      assert_args_HyperliquidBase__name_to_coin(name)
      return(assert_return_HyperliquidBase__name_to_coin(
        meta_name_to_coin(private$.ensure_meta(), name)
      ))
    },

    #' @description
    #' Resolve an asset id to its size decimals, fetching and caching metadata
    #' on first need.
    #' @param asset (scalar<count>) an integer asset id (as returned by
    #'   `name_to_asset()`: an R integer for perps, a double for spot).
    #' @return (scalar<count>) the asset's size decimals.
    sz_decimals = function(asset) {
      # Neither contract is wired: the generated assert_scalar_double pair is
      # stale (lowered from `scalar<numeric>`). The `asset` arg is the integer
      # id from name_to_asset() and szDecimals arrives as an R integer over live
      # JSON, both of which assert_scalar_double rejects. The corrected
      # `scalar<count>` tags regenerate to assert_scalar_count next document().
      return(meta_sz_decimals(private$.ensure_meta(), asset))
    }
  ),
  active = list(
    #' @field testnet Logical; read-only flag indicating whether this instance
    #'   targets testnet. (`is_async` is inherited from [connectcore::RestClient].)
    testnet = function() {
      return(private$.testnet)
    }
  ),
  private = list(
    # .keys, .base_url, .is_async, and .perform are inherited from RestClient.
    .signer = NULL,
    .testnet = FALSE,
    .vault_address = NULL,
    .account_address = NULL,
    .meta_cache = NULL,

    # Hyperliquid's error envelope, overriding RestClient's default JSON/non-2xx
    # parser: /info signals failure with HTTP >= 400, /exchange with a 200 body
    # of {status:"err"}.
    .parse_envelope = function(resp) {
      return(parse_hyperliquid_response(resp))
    },

    # Execute a Hyperliquid API request through the single funnel. Serialises the
    # body to byte-exact signed JSON and routes it through connectcore's shared
    # funnel as a raw body (Hyperliquid signs the body, not the request, and
    # requires those exact bytes on the wire).
    #
    # Injects the inherited base URL, perform function, and async flag, and the
    # overridable .parse_envelope error seam. `signed = FALSE` targets /info
    # (public reads) and `signed = TRUE` targets /exchange (the caller has
    # already built the full {action, nonce, signature, ...} body). The .parser
    # closure makes subclass methods sync/async-unaware.
    .request = function(payload, signed = FALSE, .parser = identity, timeout = 30) {
      path <- "/info"
      if (isTRUE(signed)) {
        path <- "/exchange"
      }
      return(hyperliquid_build_request(
        base_url = private$.base_url,
        path = path,
        body = payload,
        .perform = private$.perform,
        .parser = .parser,
        is_async = private$.is_async,
        timeout = timeout,
        parse_envelope = private$.parse_envelope
      ))
    },

    # POST an unauthenticated /info request. `payload` is the full body
    # ({type = ..., ...}); the discriminating `type` field is supplied by the
    # calling method.
    .info = function(payload, .parser = identity, timeout = 30) {
      return(private$.request(payload, signed = FALSE, .parser = .parser, timeout = timeout))
    },

    # POST a signed /exchange action. The caller supplies the already-built
    # action, its nonce, and signature; vault_address and expires_after are
    # serialised as JSON null when NULL (matching the reference SDK payload).
    .exchange = function(
      action,
      nonce,
      signature,
      vault_address = NULL,
      expires_after = NULL,
      .parser = identity,
      timeout = 30
    ) {
      payload <- list(
        action = action,
        nonce = nonce,
        signature = signature,
        vaultAddress = vault_address,
        expiresAfter = expires_after
      )
      return(private$.request(payload, signed = TRUE, .parser = .parser, timeout = timeout))
    },

    # Abort unless a signing key is present. Signed /exchange actions need the
    # wallet private key; public /info reads do not. Called by both submit
    # helpers so the failure is the same actionable message everywhere.
    .require_signing_key = function() {
      if (is.null(private$.keys$private_key)) {
        rlang::abort(paste0(
          "A signed action requires a wallet private key, but none is set. ",
          "Set HYPERLIQUID_PRIVATE_KEY (and optionally HYPERLIQUID_ACCOUNT_ADDRESS) ",
          "or pass keys = get_api_keys(private_key = ...) to the constructor."
        ))
      }
      return(invisible(TRUE))
    },

    # Sign and submit an L1 (exchange) action in one step. Takes the bare action
    # (built and validated by the subclass method), allocates a monotonic nonce,
    # signs over the Exchange domain (threading vault_address and expires_after
    # into the action hash), and posts the {action, nonce, signature, ...} body.
    # The network is taken from the explicit testnet flag, never URL sniffing.
    .submit_l1 = function(action, .parser = identity, expires_after = NULL, timeout = 30) {
      private$.require_signing_key()
      nonce <- connectcore::next_nonce()
      is_mainnet <- !private$.testnet
      sig <- sign_l1_action(
        private$.signer,
        action,
        private$.vault_address,
        nonce,
        expires_after,
        is_mainnet
      )
      return(private$.exchange(
        action,
        nonce,
        sig,
        vault_address = private$.vault_address,
        expires_after = expires_after,
        .parser = .parser,
        timeout = timeout
      ))
    },

    # Sign and submit a user-signed action in one step. The action must already
    # carry its own nonce-bearing field (the subclass sets `time` or `nonce` to
    # the payload nonce). Mirrors the Python SDK: sign_user_signed_action() adds
    # signatureChainId and the environment-dependent hyperliquidChain tag while
    # hashing, and the SDK posts that same mutated action -- so we reproduce the
    # mutation on the posted body (appending those two fields, matching the SDK
    # key order) to keep the posted JSON byte-for-byte consistent with what was
    # signed. vaultAddress is null for user-signed actions and expiresAfter is
    # unsupported on them, so both are sent NULL.
    .submit_user = function(action, sign_types, primary_type, .parser = identity, timeout = 30) {
      private$.require_signing_key()
      is_mainnet <- !private$.testnet
      posted_action <- action
      posted_action$signatureChainId <- "0x66eee"
      posted_action$hyperliquidChain <- "Testnet"
      if (is_mainnet) {
        posted_action$hyperliquidChain <- "Mainnet"
      }
      sig <- sign_user_signed_action(
        private$.signer,
        action,
        sign_types,
        primary_type,
        is_mainnet
      )
      nonce <- coalesce_null(action$time, action$nonce)
      return(private$.exchange(
        posted_action,
        nonce,
        sig,
        vault_address = NULL,
        expires_after = NULL,
        .parser = .parser,
        timeout = timeout
      ))
    },

    # The address user-scoped reads should default to. An agent (API) wallet
    # acts for a master account, and a vault/sub-account overrides both, so the
    # precedence is vault_address, then account_address, then the key's own
    # derived wallet address (mirrors the Python SDK's market_close lookup).
    .acting_address = function() {
      return(coalesce_null(
        private$.vault_address,
        coalesce_null(private$.account_address, private$.keys$wallet_address)
      ))
    },

    # Return cached asset-lookup tables, fetching them on first need.
    .ensure_meta = function() {
      if (is.null(private$.meta_cache)) {
        private$.meta_cache <- private$.fetch_meta_maps()
      }
      return(private$.meta_cache)
    },

    # Fetch meta + spotMeta and build the asset-lookup tables. Always
    # synchronous, even for an async instance: metadata is fetched rarely and
    # every caller (e.g. order signing) needs the resolved id immediately, not a
    # promise -- so we perform with httr2::req_perform regardless of mode.
    .fetch_meta_maps = function() {
      meta <- hyperliquid_build_request(
        base_url = private$.base_url,
        path = "/info",
        body = list(type = "meta"),
        .perform = httr2::req_perform,
        .parser = identity,
        is_async = FALSE
      )
      spot_meta <- hyperliquid_build_request(
        base_url = private$.base_url,
        path = "/info",
        body = list(type = "spotMeta"),
        .perform = httr2::req_perform,
        .parser = identity,
        is_async = FALSE
      )
      return(build_asset_maps(meta, spot_meta))
    }
  )
)
