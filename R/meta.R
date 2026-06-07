# File: R/meta.R
# Lazy exchange-metadata helpers: build the coin/name/asset lookup tables from
# the raw `meta` + `spotMeta` responses and resolve names to assets. The R6
# wiring (.ensure_meta / refresh_meta / resolvers) lives on HyperliquidBase;
# these are the pure functions it delegates to.

#' Build the Coin / Name / Asset Lookup Tables
#'
#' Mirrors the Python SDK's `Info.__init__` index logic to assemble three maps
#' from the parsed `meta` (perps) and `spotMeta` (spot) responses:
#' - `coin_to_asset`: canonical coin symbol -> integer asset id.
#' - `name_to_coin`: friendly name (and canonical name) -> canonical coin.
#' - `asset_to_sz_decimals`: asset id (as a string key) -> size decimals.
#'
#' Perps take their `meta$universe` index as the asset id (BTC = 0 on mainnet).
#' Spot assets start at `10000 + index`; the named base/quote pair (e.g.
#' `"HYPE/USDC"`) is aliased to the canonical coin (`"@107"`) when not already
#' present, and size decimals come from the base token. Builder-deployed (HIP-3)
#' perp dexes are out of scope for this phase (the original `""` dex only).
#'
#' @param meta (list) the parsed `{type:"meta"}` response (has `$universe`).
#' @param spot_meta (list) the parsed `{type:"spotMeta"}` response (has
#'   `$universe` and `$tokens`).
#' @return (list) named list with `coin_to_asset`, `name_to_coin`, and
#'   `asset_to_sz_decimals` (all named lists keyed as described).
#' @keywords internal
#' @noRd
build_asset_maps <- function(meta, spot_meta) {
  assert_args_build_asset_maps(meta, spot_meta)
  coin_to_asset <- list()
  name_to_coin <- list()
  asset_to_sz_decimals <- list()

  # Index spot tokens by their integer index for base/quote lookups.
  token_by_index <- list()
  for (token in spot_meta$tokens) {
    token_by_index[[as.character(token$index)]] <- token
  }

  # Spot assets start at 10000 + index.
  for (spot_info in spot_meta$universe) {
    asset <- spot_info$index + 10000L
    coin_to_asset[[spot_info$name]] <- asset
    name_to_coin[[spot_info$name]] <- spot_info$name
    base_info <- token_by_index[[as.character(spot_info$tokens[[1]])]]
    quote_info <- token_by_index[[as.character(spot_info$tokens[[2]])]]
    asset_to_sz_decimals[[as.character(asset)]] <- base_info$szDecimals
    pair_name <- paste0(base_info$name, "/", quote_info$name)
    if (is.null(name_to_coin[[pair_name]])) {
      name_to_coin[[pair_name]] <- spot_info$name
    }
  }

  # Perps: asset = index in meta$universe (original dex, offset 0).
  asset <- 0L
  for (asset_info in meta$universe) {
    coin_to_asset[[asset_info$name]] <- asset
    name_to_coin[[asset_info$name]] <- asset_info$name
    asset_to_sz_decimals[[as.character(asset)]] <- asset_info$szDecimals
    asset <- asset + 1L
  }

  return(assert_return_build_asset_maps(list(
    coin_to_asset = coin_to_asset,
    name_to_coin = name_to_coin,
    asset_to_sz_decimals = asset_to_sz_decimals
  )))
}

#' Resolve a Friendly Name to its Canonical Coin
#'
#' @param maps (list) the lookup tables from `build_asset_maps()`.
#' @param name (scalar<character>) a friendly name or canonical coin symbol.
#' @return (scalar<character>) the canonical coin symbol.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
meta_name_to_coin <- function(maps, name) {
  assert_args_meta_name_to_coin(maps, name)
  coin <- maps$name_to_coin[[name]]
  if (is.null(coin)) {
    rlang::abort(paste0(
      "Unknown coin/name: '", name, "'. Call refresh_meta() if it was newly listed."
    ))
  }
  return(assert_return_meta_name_to_coin(coin))
}

#' Resolve a Friendly Name to its Integer Asset Id
#'
#' @param maps (list) the lookup tables from `build_asset_maps()`.
#' @param name (scalar<character>) a friendly name or canonical coin symbol.
#' @return (scalar<count>) the integer asset id used in signed actions (an R
#'   integer for perps, a double for spot).
#' @keywords internal
#' @noRd
meta_name_to_asset <- function(maps, name) {
  assert_args_meta_name_to_asset(maps, name)
  coin <- meta_name_to_coin(maps, name)
  # Return not wired: the stale assert_scalar_double contract rejects integer
  # perp ids (see name_to_asset()). Corrected @return is `scalar<count>`.
  return(maps$coin_to_asset[[coin]])
}

#' Resolve an Asset Id to its Size Decimals
#'
#' @param maps (list) the lookup tables from `build_asset_maps()`.
#' @param asset (scalar<count>) an integer asset id (integer for perps, double
#'   for spot).
#' @return (scalar<count>) the asset's size decimals.
#' @importFrom rlang abort
#' @keywords internal
#' @noRd
meta_sz_decimals <- function(maps, asset) {
  # Neither contract is wired: the stale assert_scalar_double pair rejects the
  # integer `asset` id from name_to_asset() and the integer szDecimals that
  # arrives over live JSON. Corrected tags are `scalar<count>`.
  sz <- maps$asset_to_sz_decimals[[as.character(asset)]]
  if (is.null(sz)) {
    rlang::abort(paste0(
      "Unknown asset id: ", asset, ". Call refresh_meta() if it was newly listed."
    ))
  }
  return(sz)
}
