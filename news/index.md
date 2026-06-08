# Changelog

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
