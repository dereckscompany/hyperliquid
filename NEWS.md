# hyperliquid 0.2.1

## Hardening: validate fixtures and contracts against the real testnet API

* Added `dev/capture-hyperliquid.R`, a read-only capture harness that hits the real Hyperliquid API and writes each raw `/info` response verbatim to the git-ignored `local/raw-data/hyperliquid/`. Hyperliquid is body-routed, so reads are `POST /info` discriminated by `body$type`; the harness issues only those reads (it never touches the signed-write `/exchange` endpoint, never signs anything, and uses only the public account address), then summarises each endpoint as POPULATED / EMPTY / FAIL. All 32 read endpoints were captured against testnet with zero failures, and every committed fixture's structure was validated against its live counterpart: the parsers parse the real responses cleanly, and the only divergences are additive API fields (e.g. `marginTables`, `feeSchedule`, `isDelisted`) that no parser consumes, so no fixture enrichment was required.

## Fixes: empty-collection responses violated their own column contracts

* `get_positions()` raised a contract error on a **flat account** (no open positions). The live capture reproduced this: `parse_positions()` returned a bare zero-column `data.table` on an empty `assetPositions`, but the `@return` contract requires the ten position columns. The empty branch now returns the typed zero-row schema (a zero-row typed column satisfies `assert_no_missing_values`), so a flat account parses cleanly. The synthetic fixture hid the bug because it always carried two open positions.
* The same empty-collection defect was fixed in `parse_margin_summary()` (an address that never deposited), `parse_user_fills()` / `get_user_fills()` / `get_user_fills_by_time()` (an account that never traded), `parse_funding_history()` (a coin/window with no funding events), and `parse_candles()` (an empty candle window): each empty branch now returns the typed zero-row schema its `@return` contract documents, instead of a column-less `data.table`. Regression tests assert the empty parser output carries the full column set and passes its generated `assert_return_*` contract.

# hyperliquid 0.2.0

## Conventions: align with the connector gold standard

* `StakingSummary$n_pending_withdrawals` is now typed `integer | NA`. The parser coalesces an absent `nPendingWithdrawals` field to `NA_integer_`, so the column's contract must admit `NA`; without it `assert_no_missing_values` would reject the parser's own output on a real response that omits the field.
* The `hyperliquid_shapes` block no longer carries `@genassert`/`@exportassert`. hyperliquid is a leaf connector: nothing internal calls a per-shape `assert_type_*()` validator and no downstream package validates against these shapes, so the ten exported `assert_type_*` validators are dropped and the `NAMESPACE` now exports zero `assert_*` symbols. Each shape is still enforced at the public boundary, expanded inline into each method's generated `assert_return_*`.
* `DESCRIPTION` now pins minimum versions in `Imports`/`Suggests` (`connectcore (>= 0.1.0)`, `roxyassert (>= 0.9.1)`) and the `Remotes` entries are source-only (the `@v0.1.0`/`@v0.9.1` refs are stripped), so the version floor is expressed once in the dependency fields rather than pinned to a moving tag.

# hyperliquid 0.1.1

## Transport: route the body through connectcore's raw-body funnel

* The connector now owns **no transport**. `hyperliquid_build_request()` is reduced to a thin serialise-and-delegate helper: it pre-serialises the (already body-signed) payload with `jsonlite::toJSON(..., auto_unbox = TRUE, null = "null")` and routes it through `connectcore::build_request()` with `body_format = "raw"`, which sends the bytes verbatim via `httr2::req_body_raw()`. The hand-rolled `httr2` request builder (`request()` / `req_url_path_append()` / `req_method()` / `req_body_raw()` / `req_timeout()` / `req_user_agent()` / `req_error()`) is removed. connectcore v0.1.0's `body_format = "raw"` makes this possible: it performs no `NULL`-pruning, no pretty-printing, and no re-encoding, and its `.sign` seam runs after the body is set — so the exact signed bytes reach the wire.
* This is an internal refactor with **zero behaviour change**: the wire bytes (especially the signed `/exchange` body) are byte-identical to before, including `vaultAddress`/`expiresAfter` serialised as JSON `null`. The signing vectors and the mock-router body assertions remain green.

# hyperliquid 0.1.0

## Transport: migrate to connectcore

* `HyperliquidBase` now **inherits `connectcore::RestClient`**, the shared transport base, for credential storage, the sync/async perform function, and the overridable `.parse_envelope()` error seam. The Hyperliquid two-failure-shape parser (`/info` HTTP 422 text, `/exchange` 200 `{status:"err"}`) is wired as the `.parse_envelope()` override. The `.sign()` request seam is left at its no-op default: Hyperliquid signs the **body** (a wallet signature embedded as a `signature` field), not the HTTP request.
* The duplicated `then_or_now()` (the single sync/async branch point) and `next_nonce()` (the monotonic epoch-millisecond nonce) now come from connectcore; the local copies were removed.
* `hyperliquid_build_request()` stays Hyperliquid-specific — the body-signed wire contract requires the exact signed JSON on the wire (including `vaultAddress`/`expiresAfter` as JSON `null`), so it keeps `req_body_raw()` rather than connectcore's request funnel — but it now delegates its sync/async branch to `connectcore::then_or_now()` and accepts an overridable `parse_envelope` seam.
* No public API change: every exported class, method, signature, and return shape is unchanged, and the full test suite passes.

# hyperliquid 0.0.1

Initial release: an R wrapper for the Hyperliquid decentralised exchange, covering perpetual and spot trading across both synchronous and asynchronous (promise-based) operations, with Ethereum wallet signing for the `/exchange` endpoint computed in pure R.

## Features

* **Market data** (`HyperliquidMarketData`, public, no auth): perp and spot metadata, per-asset contexts (mark/mid/oracle/funding/open-interest), all mids, the L2 order book, OHLCV candles, funding history and predicted fundings, builder-deployed perp dexes, recent trades, and exchange status.
* **Account** (`HyperliquidAccount`, public reads by address): positions and cross-margin summary, spot balances, open and frontend orders, fills (recent and by time), historical orders, funding and non-funding ledgers, portfolio value/PnL/volume, fee schedule, rate limit, role, sub-accounts, single-order status, and vault equities.
* **Trading** (`HyperliquidTrading`, signed): place / modify / cancel orders (single or bulk, by order id or client order id), market open and close, scheduled dead-man's-switch cancel, leverage and isolated-margin updates, and agent / builder-fee approvals.
* **Transfers** (`HyperliquidTransfers`, signed): spot/perp collateral class transfer, USDC and spot-token sends, bridge withdrawals, cross-dex sends, and sub-account and vault transfers.
* **Staking** (`HyperliquidStaking`): delegator summary, per-validator delegations, reward and full delegate/deposit/withdraw history, and the delegate / undelegate action.
* **Bulk backfill**: `hyperliquid_backfill_klines()` and `hyperliquid_backfill_funding()` walk history for many coins/intervals to a CSV, appending incrementally with resume. A bundled `hyperliquid_ohlcv` sample dataset ships daily candles for examples.
* **Sync and async**: every method works in both modes; `async = TRUE` returns a `promises::promise` resolving to the same `data.table`.

## Design

* Every public method returns a single flat `data.table` with no list columns; nested objects are flattened to scalar `snake_case` columns and heterogeneous rows are stacked with a discriminator column.
* The `/exchange` endpoint is authenticated by an Ethereum wallet signature (secp256k1 ECDSA, Keccak-256, EIP-712, and the msgpack action hash) implemented in pure R (`openssl` + `gmp`) with no compiled code, and verified byte-identical to the official Python and Rust SDK test vectors.
* All requests flow through a single funnel (`hyperliquid_build_request()`) with one sync/async branch point. The network is selected by an explicit `testnet` flag, never by URL sniffing, because it changes the signature itself.
* Inputs are validated with the `assert` package; times are handled in UTC via `lubridate`, and amounts are transmitted with exact precision.
