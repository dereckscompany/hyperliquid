# HyperliquidAccount: User-Scoped Account Reads

HyperliquidAccount: User-Scoped Account Reads

HyperliquidAccount: User-Scoped Account Reads

## Details

### Purpose

Reads the full state and history of one Hyperliquid account from the
`/info` endpoint: perp positions and margin summary, spot balances, open
orders (plain and frontend-detailed), fills, historical orders, funding
and non-funding ledgers, portfolio value/PnL/volume, fee schedule and
daily volume, request rate limit, account role, sub-accounts,
single-order status, and vault equities. Every method is unauthenticated
and needs no wallet key.

Inherits from
[HyperliquidBase](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction; in async mode each
returns a
[promises::promise](https://rstudio.github.io/promises/reference/promise.html)
resolving to the same
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html).

### Default address

Every read defaults `address` to the instance's acting address (vault,
then master account, then the key's own wallet). Pass `address`
explicitly to inspect any other account.

### Official Documentation

<https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/info-endpoint/perpetuals>

### Endpoints Covered

|                                     |                             |      |
|-------------------------------------|-----------------------------|------|
| Method                              | type                        | Auth |
| get_positions                       | clearinghouseState          | No   |
| get_margin_summary                  | clearinghouseState          | No   |
| get_spot_balances                   | spotClearinghouseState      | No   |
| get_open_orders                     | openOrders                  | No   |
| get_frontend_open_orders            | frontendOpenOrders          | No   |
| get_user_fills                      | userFills                   | No   |
| get_user_fills_by_time              | userFillsByTime             | No   |
| get_historical_orders               | historicalOrders            | No   |
| get_user_funding                    | userFunding                 | No   |
| get_user_non_funding_ledger_updates | userNonFundingLedgerUpdates | No   |
| get_portfolio                       | portfolio                   | No   |
| get_portfolio_volume                | portfolio                   | No   |
| get_user_fees                       | userFees                    | No   |
| get_user_volume                     | userFees                    | No   |
| get_user_rate_limit                 | userRateLimit               | No   |
| get_user_role                       | userRole                    | No   |
| get_sub_accounts                    | subAccounts                 | No   |
| get_order_status                    | orderStatus                 | No   |
| get_user_vault_equities             | userVaultEquities           | No   |

## Super class

[`hyperliquid::HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
-\> `HyperliquidAccount`

## Methods

### Public methods

- [`HyperliquidAccount$get_positions()`](#method-HyperliquidAccount-get_positions)

- [`HyperliquidAccount$get_margin_summary()`](#method-HyperliquidAccount-get_margin_summary)

- [`HyperliquidAccount$get_spot_balances()`](#method-HyperliquidAccount-get_spot_balances)

- [`HyperliquidAccount$get_open_orders()`](#method-HyperliquidAccount-get_open_orders)

- [`HyperliquidAccount$get_frontend_open_orders()`](#method-HyperliquidAccount-get_frontend_open_orders)

- [`HyperliquidAccount$get_user_fills()`](#method-HyperliquidAccount-get_user_fills)

- [`HyperliquidAccount$get_user_fills_by_time()`](#method-HyperliquidAccount-get_user_fills_by_time)

- [`HyperliquidAccount$get_historical_orders()`](#method-HyperliquidAccount-get_historical_orders)

- [`HyperliquidAccount$get_user_funding()`](#method-HyperliquidAccount-get_user_funding)

- [`HyperliquidAccount$get_user_non_funding_ledger_updates()`](#method-HyperliquidAccount-get_user_non_funding_ledger_updates)

- [`HyperliquidAccount$get_portfolio()`](#method-HyperliquidAccount-get_portfolio)

- [`HyperliquidAccount$get_portfolio_volume()`](#method-HyperliquidAccount-get_portfolio_volume)

- [`HyperliquidAccount$get_user_fees()`](#method-HyperliquidAccount-get_user_fees)

- [`HyperliquidAccount$get_user_volume()`](#method-HyperliquidAccount-get_user_volume)

- [`HyperliquidAccount$get_user_rate_limit()`](#method-HyperliquidAccount-get_user_rate_limit)

- [`HyperliquidAccount$get_user_role()`](#method-HyperliquidAccount-get_user_role)

- [`HyperliquidAccount$get_sub_accounts()`](#method-HyperliquidAccount-get_sub_accounts)

- [`HyperliquidAccount$get_order_status()`](#method-HyperliquidAccount-get_order_status)

- [`HyperliquidAccount$get_user_vault_equities()`](#method-HyperliquidAccount-get_user_vault_equities)

- [`HyperliquidAccount$clone()`](#method-HyperliquidAccount-clone)

Inherited methods

- [`hyperliquid::HyperliquidBase$initialize()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-initialize)
- [`hyperliquid::HyperliquidBase$name_to_asset()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_asset)
- [`hyperliquid::HyperliquidBase$name_to_coin()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_coin)
- [`hyperliquid::HyperliquidBase$refresh_meta()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-refresh_meta)
- [`hyperliquid::HyperliquidBase$sz_decimals()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-sz_decimals)

------------------------------------------------------------------------

### Method `get_positions()`

Retrieve the account's open perpetual positions, one row per position.

#### Usage

    HyperliquidAccount$get_positions(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<Position\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `coin`, `szi`, `entry_px`, `position_value`, `unrealized_pnl`,
`return_on_equity`, `leverage_type`, `leverage_value`, `liquidation_px`,
`margin_used`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_margin_summary()`

Retrieve the account's cross-margin summary. Sibling of get_positions(),
which parses the positions from the same payload.

#### Usage

    HyperliquidAccount$get_margin_summary(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<MarginSummary\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `account_value`, `total_ntl_pos`, `total_raw_usd`,
`total_margin_used`, `withdrawable`, `cross_account_value`,
`cross_total_ntl_pos`, `cross_total_raw_usd`, `cross_total_margin_used`,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_spot_balances()`

Retrieve the account's spot token balances, one row per balance.

#### Usage

    HyperliquidAccount$get_spot_balances(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `coin`, `total`, `hold`, `entry_ntl`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_open_orders()`

Retrieve the account's resting orders, one row per order.

#### Usage

    HyperliquidAccount$get_open_orders(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `coin`, `oid`, `side`, `limit_px`, `sz`, `timestamp`, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_frontend_open_orders()`

Retrieve the account's resting orders with the frontend's richer detail
(order type, trigger fields, reduce-only, tif). Sibling of
get_open_orders() with more columns.

#### Usage

    HyperliquidAccount$get_frontend_open_orders(
      address = private$.acting_address()
    )

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `coin`, `oid`, `side`, `limit_px`, `sz`, `timestamp`, `order_type`,
`is_trigger`, `trigger_px`, `trigger_condition`, `reduce_only`, `tif`,
`orig_sz`, `is_position_tpsl`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_fills()`

Retrieve the account's most recent fills (retention is the ~10,000
most-recent fills).

#### Usage

    HyperliquidAccount$get_user_fills(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<Fill\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `coin`, `px`, `sz`, `side`, `time`, `start_position`, `dir`,
`closed_pnl`, `hash`, `oid`, `crossed`, `fee`, `fee_token`, `tid`, or a
promise thereof.

------------------------------------------------------------------------

### Method `get_user_fills_by_time()`

Retrieve the account's fills within a time range (up to 2,000 per call),
same shape as get_user_fills().

#### Usage

    HyperliquidAccount$get_user_fills_by_time(
      address = private$.acting_address(),
      start,
      end = NULL,
      aggregate_by_time = FALSE
    )

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

- `start`:

  (POSIXct \| numeric) range start (POSIXct or numeric
  epoch-milliseconds).

- `end`:

  (POSIXct \| numeric \| NULL) range end (POSIXct, numeric
  epoch-milliseconds, or `NULL`). Default `NULL` (up to now).

- `aggregate_by_time`:

  (scalar\<logical\>) if `TRUE`, partial fills of one order at the same
  time are aggregated. Default `FALSE`.

#### Returns

(promise\<Fill\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with the same columns as get_user_fills(), or a promise thereof.

------------------------------------------------------------------------

### Method `get_historical_orders()`

Retrieve the account's historical orders, one row per status transition
(the same `oid` recurs across its lifecycle; not deduplicated).

#### Usage

    HyperliquidAccount$get_historical_orders(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `oid`, `coin`, `side`, `limit_px`, `sz`, `orig_sz`, `order_type`,
`tif`, `reduce_only`, `trigger_px`, `trigger_condition`, `is_trigger`,
`is_position_tpsl`, `cloid`, `timestamp`, `status`, `status_timestamp`,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_funding()`

Retrieve the account's funding-payment history within a time range, one
row per payment.

#### Usage

    HyperliquidAccount$get_user_funding(
      address = private$.acting_address(),
      start,
      end = NULL
    )

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

- `start`:

  (POSIXct \| numeric) range start (POSIXct or numeric
  epoch-milliseconds).

- `end`:

  (POSIXct \| numeric \| NULL) range end (POSIXct, numeric
  epoch-milliseconds, or `NULL`). Default `NULL` (up to now).

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `time`, `hash`, `coin`, `funding_rate`, `szi`, `usdc`, `n_samples`,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_non_funding_ledger_updates()`

Retrieve the account's non-funding ledger updates (deposits,
withdrawals, transfers, liquidations) within a time range. Heterogeneous
events stack with a `delta_type` discriminator.

#### Usage

    HyperliquidAccount$get_user_non_funding_ledger_updates(
      address = private$.acting_address(),
      start,
      end = NULL
    )

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

- `start`:

  (POSIXct \| numeric) range start (POSIXct or numeric
  epoch-milliseconds).

- `end`:

  (POSIXct \| numeric \| NULL) range end (POSIXct, numeric
  epoch-milliseconds, or `NULL`). Default `NULL` (up to now).

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
led by `time`, `hash`, `delta_type`, `usdc`, then the union of the
variants' fields, or a promise thereof.

------------------------------------------------------------------------

### Method `get_portfolio()`

Retrieve the account's portfolio value and PnL history, long: one row
per (period, metric, point).

#### Usage

    HyperliquidAccount$get_portfolio(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `period`, `metric`, `time`, `value`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_portfolio_volume()`

Retrieve the account's per-period traded volume. Sibling of
get_portfolio() over the same payload.

#### Usage

    HyperliquidAccount$get_portfolio_volume(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `period`, `vlm`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_fees()`

Retrieve the account's current fee schedule.

#### Usage

    HyperliquidAccount$get_user_fees(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `user_add_rate`, `user_cross_rate`, `active_referral_discount`, or
a promise thereof.

------------------------------------------------------------------------

### Method `get_user_volume()`

Retrieve the account's daily traded volume. Sibling of get_user_fees()
over the same payload.

#### Usage

    HyperliquidAccount$get_user_volume(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `date`, `exchange`, `user_add`, `user_cross`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_rate_limit()`

Retrieve the account's current request rate-limit state.

#### Usage

    HyperliquidAccount$get_user_rate_limit(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `cum_vlm`, `n_requests_used`, `n_requests_cap`, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_user_role()`

Retrieve the account's role (e.g. `"user"`, `"vault"`, `"agent"`,
`"subAccount"`).

#### Usage

    HyperliquidAccount$get_user_role(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `role`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_sub_accounts()`

Retrieve the account's sub-accounts (returns a zero-row table when the
account has none).

#### Usage

    HyperliquidAccount$get_sub_accounts(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `name`, `sub_account_user`, `master`, `account_value`,
`total_ntl_pos`, `total_raw_usd`, `total_margin_used`, `withdrawable`,
or a promise thereof.

------------------------------------------------------------------------

### Method `get_order_status()`

Retrieve the status of a single order by its order id or client order
id.

#### Usage

    HyperliquidAccount$get_order_status(
      address = private$.acting_address(),
      oid_or_cloid
    )

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

- `oid_or_cloid`:

  (scalar\<numeric\> \| scalar\<character\>) numeric order id, or
  character `0x`-prefixed client order id (cloid).

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `query_status` and the order shape (`oid`, `coin`, `side`, ...,
`status`, `status_timestamp`), or a promise thereof.

------------------------------------------------------------------------

### Method `get_user_vault_equities()`

Retrieve the account's equity in each vault it has deposited into, one
row per vault.

#### Usage

    HyperliquidAccount$get_user_vault_equities(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the account's `0x`-prefixed address. Defaults to
  the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `vault_address`, `equity`, `locked_until_timestamp`, or a promise
thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidAccount$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
account <- HyperliquidAccount$new()
addr <- "0x010461c14e146ac35fe42271bdc1134ee31c703a"
account$get_positions(addr)
account$get_margin_summary(addr)
account$get_user_fills_by_time(addr, start = lubridate::now("UTC") - lubridate::days(1))
} # }
```
