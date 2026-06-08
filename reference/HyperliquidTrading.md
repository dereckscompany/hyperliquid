# HyperliquidTrading: Order Placement, Cancellation, and Account Controls

HyperliquidTrading: Order Placement, Cancellation, and Account Controls

HyperliquidTrading: Order Placement, Cancellation, and Account Controls

## Details

### Purpose

Signed `/exchange` trading actions: place and modify limit/trigger
orders (single or bulk), open and close positions at market via an
aggressive immediate-or-cancel limit, cancel by order id or client order
id (single or bulk), schedule a dead-man's-switch cancel-all, set
per-asset leverage and isolated margin, and approve an agent (API)
wallet or a builder fee. Every method requires a wallet signing key.

Inherits from
[HyperliquidBase](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md).
Order/cancel actions are **L1** actions hashed and signed over the
Exchange domain (asset ids and key insertion order are part of the
signature, so both are reproduced exactly). The two approvals are
**user-signed** actions over the `HyperliquidSignTransaction` EIP-712
domain.

### Sync vs Async

Most methods support both modes via the `async` argument at
construction. The exceptions are market_open() and market_close(): they
chain a read (the mid price, and for closes the open position) before
the write, so they are **sync-preferred** and assume the chained `/info`
read resolves synchronously.

### Official Documentation

<https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/exchange-endpoint>

### Endpoints Covered

|                        |                      |      |
|------------------------|----------------------|------|
| Method                 | type                 | Auth |
| place_order            | order                | Yes  |
| bulk_orders            | order                | Yes  |
| market_open            | order                | Yes  |
| market_close           | order                | Yes  |
| modify_order           | batchModify          | Yes  |
| bulk_modify            | batchModify          | Yes  |
| cancel_order           | cancel               | Yes  |
| bulk_cancel            | cancel               | Yes  |
| cancel_by_cloid        | cancelByCloid        | Yes  |
| bulk_cancel_by_cloid   | cancelByCloid        | Yes  |
| schedule_cancel        | scheduleCancel       | Yes  |
| update_leverage        | updateLeverage       | Yes  |
| update_isolated_margin | updateIsolatedMargin | Yes  |
| approve_agent          | approveAgent         | Yes  |
| approve_builder_fee    | approveBuilderFee    | Yes  |

## Super class

[`hyperliquid::HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
-\> `HyperliquidTrading`

## Methods

### Public methods

- [`HyperliquidTrading$place_order()`](#method-HyperliquidTrading-place_order)

- [`HyperliquidTrading$bulk_orders()`](#method-HyperliquidTrading-bulk_orders)

- [`HyperliquidTrading$market_open()`](#method-HyperliquidTrading-market_open)

- [`HyperliquidTrading$market_close()`](#method-HyperliquidTrading-market_close)

- [`HyperliquidTrading$modify_order()`](#method-HyperliquidTrading-modify_order)

- [`HyperliquidTrading$bulk_modify()`](#method-HyperliquidTrading-bulk_modify)

- [`HyperliquidTrading$cancel_order()`](#method-HyperliquidTrading-cancel_order)

- [`HyperliquidTrading$cancel_by_cloid()`](#method-HyperliquidTrading-cancel_by_cloid)

- [`HyperliquidTrading$bulk_cancel()`](#method-HyperliquidTrading-bulk_cancel)

- [`HyperliquidTrading$bulk_cancel_by_cloid()`](#method-HyperliquidTrading-bulk_cancel_by_cloid)

- [`HyperliquidTrading$schedule_cancel()`](#method-HyperliquidTrading-schedule_cancel)

- [`HyperliquidTrading$update_leverage()`](#method-HyperliquidTrading-update_leverage)

- [`HyperliquidTrading$update_isolated_margin()`](#method-HyperliquidTrading-update_isolated_margin)

- [`HyperliquidTrading$approve_agent()`](#method-HyperliquidTrading-approve_agent)

- [`HyperliquidTrading$approve_builder_fee()`](#method-HyperliquidTrading-approve_builder_fee)

- [`HyperliquidTrading$clone()`](#method-HyperliquidTrading-clone)

Inherited methods

- [`hyperliquid::HyperliquidBase$initialize()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-initialize)
- [`hyperliquid::HyperliquidBase$name_to_asset()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_asset)
- [`hyperliquid::HyperliquidBase$name_to_coin()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_coin)
- [`hyperliquid::HyperliquidBase$refresh_meta()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-refresh_meta)
- [`hyperliquid::HyperliquidBase$sz_decimals()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-sz_decimals)

------------------------------------------------------------------------

### Method `place_order()`

Place a single order. A thin wrapper over bulk_orders(). Builder fees
are never applied automatically: a `builder` is attached only when you
pass one explicitly.

#### Usage

    HyperliquidTrading$place_order(
      name,
      is_buy,
      sz,
      limit_px,
      order_type,
      reduce_only = FALSE,
      cloid = NULL,
      builder = NULL
    )

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name, e.g. `"BTC"`.

- `is_buy`:

  (scalar\<logical\>) `TRUE` for a bid, `FALSE` for an ask.

- `sz`:

  (scalar\<numeric in \]0, Inf\[\>) the order size in coin units.

- `limit_px`:

  (scalar\<numeric in \]0, Inf\[\>) the limit price.

- `order_type`:

  (list) either `list(limit = list(tif = "Gtc"|"Ioc"|"Alo"))` or
  `list(trigger = list(triggerPx = , isMarket = , tpsl = "tp"|"sl"))`.

- `reduce_only`:

  (scalar\<logical\>) `TRUE` to only reduce an existing position.
  Default `FALSE`.

- `cloid`:

  (scalar\<character\> \| NULL) an optional client order id from
  [`new_cloid()`](https://dereckscompany.github.io/hyperliquid/reference/new_cloid.md).
  Default `NULL`.

- `builder`:

  (list?) an optional builder fee spec
  `list(b = <address>, f = <tenths-of-bps>)`. Default `NULL`.

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status, or a promise thereof.

------------------------------------------------------------------------

### Method `bulk_orders()`

Place a batch of orders in one signed action. Each order is validated,
its coin resolved to an asset id, and converted to its wire shape; the
wires are assembled into one `order` action.

#### Usage

    HyperliquidTrading$bulk_orders(orders, builder = NULL, grouping = "na")

#### Arguments

- `orders`:

  (list) unnamed list of order specs; each a named list with `coin`,
  `is_buy`, `sz`, `limit_px`, `order_type`, `reduce_only`, and optional
  `cloid` (same fields as place_order()).

- `builder`:

  (list?) an optional builder fee spec
  `list(b = <address>, f = <tenths-of-bps>)`. The address is lowercased.
  Default `NULL`.

- `grouping`:

  (scalar\<character\>) one of `"na"`, `"normalTpsl"`, `"positionTpsl"`.
  Default `"na"`.

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status, or a promise thereof.

------------------------------------------------------------------------

### Method `market_open()`

Open a position at market: read the current mid, compute an aggressive
immediate-or-cancel limit price `mid * (1 +/- slippage)`, and submit it.
Sync-preferred: it chains a mid-price read before the write.

#### Usage

    HyperliquidTrading$market_open(
      name,
      is_buy,
      sz,
      slippage = 0.05,
      cloid = NULL,
      builder = NULL
    )

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name, e.g. `"BTC"`.

- `is_buy`:

  (scalar\<logical\>) `TRUE` to open long, `FALSE` to open short.

- `sz`:

  (scalar\<numeric in \]0, Inf\[\>) the order size in coin units.

- `slippage`:

  (scalar\<numeric in \]0, Inf\[\>) the price tolerance fraction.
  Default `0.05` (5%).

- `cloid`:

  (scalar\<character\> \| NULL) an optional client order id. Default
  `NULL`.

- `builder`:

  (list?) an optional builder fee spec. Default `NULL`.

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status.

------------------------------------------------------------------------

### Method `market_close()`

Close a position at market: read the open position to find its signed
size, take the opposite side, and submit a reduce-only aggressive
immediate-or-cancel limit. Sync-preferred: it chains the position read
and a mid-price read before the write.

#### Usage

    HyperliquidTrading$market_close(name, sz = NULL, slippage = 0.05, cloid = NULL)

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name, e.g. `"BTC"`.

- `sz`:

  (scalar\<numeric in \]0, Inf\[\> \| NULL) the size to close. `NULL`
  (default) closes the whole position (`abs(szi)`).

- `slippage`:

  (scalar\<numeric in \]0, Inf\[\>) the price tolerance fraction.
  Default `0.05` (5%).

- `cloid`:

  (scalar\<character\> \| NULL) an optional client order id. Default
  `NULL`.

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status.

------------------------------------------------------------------------

### Method `modify_order()`

Modify a single resting order in place. A thin wrapper over
bulk_modify().

#### Usage

    HyperliquidTrading$modify_order(
      oid,
      name,
      is_buy,
      sz,
      limit_px,
      order_type,
      reduce_only = FALSE,
      cloid = NULL
    )

#### Arguments

- `oid`:

  (scalar\<numeric\>) the resting order's id (oid).

- `name`:

  (scalar\<character\>) the coin or friendly name.

- `is_buy`:

  (scalar\<logical\>) the (possibly new) side.

- `sz`:

  (scalar\<numeric in \]0, Inf\[\>) the (possibly new) size.

- `limit_px`:

  (scalar\<numeric in \]0, Inf\[\>) the (possibly new) price.

- `order_type`:

  (list) the order type (see place_order()).

- `reduce_only`:

  (scalar\<logical\>) default `FALSE`.

- `cloid`:

  (scalar\<character\> \| NULL) an optional client order id. Default
  `NULL`.

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status, or a promise thereof.

------------------------------------------------------------------------

### Method `bulk_modify()`

Modify a batch of resting orders in one signed `batchModify` action.

#### Usage

    HyperliquidTrading$bulk_modify(modifies)

#### Arguments

- `modifies`:

  (list) unnamed list of modify specs; each a named list with `oid`
  (numeric) and `order` (an order spec, see place_order()).

#### Returns

(promise\<OrderResult\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per status, or a promise thereof.

------------------------------------------------------------------------

### Method `cancel_order()`

Cancel a single order by its order id. A thin wrapper over
bulk_cancel().

#### Usage

    HyperliquidTrading$cancel_order(name, oid)

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name.

- `oid`:

  (scalar\<numeric\>) the order id to cancel.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per cancel, or a promise thereof.

------------------------------------------------------------------------

### Method `cancel_by_cloid()`

Cancel a single order by its client order id. A thin wrapper over
bulk_cancel_by_cloid().

#### Usage

    HyperliquidTrading$cancel_by_cloid(name, cloid)

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name.

- `cloid`:

  (scalar\<character\>) the client order id (`0x`-prefixed 32 hex
  chars).

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per cancel, or a promise thereof.

------------------------------------------------------------------------

### Method `bulk_cancel()`

Cancel a batch of orders by order id in one signed `cancel` action. Each
cancel resolves its coin to an asset id (the wire `a`) and carries the
oid (the wire `o`).

#### Usage

    HyperliquidTrading$bulk_cancel(cancels)

#### Arguments

- `cancels`:

  (list) unnamed list of cancel specs; each a named list with `coin` and
  `oid`.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per cancel, or a promise thereof.

------------------------------------------------------------------------

### Method `bulk_cancel_by_cloid()`

Cancel a batch of orders by client order id in one signed
`cancelByCloid` action. Each cancel carries the asset id (the wire
`asset`) and the cloid.

#### Usage

    HyperliquidTrading$bulk_cancel_by_cloid(cancels)

#### Arguments

- `cancels`:

  (list) unnamed list of cancel specs; each a named list with `coin` and
  `cloid`.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html),
one row per cancel, or a promise thereof.

------------------------------------------------------------------------

### Method `schedule_cancel()`

Arm or disarm a dead-man's switch: schedule a time at which all open
orders are cancelled. The time must be at least 5 seconds in the future;
pass `NULL` to clear a pending schedule. Max 10 triggers per UTC day.

#### Usage

    HyperliquidTrading$schedule_cancel(time = NULL)

#### Arguments

- `time`:

  (POSIXct \| numeric \| NULL) when to cancel all orders (POSIXct,
  numeric epoch-milliseconds, or `NULL`). `NULL` (default) clears any
  pending schedule.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `update_leverage()`

Set the leverage for a coin, cross or isolated.

#### Usage

    HyperliquidTrading$update_leverage(name, leverage, is_cross = TRUE)

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name.

- `leverage`:

  (scalar\<count in \[1, Inf\[\>) a finite, strictly-positive whole
  number (accepts an integer or a whole-valued double).

- `is_cross`:

  (scalar\<logical\>) `TRUE` for cross margin, `FALSE` for isolated.
  Default `TRUE`.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `update_isolated_margin()`

Add or remove isolated margin for a coin. The USD amount is scaled to a
micro-USD integer (x1e6) before signing. A positive `amount` adds
margin; a negative `amount` removes it (SDK parity).

#### Usage

    HyperliquidTrading$update_isolated_margin(name, amount)

#### Arguments

- `name`:

  (scalar\<character\>) the coin or friendly name.

- `amount`:

  (scalar\<numeric\>) the USD amount of margin to move – a finite,
  non-zero scalar. Positive adds margin, negative removes it.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `approve_agent()`

Approve a fresh agent (API) wallet for this account. A new secp256k1 key
is generated locally, its address approved on-chain, and the **secret is
returned to you** – store it securely, as it is the only time it is
exposed and it can sign trading actions for this account until revoked.

Mirrors the reference SDK: when `name` is `NULL` the action is signed
with an empty `agentName`. (The SDK then strips the empty field from the
posted body; this client instead posts `agentName = ""`, which is
signature-equivalent because the server defaults a missing `agentName`
to the empty string – the EIP-712 digest is identical either way.)

#### Usage

    HyperliquidTrading$approve_agent(name = NULL)

#### Arguments

- `name`:

  (scalar\<character\> \| NULL) an optional human-readable agent name.
  Default `NULL`.

#### Returns

(promise\<data.table\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `agent_address`, `agent_key` (the new hex secret), and `status`, or
a promise thereof.

------------------------------------------------------------------------

### Method `approve_builder_fee()`

Approve a maximum builder fee for a builder address, allowing that
builder to attach a fee (up to `max_fee_rate`) to your orders.

#### Usage

    HyperliquidTrading$approve_builder_fee(builder, max_fee_rate)

#### Arguments

- `builder`:

  (scalar\<character\>) the builder's `0x`-prefixed address.

- `max_fee_rate`:

  (scalar\<character\>) the max fee as a percent string, e.g.
  `"0.001%"`.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidTrading$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
trading <- HyperliquidTrading$new()
# A resting post-only bid:
trading$place_order("BTC", is_buy = TRUE, sz = 0.001, limit_px = 50000,
  order_type = list(limit = list(tif = "Alo")))
# Open and then close a long at market:
trading$market_open("BTC", is_buy = TRUE, sz = 0.001)
trading$market_close("BTC")
# Cancel one order, then arm a 1-minute dead-man's switch:
trading$cancel_order("BTC", oid = 123456789)
trading$schedule_cancel(lubridate::now("UTC") + lubridate::seconds(60))
} # }
```
