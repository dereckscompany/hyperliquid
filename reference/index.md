# Package index

## API Client Classes

R6 classes for interacting with the Hyperliquid API

- [`HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
  : HyperliquidBase: Abstract Base Class for Hyperliquid API Clients
- [`HyperliquidMarketData`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidMarketData.md)
  : HyperliquidMarketData: Public Market Data Retrieval
- [`HyperliquidAccount`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidAccount.md)
  : HyperliquidAccount: User-Scoped Account Reads
- [`HyperliquidTrading`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidTrading.md)
  : HyperliquidTrading: Order Placement, Cancellation, and Account
  Controls
- [`HyperliquidTransfers`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidTransfers.md)
  : HyperliquidTransfers: Collateral Movement, Sends, and Withdrawals
- [`HyperliquidStaking`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidStaking.md)
  : HyperliquidStaking: Native-Token Staking and Delegation

## Configuration

Wallet credential, endpoint, and client-order-id helpers

- [`get_api_keys()`](https://dereckscompany.github.io/hyperliquid/reference/get_api_keys.md)
  : Retrieve Hyperliquid Wallet Credentials
- [`get_base_url()`](https://dereckscompany.github.io/hyperliquid/reference/get_base_url.md)
  : Retrieve the Hyperliquid REST Base URL
- [`new_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/new_cloid.md)
  : Generate a Client Order Id (cloid)

## Low-Level Request

The single funnel through which all Hyperliquid API calls flow

- [`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)
  : Build and Execute a Hyperliquid API Request

## Backfill and Data

Bulk historical download and the included dataset

- [`hyperliquid_backfill_klines()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_klines.md)
  : Backfill Hyperliquid Candle (OHLCV) Data to CSV
- [`hyperliquid_backfill_funding()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_backfill_funding.md)
  : Backfill Hyperliquid Funding-Rate History to CSV
- [`hyperliquid_ohlcv`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_ohlcv.md)
  : Daily OHLCV Sample Data from Hyperliquid

## Utilities

Time conversion helpers and interval constants

- [`time_convert_from_hyperliquid()`](https://dereckscompany.github.io/hyperliquid/reference/time_convert_from_hyperliquid.md)
  : Convert a Hyperliquid Timestamp to POSIXct
- [`time_convert_to_hyperliquid()`](https://dereckscompany.github.io/hyperliquid/reference/time_convert_to_hyperliquid.md)
  : Convert a POSIXct to a Hyperliquid Timestamp
- [`HYPERLIQUID_INTERVALS`](https://dereckscompany.github.io/hyperliquid/reference/HYPERLIQUID_INTERVALS.md)
  : Hyperliquid Candle Intervals

## Return Shapes

The data.table shape every method returns

- [`hyperliquid_shapes`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_shapes.md)
  : Hyperliquid return shapes
