# HyperliquidStaking: Native-Token Staking and Delegation

HyperliquidStaking: Native-Token Staking and Delegation

HyperliquidStaking: Native-Token Staking and Delegation

## Details

Reads a delegator's staking state and history, and delegates or
undelegates the native token to or from a validator. Hyperliquid uses
delegated proof-of-stake: stake is delegated to validators, delegations
carry a one-day lockup, and rewards accrue every minute and compound
daily.

Inherits from
[HyperliquidBase](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md).
All methods support both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Purpose

Surface the staking account: the staked / free balances and pending
withdrawals (get_staking_summary()), the active per-validator
delegations (get_staking_delegations()), the reward accrual history
(get_staking_rewards()), the full delegate/deposit/withdraw event ledger
(get_delegator_history()), and the delegate / undelegate action itself
(token_delegate()).

### Official Documentation

<https://hyperliquid.gitbook.io/hyperliquid-docs/hypercore/staking>

### Default address

The read methods default `address` to the instance's acting address
(vault, then master account, then the key's own wallet). Pass `address`
explicitly to inspect any other delegator.

### Endpoints Covered

|                         |                  |      |
|-------------------------|------------------|------|
| Method                  | type             | Auth |
| get_staking_summary     | delegatorSummary | No   |
| get_staking_delegations | delegations      | No   |
| get_staking_rewards     | delegatorRewards | No   |
| get_delegator_history   | delegatorHistory | No   |
| token_delegate          | tokenDelegate    | Yes  |

## Super class

[`hyperliquid::HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
-\> `HyperliquidStaking`

## Methods

### Public methods

- [`HyperliquidStaking$get_staking_summary()`](#method-HyperliquidStaking-get_staking_summary)

- [`HyperliquidStaking$get_staking_delegations()`](#method-HyperliquidStaking-get_staking_delegations)

- [`HyperliquidStaking$get_staking_rewards()`](#method-HyperliquidStaking-get_staking_rewards)

- [`HyperliquidStaking$get_delegator_history()`](#method-HyperliquidStaking-get_delegator_history)

- [`HyperliquidStaking$token_delegate()`](#method-HyperliquidStaking-token_delegate)

- [`HyperliquidStaking$clone()`](#method-HyperliquidStaking-clone)

Inherited methods

- [`hyperliquid::HyperliquidBase$initialize()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-initialize)
- [`hyperliquid::HyperliquidBase$name_to_asset()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_asset)
- [`hyperliquid::HyperliquidBase$name_to_coin()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_coin)
- [`hyperliquid::HyperliquidBase$refresh_meta()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-refresh_meta)
- [`hyperliquid::HyperliquidBase$sz_decimals()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-sz_decimals)

------------------------------------------------------------------------

### Method `get_staking_summary()`

Retrieve a delegator's staking summary: the staked and free balances,
the total pending withdrawal, and the number of pending withdrawals.

#### Usage

    HyperliquidStaking$get_staking_summary(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the delegator's `0x`-prefixed address. Defaults
  to the instance's acting address.

#### Returns

(promise\<StakingSummary\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `delegated`, `undelegated`, `total_pending_withdrawal`,
`n_pending_withdrawals`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_staking_delegations()`

Retrieve a delegator's active per-validator delegations.

#### Usage

    HyperliquidStaking$get_staking_delegations(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the delegator's `0x`-prefixed address. Defaults
  to the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `validator`, `amount`, `locked_until_timestamp`, or a promise
thereof.

------------------------------------------------------------------------

### Method `get_staking_rewards()`

Retrieve a delegator's historic staking rewards.

#### Usage

    HyperliquidStaking$get_staking_rewards(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the delegator's `0x`-prefixed address. Defaults
  to the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `time`, `source`, `total_amount`, or a promise thereof.

------------------------------------------------------------------------

### Method `get_delegator_history()`

Retrieve a delegator's comprehensive staking history: the delegate /
undelegate / deposit / withdraw events. Heterogeneous events are stacked
with a `delta_type` discriminator.

#### Usage

    HyperliquidStaking$get_delegator_history(address = private$.acting_address())

#### Arguments

- `address`:

  (scalar\<character\>) the delegator's `0x`-prefixed address. Defaults
  to the instance's acting address.

#### Returns

(promise\<data.table\>) a
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `time`, `hash`, `delta_type`, and the union of the variants' fields
(`validator`, `amount`, `is_undelegate` where present), or a promise
thereof.

------------------------------------------------------------------------

### Method `token_delegate()`

Delegate or undelegate native token to or from a validator. Delegations
carry a one-day lockup; undelegated balances reflect instantly. Requires
a signing key.

#### Usage

    HyperliquidStaking$token_delegate(validator, wei, is_undelegate = FALSE)

#### Arguments

- `validator`:

  (scalar\<character\>) the validator's `0x`-prefixed address.

- `wei`:

  (scalar\<numeric in \]0, Inf\[\>) the amount in wei – a finite,
  strictly-positive whole number.

- `is_undelegate`:

  (scalar\<logical\>) `TRUE` to undelegate (withdraw stake), `FALSE` to
  delegate. Default `FALSE`.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidStaking$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
staking <- HyperliquidStaking$new()
staking$get_staking_summary("0x5ac99df645f3414876c816caa18b2d234024b487")
staking$get_staking_delegations("0x5ac99df645f3414876c816caa18b2d234024b487")

# Delegate 100 wei to a validator (requires a signing key):
staking$token_delegate(
  validator = "0x5ac99df645f3414876c816caa18b2d234024b487",
  wei = 100,
  is_undelegate = FALSE
)
} # }
```
