# Changelog

## hyperliquid 0.7.0

A lossless raw accessor for funding history, alongside the typed
surface, for byte-faithful bronze archival.

In plain English: the typed `data.table` methods are the right default
for analysis, but a raw-data archive wants the exchange’s own records
untouched — the exact decimal strings it sent, in its own field order.
Hyperliquid reports a funding rate and premium as strings
(e.g. `"0.0000034197"`) and the settlement time as a raw
epoch-millisecond number; the typed `get_funding_history()` converts
those to doubles and a POSIXct and snake_cases the names, which is right
for analysis but not for an archive that must keep exactly what the
venue sent. This release adds a raw sibling for the funding surface the
scraper’s `hyperliquid-funding` collector archives, so the archive
stores Hyperliquid’s own bytes and the tidy table stays the analysis
convenience.

- `get_funding_history_raw()`: the parsed JSON array exactly as
  Hyperliquid returns it — one named list per settlement
  `{ coin, fundingRate, premium, time }`, in venue order,
  `fundingRate`/`premium` kept as the venue’s decimal STRINGS (no float
  coercion, no precision loss) and `time` kept as the raw
  epoch-millisecond number, a JSON `null` kept distinct from an absent
  field. The typed `get_funding_history()` is unchanged.
- The raw method carries a roxyassert `(promise<list>)` contract and
  threads sync/async from the constructor exactly like its typed
  sibling. End-to-end mock-router tests cover both the losslessness
  (strings, field order, raw time preserved) and sync/async parity,
  against the existing funding fixture.
- Universe discovery needs no raw sibling: the typed `get_meta()`
  already exposes every perp `name` (delisted included) faithfully, and
  meta is derived-for-discovery, never archived as bronze.

## hyperliquid 0.6.0

### Opt-in request retry at construction (`max_tries`), gated on path idempotency

Every client class constructor (via `HyperliquidBase`) gains a
`max_tries` argument (`scalar<integer in [1, 10]>`, default `1` = no
retry) threaded to `connectcore`’s retry machinery. Hyperliquid is
unusual: its **entire API is POST** — both `/info` (reads) and
`/exchange` (writes) — so a plain GET-only carve-out would make retry
inert. Instead the retry decision is by **idempotency of the path**:
[`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)
marks `/info` idempotent (its query is encoded in the body, so it is
safe to re-send) and `/exchange` non-idempotent (a write), hardcoded per
path and never caller-choosable. `max_tries > 1` therefore retries a
transient `/info` failure (HTTP 408/429/5xx or a dropped connection)
with jittered backoff, while an `/exchange` write is performed exactly
once regardless of `max_tries`, so an order or cancel can never be
silently resent and double-submitted. The default `1` leaves
live-trading behaviour unchanged — the trader layer stays the single
retry authority there; raise `max_tries` only for research and backfill
reads. Requires `connectcore (>= 0.5.0)`, whose `build_request()` gained
the explicit per-request `idempotent` flag this relies on.

## hyperliquid 0.5.0

### Typed input-validation and wire-encoding conditions (the non-transport taxonomy)

- The connector’s 37 non-transport
  [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html) sites
  now signal **classed conditions** instead of bare strings, so a caller
  branches on error *type* instead of grepping the message text. This
  completes the taxonomy alongside the request funnel’s typed transport
  conditions.
- Two domain subclasses, both rooted at `hyperliquid_error` (the
  connector’s DOMAIN root, parallel to the transport `connectcore_error`
  root — a non-transport failure is not a transport failure, so the two
  roots never meet, exactly the `core_error` / `connectcore_error`
  split): `hyperliquid_validation_error` (20 sites: a method’s argument,
  parameter, or credential setup is malformed — a bad address / coin /
  interval / side / cloid, a missing wallet key, an unknown coin or
  asset id, a non-finite amount) via a new
  `abort_hyperliquid_validation_error()`; and
  `hyperliquid_encoding_error` (17 sites: a value that cannot be
  serialised to the venue’s wire format — the msgpack encoder rejecting
  an unrepresentable integer, over-long string, non-finite or
  unsupported value, or a float-to-wire conversion that would silently
  round the order) via a new `abort_hyperliquid_encoding_error()`. Catch
  either subclass specifically, or `hyperliquid_error` for any
  non-transport failure.
- The message strings are **byte-identical** to the bare
  [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html) calls
  they replaced (a reverse-substitution proves all 37 reproduce master
  exactly; golden tests pin a representative site per subclass), so
  existing tests and downstream message greps keep matching. The classes
  are purely additive;
  [`conditionMessage()`](https://rdrr.io/r/base/conditions.html) and
  `inherits(e, "error")` are unchanged. No behaviour changes.
- Follows the org convention (dereckscompany/tradebot-core#30;
  discussion “throw typed errors, not bare strings”). The transport/API
  funnel (`abort_hyperliquid_error` /
  `abort_hyperliquid_exchange_error`, rooted at `connectcore_error`) is
  untouched.

## hyperliquid 0.4.0

### Typed API-error conditions

- Both failure surfaces of the request funnel
  (`parse_hyperliquid_response()`) now signal a **classed condition**
  instead of a bare
  [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html), so a
  caller branches on error *type* and reads structured *fields* rather
  than grepping the message text. The `/info` malformed-body surface (a
  non-2xx HTTP status) raises `abort_hyperliquid_error()`, classed
  specific -\> general: `hyperliquid_api_error_<status>`,
  `hyperliquid_api_error`, then the inherited connectcore family
  `connectcore_api_error_<status>` / `connectcore_api_error` /
  `connectcore_error`, carrying `status` (integer), `url` (credentials
  redacted), and `body_snippet`.
- The `/exchange` surface is different: Hyperliquid returns HTTP **200**
  even on failure, with `{status:"err", response:"<string>"}`. This now
  raises `abort_hyperliquid_exchange_error()`, which adds a distinct
  `hyperliquid_exchange_error` class at the front of the family so a
  caller can single it out. Because the 200 status is meaningless for
  this surface it is **no-status**: it carries neither a per-status
  class nor a `status` field, and instead carries the exchange
  `response` string (plus `url` and `body_snippet`). Its full class
  vector is
  `c("hyperliquid_exchange_error", "hyperliquid_api_error", "connectcore_api_error", "connectcore_error")`,
  so `hyperliquid_api_error` / `connectcore_api_error` /
  `connectcore_error` still catch it.
- The message strings are **byte-identical** to the previous
  `"Hyperliquid HTTP error <status>\n<body>"` and
  `"Hyperliquid exchange error: <response>"`, so existing tests and
  downstream message greps keep matching. The classes and fields are
  purely additive.
- This follows the connector-subclass recipe documented in connectcore
  0.4.0 (`?connectcore_conditions`); the floor is bumped to
  `connectcore (>= 0.4.0)`.

## hyperliquid 0.3.1

### Feature: `as_cloid()` / `is_cloid()` map any client tag to a venue-valid cloid

- Hyperliquid’s client order id (`cloid`) must be a `0x`-prefixed
  32-hex-character (16-byte) string, so a trader’s free-form idempotency
  id is silently rejected by the venue.
  [`as_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/as_cloid.md)
  maps any character tag deterministically onto a valid cloid — an
  already-valid cloid passes through lowercased, and any other tag
  becomes `"0x"` plus the first 16 bytes of its SHA-256 digest — so the
  same logical id always yields the same cloid and idempotency is
  preserved (collisions are negligible at 128 bits).
  [`is_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/is_cloid.md)
  is the vectorised, non-aborting predicate for the same format (`NA`
  in, `NA` out), useful as a boundary guard or filter. The hash step is
  one-way: recover the original tag by lookup against
  [`as_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/as_cloid.md)
  of your candidate ids, not by decoding, so there is deliberately no
  `cloid_decode()`. The `cloid` regex now lives once in an internal
  `CLOID_PATTERN` constant shared with the order-boundary validator.
  Closes [\#2](https://github.com/dereckscompany/hyperliquid/issues/2).

## hyperliquid 0.3.0

### Breaking: spelled-out argument names on the trading and account signatures

- The abbreviated argument names on the public trading and account
  methods are spelled out fleet-wide (`CONNECTOR-CONVENTIONS.md` I.1.5):
  `sz` becomes `size`, `limit_px` becomes `limit_price`, `trigger_px`
  becomes `trigger_price`, `cloid` becomes `client_order_id`, `oid`
  becomes `order_id`, and `get_order_status()`’s `oid_or_cloid` becomes
  `order_id_or_client_order_id`. This affects `place_order()`,
  `market_open()`, `market_close()`, `modify_order()`, `cancel_order()`,
  `cancel_by_cloid()`, and `get_order_status()`. It is a clean break
  with no deprecation shims. The venue wire keys are unchanged: an R
  `size` argument is still serialised to the `sz` order field on the
  wire, and the returned data.tables keep their venue-native column
  names (`sz`, `oid`, `limit_px`, `cloid`, `trigger_px`), which are a
  separate vocabulary from the R argument names. The
  `cancel_by_cloid()`/`bulk_cancel_by_cloid()` method names and the
  power-user order/cancel-spec list field names (`sz`, `limit_px`,
  `cloid`, `oid` inside the `orders`/`modifies`/`cancels` payload maps)
  mirror the venue’s own vocabulary and are retained.

### Internal: `ms_to_datetime()` imported from connectcore

- The local `ms_to_datetime()` re-implementation is dropped in favour of
  the canonical, length-preserving, NA-in-NA-out
  [`connectcore::ms_to_datetime()`](https://dereckscompany.github.io/connectcore/reference/ms_to_datetime.html)
  (connectcore \>= 0.3.0), matching the fleet-wide centralisation.
  Behaviour is unchanged: epoch-millisecond timestamps still convert to
  POSIXct in UTC.

### Documentation: typed nested column bullets on every data.table return

- Every multi-row data.table `@return` on the market-data, account,
  trading, and staking clients is documented as typed nested column
  bullets (bare column name, composite type token, `| NA` where a column
  may be missing) rather than prose, closing the last
  documentation-consistency gap against the fleet convention.

### Dependencies

- `connectcore` floors at `>= 0.3.0` (for `ms_to_datetime()`); explicit
  Imports floors added for `assert` (`>= 0.0.9`) and `ethsign`
  (`>= 0.0.2`). Remotes stay bare per the ratified floors-in-Imports
  policy, and `renv.lock` is refreshed (connectcore 0.3.0, htmltools
  0.5.9) so the CI environment restores cleanly.

## hyperliquid 0.2.1

### Hardening: validate fixtures and contracts against the real testnet API

- Added `dev/capture-hyperliquid.R`, a read-only capture harness that
  hits the real Hyperliquid API and writes each raw `/info` response
  verbatim to the git-ignored `local/raw-data/hyperliquid/`. Hyperliquid
  is body-routed, so reads are `POST /info` discriminated by
  `body$type`; the harness issues only those reads (it never touches the
  signed-write `/exchange` endpoint, never signs anything, and uses only
  the public account address), then summarises each endpoint as
  POPULATED / EMPTY / FAIL. All 32 read endpoints were captured against
  testnet with zero failures, and every committed fixture’s structure
  was validated against its live counterpart: the parsers parse the real
  responses cleanly, and the only divergences are additive API fields
  (e.g. `marginTables`, `feeSchedule`, `isDelisted`) that no parser
  consumes, so no fixture enrichment was required.

### Fixes: empty-collection responses violated their own column contracts

- `get_positions()` raised a contract error on a **flat account** (no
  open positions). The live capture reproduced this: `parse_positions()`
  returned a bare zero-column `data.table` on an empty `assetPositions`,
  but the `@return` contract requires the ten position columns. The
  empty branch now returns the typed zero-row schema (a zero-row typed
  column satisfies `assert_no_missing_values`), so a flat account parses
  cleanly. The synthetic fixture hid the bug because it always carried
  two open positions.
- The same empty-collection defect was fixed in `parse_margin_summary()`
  (an address that never deposited), `parse_user_fills()` /
  `get_user_fills()` / `get_user_fills_by_time()` (an account that never
  traded), `parse_funding_history()` (a coin/window with no funding
  events), and `parse_candles()` (an empty candle window): each empty
  branch now returns the typed zero-row schema its `@return` contract
  documents, instead of a column-less `data.table`. Regression tests
  assert the empty parser output carries the full column set and passes
  its generated `assert_return_*` contract.
- A completeness pass over every parser caught four more strict-contract
  endpoints with the identical defect, fixed the same way:
  `parse_meta()` (an empty perp universe), `parse_l2_book()` (an empty
  order-book side), `parse_staking_summary()` (an address that never
  staked), and `parse_token_delegate()` (an empty delegate envelope) now
  each return their documented typed zero-row schema instead of a
  column-less `data.table`, with regression tests on all four.

### Convention: every empty branch returns a typed zero-row table

- Every endpoint parser’s empty branch now returns its typed zero-row
  schema (all columns present, correctly typed), never a column-less
  `data.table()`. This extends the typed-empty guarantee beyond the
  strict-contract endpoints to the ones whose `@return` did not strictly
  require columns (`get_spot_balances()`, `get_open_orders()`,
  `get_recent_trades()`, the portfolio / fees / sub-account / staking
  reads, …): an empty live response now returns a stable, fully-typed
  table everywhere. Each empty closes with `[]` so it prints on the
  first call, and timestamp columns use the same `ms_to_datetime()`
  coercion the parsers apply so an empty column’s class and tz match a
  populated one.
- Most shapes are used in a single parser, so they are inlined at the
  branch rather than wrapped in a helper. Only the two shapes genuinely
  reused across more than one function are extracted as `empty_dt_*`
  constructors in `R/helpers_parse.R`: `empty_dt_candles()` (the candle
  parser plus both kline fetchers) and `empty_dt_funding_history()` (the
  funding parser plus the funding backfill). The three order parsers
  (`frontendOpenOrders`, `historicalOrders`, `orderStatus`) build their
  empty from the existing `flatten_order()` helper rather than restating
  the order columns, and the parsers that had two empty branches now
  have one (the pre-loop null check was redundant — a loop over `NULL`
  yields no rows). The schema-agnostic flattening primitives
  (`as_dt_row()`, `as_dt_list()`, `parse_delta_ledger()`) have no fixed
  column set and keep their bare empty; the discriminated-ledger parsers
  contribute only their always-present lead columns. A
  `test-empty-constructors.R` guard exercises every parser’s empty
  branch and asserts none is column-less.

## hyperliquid 0.2.0

### Conventions: align with the connector gold standard

- `StakingSummary$n_pending_withdrawals` is now typed `integer | NA`.
  The parser coalesces an absent `nPendingWithdrawals` field to
  `NA_integer_`, so the column’s contract must admit `NA`; without it
  `assert_no_missing_values` would reject the parser’s own output on a
  real response that omits the field.
- The `hyperliquid_shapes` block no longer carries
  `@genassert`/`@exportassert`. hyperliquid is a leaf connector: nothing
  internal calls a per-shape `assert_type_*()` validator and no
  downstream package validates against these shapes, so the ten exported
  `assert_type_*` validators are dropped and the `NAMESPACE` now exports
  zero `assert_*` symbols. Each shape is still enforced at the public
  boundary, expanded inline into each method’s generated
  `assert_return_*`.
- `DESCRIPTION` now pins minimum versions in `Imports`/`Suggests`
  (`connectcore (>= 0.1.0)`, `roxyassert (>= 0.9.1)`) and the `Remotes`
  entries are source-only (the `@v0.1.0`/`@v0.9.1` refs are stripped),
  so the version floor is expressed once in the dependency fields rather
  than pinned to a moving tag.

## hyperliquid 0.1.1

### Transport: route the body through connectcore’s raw-body funnel

- The connector now owns **no transport**.
  [`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)
  is reduced to a thin serialise-and-delegate helper: it pre-serialises
  the (already body-signed) payload with
  `jsonlite::toJSON(..., auto_unbox = TRUE, null = "null")` and routes
  it through
  [`connectcore::build_request()`](https://dereckscompany.github.io/connectcore/reference/build_request.html)
  with `body_format = "raw"`, which sends the bytes verbatim via
  [`httr2::req_body_raw()`](https://httr2.r-lib.org/reference/req_body.html).
  The hand-rolled `httr2` request builder (`request()` /
  `req_url_path_append()` / `req_method()` / `req_body_raw()` /
  `req_timeout()` / `req_user_agent()` / `req_error()`) is removed.
  connectcore v0.1.0’s `body_format = "raw"` makes this possible: it
  performs no `NULL`-pruning, no pretty-printing, and no re-encoding,
  and its `.sign` seam runs after the body is set — so the exact signed
  bytes reach the wire.
- This is an internal refactor with **zero behaviour change**: the wire
  bytes (especially the signed `/exchange` body) are byte-identical to
  before, including `vaultAddress`/`expiresAfter` serialised as JSON
  `null`. The signing vectors and the mock-router body assertions remain
  green.

## hyperliquid 0.1.0

### Transport: migrate to connectcore

- `HyperliquidBase` now **inherits
  [`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)**,
  the shared transport base, for credential storage, the sync/async
  perform function, and the overridable `.parse_envelope()` error seam.
  The Hyperliquid two-failure-shape parser (`/info` HTTP 422 text,
  `/exchange` 200 `{status:"err"}`) is wired as the `.parse_envelope()`
  override. The `.sign()` request seam is left at its no-op default:
  Hyperliquid signs the **body** (a wallet signature embedded as a
  `signature` field), not the HTTP request.
- The duplicated `then_or_now()` (the single sync/async branch point)
  and `next_nonce()` (the monotonic epoch-millisecond nonce) now come
  from connectcore; the local copies were removed.
- [`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)
  stays Hyperliquid-specific — the body-signed wire contract requires
  the exact signed JSON on the wire (including
  `vaultAddress`/`expiresAfter` as JSON `null`), so it keeps
  `req_body_raw()` rather than connectcore’s request funnel — but it now
  delegates its sync/async branch to
  [`connectcore::then_or_now()`](https://dereckscompany.github.io/connectcore/reference/then_or_now.html)
  and accepts an overridable `parse_envelope` seam.
- No public API change: every exported class, method, signature, and
  return shape is unchanged, and the full test suite passes.

## hyperliquid 0.0.1

Initial release: an R wrapper for the Hyperliquid decentralised
exchange, covering perpetual and spot trading across both synchronous
and asynchronous (promise-based) operations, with Ethereum wallet
signing for the `/exchange` endpoint computed in pure R.

### Features

- **Market data** (`HyperliquidMarketData`, public, no auth): perp and
  spot metadata, per-asset contexts
  (mark/mid/oracle/funding/open-interest), all mids, the L2 order book,
  OHLCV candles, funding history and predicted fundings,
  builder-deployed perp dexes, recent trades, and exchange status.
- **Account** (`HyperliquidAccount`, public reads by address): positions
  and cross-margin summary, spot balances, open and frontend orders,
  fills (recent and by time), historical orders, funding and non-funding
  ledgers, portfolio value/PnL/volume, fee schedule, rate limit, role,
  sub-accounts, single-order status, and vault equities.
- **Trading** (`HyperliquidTrading`, signed): place / modify / cancel
  orders (single or bulk, by order id or client order id), market open
  and close, scheduled dead-man’s-switch cancel, leverage and
  isolated-margin updates, and agent / builder-fee approvals.
- **Transfers** (`HyperliquidTransfers`, signed): spot/perp collateral
  class transfer, USDC and spot-token sends, bridge withdrawals,
  cross-dex sends, and sub-account and vault transfers.
- **Staking** (`HyperliquidStaking`): delegator summary, per-validator
  delegations, reward and full delegate/deposit/withdraw history, and
  the delegate / undelegate action.
- **Bulk backfill**:
  [`hyperliquid_backfill_klines()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_klines.md)
  and
  [`hyperliquid_backfill_funding()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_funding.md)
  walk history for many coins/intervals to a CSV, appending
  incrementally with resume. A bundled `hyperliquid_ohlcv` sample
  dataset ships daily candles for examples.
- **Sync and async**: every method works in both modes; `async = TRUE`
  returns a
  [`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
  resolving to the same `data.table`.

### Design

- Every public method returns a single flat `data.table` with no list
  columns; nested objects are flattened to scalar `snake_case` columns
  and heterogeneous rows are stacked with a discriminator column.
- The `/exchange` endpoint is authenticated by an Ethereum wallet
  signature (secp256k1 ECDSA, Keccak-256, EIP-712, and the msgpack
  action hash) implemented in pure R (`openssl` + `gmp`) with no
  compiled code, and verified byte-identical to the official Python and
  Rust SDK test vectors.
- All requests flow through a single funnel
  ([`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md))
  with one sync/async branch point. The network is selected by an
  explicit `testnet` flag, never by URL sniffing, because it changes the
  signature itself.
- Inputs are validated with the `assert` package; times are handled in
  UTC via `lubridate`, and amounts are transmitted with exact precision.
