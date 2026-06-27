# hyperliquid 0.1.0

## Transport: migrate to connectcore

* `HyperliquidBase` now **inherits `connectcore::RestClient`**, the shared
  transport base, for credential storage, the sync/async perform function, and
  the overridable `.parse_envelope()` error seam. The Hyperliquid two-failure-
  shape parser (`/info` HTTP 422 text, `/exchange` 200 `{status:"err"}`) is
  wired as the `.parse_envelope()` override. The `.sign()` request seam is left
  at its no-op default: Hyperliquid signs the **body** (a wallet signature
  embedded as a `signature` field), not the HTTP request.
* The duplicated `then_or_now()` (the single sync/async branch point) and
  `next_nonce()` (the monotonic epoch-millisecond nonce) now come from
  connectcore; the local copies were removed.
* `hyperliquid_build_request()` stays Hyperliquid-specific — the body-signed
  wire contract requires the exact signed JSON on the wire (including
  `vaultAddress`/`expiresAfter` as JSON `null`), so it keeps `req_body_raw()`
  rather than connectcore's request funnel — but it now delegates its sync/async
  branch to `connectcore::then_or_now()` and accepts an overridable
  `parse_envelope` seam.
* No public API change: every exported class, method, signature, and return
  shape is unchanged, and the full test suite passes.

# hyperliquid 0.0.1

Initial release: an R wrapper for the Hyperliquid decentralised
exchange, covering perpetual and spot trading across both synchronous and
asynchronous (promise-based) operations, with Ethereum wallet signing for the
`/exchange` endpoint computed in pure R.

## Features

* **Market data** (`HyperliquidMarketData`, public, no auth): perp and spot
  metadata, per-asset contexts (mark/mid/oracle/funding/open-interest), all
  mids, the L2 order book, OHLCV candles, funding history and predicted
  fundings, builder-deployed perp dexes, recent trades, and exchange status.
* **Account** (`HyperliquidAccount`, public reads by address): positions and
  cross-margin summary, spot balances, open and frontend orders, fills (recent
  and by time), historical orders, funding and non-funding ledgers, portfolio
  value/PnL/volume, fee schedule, rate limit, role, sub-accounts, single-order
  status, and vault equities.
* **Trading** (`HyperliquidTrading`, signed): place / modify / cancel orders
  (single or bulk, by order id or client order id), market open and close,
  scheduled dead-man's-switch cancel, leverage and isolated-margin updates, and
  agent / builder-fee approvals.
* **Transfers** (`HyperliquidTransfers`, signed): spot/perp collateral class
  transfer, USDC and spot-token sends, bridge withdrawals, cross-dex sends, and
  sub-account and vault transfers.
* **Staking** (`HyperliquidStaking`): delegator summary, per-validator
  delegations, reward and full delegate/deposit/withdraw history, and the
  delegate / undelegate action.
* **Bulk backfill**: `hyperliquid_backfill_klines()` and
  `hyperliquid_backfill_funding()` walk history for many coins/intervals to a
  CSV, appending incrementally with resume. A bundled `hyperliquid_ohlcv`
  sample dataset ships daily candles for examples.
* **Sync and async**: every method works in both modes; `async = TRUE` returns
  a `promises::promise` resolving to the same `data.table`.

## Design

* Every public method returns a single flat `data.table` with no list columns;
  nested objects are flattened to scalar `snake_case` columns and heterogeneous
  rows are stacked with a discriminator column.
* The `/exchange` endpoint is authenticated by an Ethereum wallet signature
  (secp256k1 ECDSA, Keccak-256, EIP-712, and the msgpack action hash)
  implemented in pure R (`openssl` + `gmp`) with no compiled code, and verified
  byte-identical to the official Python and Rust SDK test vectors.
* All requests flow through a single funnel (`hyperliquid_build_request()`) with
  one sync/async branch point. The network is selected by an explicit `testnet`
  flag, never by URL sniffing, because it changes the signature itself.
* Inputs are validated with the `assert` package; times are handled in UTC via
  `lubridate`, and amounts are transmitted with exact precision.
