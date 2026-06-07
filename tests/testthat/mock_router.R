# Shared mock HTTP router for the hyperliquid README and vignettes.
#
# Dispatches httr2 requests to fixture data based on the JSON REQUEST BODY type.
# Unlike coinbase (which keys on the URL), Hyperliquid exposes the entire REST
# API behind two POST paths, so there is nothing to match in the URL: every
# read is POST /info discriminated by `body$type`, and every signed write is
# POST /exchange discriminated by `body$action$type`. The fixtures come from the
# five sibling fixtures-*.R files; this file only handles routing logic.
#
# httr2 exposes a native global mock hook: `options(httr2_mock = mock_router)`
# intercepts every req_perform / req_perform_promise call, so docs render against
# canned, deterministic data with no network, no real credentials, and no funds.
# Signed actions sign the body BEFORE req_perform, so a (throwaway, ephemeral)
# wallet key must still be loadable; the mock ignores the signature entirely.
#
# Usage (in a hidden knitr setup chunk):
#   box::use(./tests/testthat/mock_router[mock_router])
#   options(httr2_mock = mock_router)

# Load the fixtures from the five sibling files. Only the names actually wired
# below are imported, so the two cross-file collisions (fixture_clearinghouse_state
# and fixture_all_mids both also live in fixtures-trading.R) never arise: the
# clearinghouseState route uses the richer account fixture, and the allMids route
# uses the market-data fixture.
box::use(
  ./`fixtures-marketdata`[
    hl_md_meta, hl_md_spot_meta, hl_md_meta_and_asset_ctxs,
    hl_md_spot_meta_and_asset_ctxs, hl_md_all_mids, hl_md_l2_book,
    hl_md_candles, hl_md_funding_history, hl_md_predicted_fundings,
    hl_md_perp_dexs, hl_md_recent_trades, hl_md_exchange_status
  ],
  ./`fixtures-account`[
    fixture_clearinghouse_state, fixture_spot_balances, fixture_open_orders,
    fixture_frontend_open_orders, fixture_user_fills, fixture_user_fills_by_time,
    fixture_historical_orders, fixture_user_funding, fixture_non_funding_ledger,
    fixture_portfolio, fixture_user_fees, fixture_user_rate_limit,
    fixture_user_role, fixture_sub_accounts, fixture_order_status,
    fixture_user_vault_equities
  ],
  ./`fixtures-trading`[
    fixture_order_mixed, fixture_order_resting, fixture_cancel_success,
    fixture_action_default
  ],
  ./`fixtures-transfers`[
    fixture_usd_class_transfer, fixture_usd_send, fixture_spot_send,
    fixture_withdraw, fixture_send_asset, fixture_sub_account_transfer,
    fixture_sub_account_spot_transfer, fixture_vault_transfer
  ],
  ./`fixtures-staking`[
    fixture_staking_summary, fixture_staking_delegations,
    fixture_staking_rewards, fixture_delegator_history,
    fixture_token_delegate_response
  ]
)

#' Build a mock httr2 response with a Hyperliquid JSON body
#'
#' Mirrors the live transport: JSON-encode a list into a real httr2 response with
#' status 200, exactly as the API returns it (`auto_unbox`, JSON `null`).
#'
#' @param data List to encode as the JSON body.
#' @param status_code Integer; HTTP status code.
#' @return An httr2 response object.
mock_hl_response <- function(data, status_code = 200L) {
  body <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  return(httr2::response(
    status_code = status_code,
    headers = list(`Content-Type` = "application/json"),
    body = charToRaw(as.character(body))
  ))
}

#' Route table: `/info` body$type -> fixture thunk.
#' Each fixture function is itself a zero-argument thunk returning the response
#' list, so it is wired directly.
#' @keywords internal
.info_routes <- list(
  # ---- Market data ----
  meta = hl_md_meta,
  spotMeta = hl_md_spot_meta,
  metaAndAssetCtxs = hl_md_meta_and_asset_ctxs,
  spotMetaAndAssetCtxs = hl_md_spot_meta_and_asset_ctxs,
  allMids = hl_md_all_mids,
  l2Book = hl_md_l2_book,
  candleSnapshot = hl_md_candles,
  fundingHistory = hl_md_funding_history,
  predictedFundings = hl_md_predicted_fundings,
  perpDexs = hl_md_perp_dexs,
  recentTrades = hl_md_recent_trades,
  exchangeStatus = hl_md_exchange_status,

  # ---- Account ----
  clearinghouseState = fixture_clearinghouse_state,
  spotClearinghouseState = fixture_spot_balances,
  openOrders = fixture_open_orders,
  frontendOpenOrders = fixture_frontend_open_orders,
  userFills = fixture_user_fills,
  userFillsByTime = fixture_user_fills_by_time,
  historicalOrders = fixture_historical_orders,
  userFunding = fixture_user_funding,
  userNonFundingLedgerUpdates = fixture_non_funding_ledger,
  portfolio = fixture_portfolio,
  userFees = fixture_user_fees,
  userRateLimit = fixture_user_rate_limit,
  userRole = fixture_user_role,
  subAccounts = fixture_sub_accounts,
  orderStatus = fixture_order_status,
  userVaultEquities = fixture_user_vault_equities,

  # ---- Staking ----
  delegatorSummary = fixture_staking_summary,
  delegations = fixture_staking_delegations,
  delegatorRewards = fixture_staking_rewards,
  delegatorHistory = fixture_delegator_history
)

#' Route table: `/exchange` body$action$type -> fixture thunk.
#' @keywords internal
.exchange_routes <- list(
  # ---- Trading ----
  order = fixture_order_mixed,
  batchModify = fixture_order_resting,
  cancel = fixture_cancel_success,
  cancelByCloid = fixture_cancel_success,
  scheduleCancel = fixture_action_default,
  updateLeverage = fixture_action_default,
  updateIsolatedMargin = fixture_action_default,
  approveAgent = fixture_action_default,
  approveBuilderFee = fixture_action_default,

  # ---- Transfers ----
  usdClassTransfer = fixture_usd_class_transfer,
  usdSend = fixture_usd_send,
  spotSend = fixture_spot_send,
  withdraw3 = fixture_withdraw,
  sendAsset = fixture_send_asset,
  subAccountTransfer = fixture_sub_account_transfer,
  subAccountSpotTransfer = fixture_sub_account_spot_transfer,
  vaultTransfer = fixture_vault_transfer,

  # ---- Staking write ----
  tokenDelegate = fixture_token_delegate_response
)

#' Mock HTTP router for README and vignettes
#'
#' Dispatches `httr2` requests to fixture data based on the JSON request body.
#' Set via `options(httr2_mock = mock_router)` in a hidden knitr setup chunk.
#'
#' Hyperliquid has only two endpoints, so the routing keys on the body, not the
#' URL: `/info` reads dispatch on `body$type`, `/exchange` signed writes on
#' `body$action$type`.
#'
#' @param req An `httr2_request` object.
#' @return An `httr2_response` object.
#' @export
mock_router <- function(req) {
  raw_body <- req$body$data
  body_txt <- if (is.raw(raw_body)) rawToChar(raw_body) else as.character(raw_body)
  body <- jsonlite::fromJSON(body_txt, simplifyVector = FALSE)

  if (grepl("/exchange", req$url, fixed = TRUE)) {
    type <- body$action$type
    fixture <- .exchange_routes[[as.character(type)]]
    where <- "/exchange action"
  } else {
    type <- body$type
    fixture <- .info_routes[[as.character(type)]]
    where <- "/info"
  }

  if (is.null(fixture)) {
    stop(sprintf(
      "Unmocked Hyperliquid %s type: '%s'. Add it to mock_router.R.",
      where, if (is.null(type)) "<missing>" else type
    ))
  }

  return(mock_hl_response(fixture()))
}
