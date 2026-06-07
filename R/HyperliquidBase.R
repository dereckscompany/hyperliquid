# File: R/HyperliquidBase.R
# Abstract R6 base class for all Hyperliquid API client classes.

#' HyperliquidBase: Abstract Base Class for Hyperliquid API Clients
#'
#' Provides shared infrastructure for all Hyperliquid R6 classes: wallet
#' credentials, network selection, sync/async execution mode, the request
#' funnel ([hyperliquid_build_request()]), and lazy exchange-metadata caching.
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
#' All fields are private:
#' - `.keys`: List; wallet credentials from [get_api_keys()].
#' - `.base_url`: Character; REST base URL for the selected network.
#' - `.is_async`: Logical; whether the instance is in async mode.
#' - `.perform`: Function; [httr2::req_perform] or [httr2::req_perform_promise].
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
  public = list(
    #' @description
    #' Initialise a HyperliquidBase object.
    #'
    #' @param keys List; wallet credentials from [get_api_keys()]. Defaults to
    #'   `get_api_keys()`.
    #' @param testnet Logical; target testnet instead of mainnet. Default
    #'   `FALSE`.
    #' @param async Logical; if `TRUE`, methods return promises. Default `FALSE`.
    #' @param vault_address Character or `NULL`; a vault or sub-account address
    #'   to act on behalf of (threaded into the action hash and payload of
    #'   signed actions). Default `NULL`.
    #' @return Invisible self.
    initialize = function(
      keys = get_api_keys(),
      testnet = FALSE,
      async = FALSE,
      vault_address = NULL
    ) {
      assert::assert_scalar_logical(testnet)
      assert::assert_scalar_logical(async)
      assert::assert_scalar_character(vault_address, null_ok = TRUE)

      private$.keys <- keys
      private$.testnet <- isTRUE(testnet)
      private$.base_url <- get_base_url(testnet = private$.testnet)
      private$.is_async <- isTRUE(async)
      private$.vault_address <- vault_address
      private$.account_address <- keys$account_address

      if (private$.is_async) {
        if (!requireNamespace("promises", quietly = TRUE)) {
          rlang::abort("Async mode requires the 'promises' package. Install it with install.packages(\"promises\").")
        }
        private$.perform <- httr2::req_perform_promise
      } else {
        private$.perform <- httr2::req_perform
      }

      return(invisible(self))
    },

    #' @description
    #' Force a refetch of exchange metadata, replacing the cached asset-lookup
    #' tables. Metadata is otherwise fetched lazily on first need; call this
    #' after a new asset is listed.
    #' @return Invisible self.
    refresh_meta = function() {
      private$.meta_cache <- private$.fetch_meta_maps()
      return(invisible(self))
    },

    #' @description
    #' Resolve a friendly name (or canonical coin symbol) to its integer asset
    #' id, fetching and caching metadata on first need.
    #' @param name Character; a friendly name or canonical coin symbol.
    #' @return Numeric; the integer asset id used in signed actions.
    name_to_asset = function(name) {
      return(meta_name_to_asset(private$.ensure_meta(), name))
    },

    #' @description
    #' Resolve a friendly name to its canonical coin symbol, fetching and
    #' caching metadata on first need.
    #' @param name Character; a friendly name or canonical coin symbol.
    #' @return Character; the canonical coin symbol.
    name_to_coin = function(name) {
      return(meta_name_to_coin(private$.ensure_meta(), name))
    },

    #' @description
    #' Resolve an asset id to its size decimals, fetching and caching metadata
    #' on first need.
    #' @param asset Numeric; an integer asset id.
    #' @return Numeric; the asset's size decimals.
    sz_decimals = function(asset) {
      return(meta_sz_decimals(private$.ensure_meta(), asset))
    }
  ),
  active = list(
    #' @field is_async Logical; read-only flag indicating whether this instance
    #'   operates in async mode.
    is_async = function() {
      return(private$.is_async)
    },

    #' @field testnet Logical; read-only flag indicating whether this instance
    #'   targets testnet.
    testnet = function() {
      return(private$.testnet)
    }
  ),
  private = list(
    .keys = NULL,
    .base_url = NULL,
    .is_async = FALSE,
    .perform = NULL,
    .testnet = FALSE,
    .vault_address = NULL,
    .account_address = NULL,
    .meta_cache = NULL,

    # Execute a Hyperliquid API request through the single funnel.
    #
    # Injects the instance's base URL and perform function. `signed = FALSE`
    # targets /info (public reads) and `signed = TRUE` targets /exchange (the
    # caller has already built the full {action, nonce, signature, ...} body).
    # The .parser closure makes subclass methods sync/async-unaware.
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
        timeout = timeout
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
      nonce <- next_nonce()
      is_mainnet <- !private$.testnet
      sig <- sign_l1_action(
        private$.keys$private_key,
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
        private$.keys$private_key,
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
