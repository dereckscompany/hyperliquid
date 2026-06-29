# Shared mock HTTP router for the hyperliquid README, vignettes, and tests.
#
# This is the THIN hyperliquid-specific layer over connectcore's shared mock
# harness (connectcore::mock_router / body_routes / with_mock_api /
# local_mock_api / load_fixtures / mock_response). connectcore owns the response
# builder, the dispatch loop, and the scoped-activation helpers; this file only
# declares the route table and loads the fixtures from disk.
#
# Unlike coinbase (which keys on the URL), Hyperliquid exposes the entire REST
# API behind two POST paths, so there is nothing to match in the URL: every read
# is POST /info discriminated by `body$type`, and every signed write is POST
# /exchange discriminated by `body$action$type`. connectcore::body_routes()
# builds one predicate-route per body type from a named case table, so the table
# below is just `type -> captured-fixture JSON string`.
#
# Each fixture is the REAL captured (or, for write acks, synthetic) Hyperliquid
# JSON for that body type, loaded verbatim from tests/testthat/fixtures/*.json by
# connectcore::load_fixtures() (a named list keyed by file basename; each value
# the raw JSON string). connectcore::mock_response() serves a string body
# verbatim, so the parsers and column contracts run against genuine response
# shapes. The captured read fixtures are scrubbed of every real account / vault /
# validator address and on-chain hash (deterministic placeholders) while
# preserving the exact JSON shape; the /exchange write acks are synthetic
# success envelopes (write endpoints are never called to capture).
#
# httr2 exposes a native global mock hook: connectcore::with_mock_api(.mock_routes,
# { ... }) (or local_mock_api(.mock_routes)) installs the dispatcher as the
# httr2_mock option, intercepting every req_perform / req_perform_promise call,
# so docs render and tests run against canned, deterministic data with no
# network, no real credentials, and no funds. Signed /exchange actions sign the
# body BEFORE req_perform, so a (throwaway, ephemeral) wallet key must still be
# loadable; the mock ignores the signature entirely.
#
# Usage (in a hidden knitr setup chunk or a test):
#   box::use(./tests/testthat/mock_router[.mock_routes])
#   connectcore::with_mock_api(.mock_routes, { ...code... })  # scoped to a block
#   connectcore::local_mock_api(.mock_routes)                 # scoped to a frame

box::use(
  connectcore[body_routes, load_fixtures]
)

# Load every captured fixture as its raw JSON string, keyed by file basename
# (meta.json -> "meta"). Resolved relative to THIS module file so it works from
# the package root (README), vignettes/, and tests/testthat alike.
.fixtures <- load_fixtures(box::file("fixtures"))

#' `/info` read routes: `body$type` -> captured-fixture JSON string.
#'
#' One case per read endpoint. The two cross-domain collisions resolve here:
#' `clearinghouseState` serves the richer two-position account fixture and
#' `allMids` the market-data dictionary.
#' @keywords internal
.info_cases <- list(
  # ---- Market data ----
  meta = .fixtures$meta,
  spotMeta = .fixtures$spot_meta,
  metaAndAssetCtxs = .fixtures$meta_and_asset_ctxs,
  spotMetaAndAssetCtxs = .fixtures$spot_meta_and_asset_ctxs,
  allMids = .fixtures$all_mids,
  l2Book = .fixtures$l2_book,
  candleSnapshot = .fixtures$candle_snapshot,
  fundingHistory = .fixtures$funding_history,
  predictedFundings = .fixtures$predicted_fundings,
  perpDexs = .fixtures$perp_dexs,
  recentTrades = .fixtures$recent_trades,
  exchangeStatus = .fixtures$exchange_status,

  # ---- Account ----
  clearinghouseState = .fixtures$clearinghouse_state,
  spotClearinghouseState = .fixtures$spot_clearinghouse_state,
  openOrders = .fixtures$open_orders,
  frontendOpenOrders = .fixtures$frontend_open_orders,
  userFills = .fixtures$user_fills,
  userFillsByTime = .fixtures$user_fills_by_time,
  historicalOrders = .fixtures$historical_orders,
  userFunding = .fixtures$user_funding,
  userNonFundingLedgerUpdates = .fixtures$user_non_funding_ledger_updates,
  portfolio = .fixtures$portfolio,
  userFees = .fixtures$user_fees,
  userRateLimit = .fixtures$user_rate_limit,
  userRole = .fixtures$user_role,
  subAccounts = .fixtures$sub_accounts,
  orderStatus = .fixtures$order_status,
  userVaultEquities = .fixtures$user_vault_equities,

  # ---- Staking ----
  delegatorSummary = .fixtures$delegator_summary,
  delegations = .fixtures$delegations,
  delegatorRewards = .fixtures$delegator_rewards,
  delegatorHistory = .fixtures$delegator_history
)

#' `/exchange` write routes: `body$action$type` -> synthetic-ack JSON string.
#' @keywords internal
.exchange_cases <- list(
  # ---- Trading ----
  order = .fixtures$order,
  batchModify = .fixtures$batch_modify,
  cancel = .fixtures$cancel,
  cancelByCloid = .fixtures$cancel_by_cloid,
  scheduleCancel = .fixtures$schedule_cancel,
  updateLeverage = .fixtures$update_leverage,
  updateIsolatedMargin = .fixtures$update_isolated_margin,
  approveAgent = .fixtures$approve_agent,
  approveBuilderFee = .fixtures$approve_builder_fee,

  # ---- Transfers ----
  usdClassTransfer = .fixtures$usd_class_transfer,
  usdSend = .fixtures$usd_send,
  spotSend = .fixtures$spot_send,
  withdraw3 = .fixtures$withdraw3,
  sendAsset = .fixtures$send_asset,
  subAccountTransfer = .fixtures$sub_account_transfer,
  subAccountSpotTransfer = .fixtures$sub_account_spot_transfer,
  vaultTransfer = .fixtures$vault_transfer,

  # ---- Staking write ----
  tokenDelegate = .fixtures$token_delegate
)

#' Route table: body-discriminated routes for `/exchange` and `/info`.
#'
#' `/exchange` is matched before `/info` so a signed write (which also contains a
#' top-level `type` from its envelope) never falls through to a read route.
#' @export
.mock_routes <- c(
  body_routes("/exchange", c("action", "type"), .exchange_cases),
  body_routes("/info", "type", .info_cases)
)
