# HyperliquidTransfers: Collateral Movement, Sends, and Withdrawals

HyperliquidTransfers: Collateral Movement, Sends, and Withdrawals

HyperliquidTransfers: Collateral Movement, Sends, and Withdrawals

## Details

### Purpose

Signed `/exchange` actions that move funds: between the spot and perp
wallets of one account (`usd_class_transfer`), to another address on
Hyperliquid (`usd_send`, `spot_send`, `send_asset`), out to the bridge
(`withdraw`), and between an account and its sub-accounts or a vault
(`sub_account_transfer`, `sub_account_spot_transfer`, `vault_transfer`).
All require a wallet signing key.

Inherits from
[HyperliquidBase](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md).
Every method supports both synchronous and asynchronous execution
depending on the `async` argument at construction.

### Signing

Most transfers are **user-signed** actions over the
`HyperliquidSignTransaction` EIP-712 domain (each carries its own
`time`/`nonce` field, and `vaultAddress` is forced null on the wire).
The sub-account and vault transfers are **L1** actions hashed and signed
over the Exchange domain. Amounts denominated in USD for
sub-account/vault transfers are scaled to micro-USD integers (x1e6)
before signing.

### Official Documentation

<https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/exchange-endpoint>

### Endpoints Covered

|                           |                        |      |
|---------------------------|------------------------|------|
| Method                    | type                   | Auth |
| usd_class_transfer        | usdClassTransfer       | Yes  |
| usd_send                  | usdSend                | Yes  |
| spot_send                 | spotSend               | Yes  |
| withdraw                  | withdraw3              | Yes  |
| send_asset                | sendAsset              | Yes  |
| sub_account_transfer      | subAccountTransfer     | Yes  |
| sub_account_spot_transfer | subAccountSpotTransfer | Yes  |
| vault_transfer            | vaultTransfer          | Yes  |

## Super class

[`hyperliquid::HyperliquidBase`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.md)
-\> `HyperliquidTransfers`

## Methods

### Public methods

- [`HyperliquidTransfers$usd_class_transfer()`](#method-HyperliquidTransfers-usd_class_transfer)

- [`HyperliquidTransfers$usd_send()`](#method-HyperliquidTransfers-usd_send)

- [`HyperliquidTransfers$spot_send()`](#method-HyperliquidTransfers-spot_send)

- [`HyperliquidTransfers$withdraw()`](#method-HyperliquidTransfers-withdraw)

- [`HyperliquidTransfers$send_asset()`](#method-HyperliquidTransfers-send_asset)

- [`HyperliquidTransfers$sub_account_transfer()`](#method-HyperliquidTransfers-sub_account_transfer)

- [`HyperliquidTransfers$sub_account_spot_transfer()`](#method-HyperliquidTransfers-sub_account_spot_transfer)

- [`HyperliquidTransfers$vault_transfer()`](#method-HyperliquidTransfers-vault_transfer)

- [`HyperliquidTransfers$clone()`](#method-HyperliquidTransfers-clone)

Inherited methods

- [`hyperliquid::HyperliquidBase$initialize()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-initialize)
- [`hyperliquid::HyperliquidBase$name_to_asset()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_asset)
- [`hyperliquid::HyperliquidBase$name_to_coin()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-name_to_coin)
- [`hyperliquid::HyperliquidBase$refresh_meta()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-refresh_meta)
- [`hyperliquid::HyperliquidBase$sz_decimals()`](https://dereckscompany.github.io/hyperliquid/reference/HyperliquidBase.html#method-sz_decimals)

------------------------------------------------------------------------

### Method `usd_class_transfer()`

Move USDC collateral between the spot and perp wallets of the acting
account (no on-chain transfer; an internal class switch). When the
client was constructed with a `vault_address`, the amount string carries
a `subaccount:<vault>` suffix so the move applies to that sub-account
(mirrors the reference SDK).

#### Usage

    HyperliquidTransfers$usd_class_transfer(amount, to_perp)

#### Arguments

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the USDC amount to move.

- `to_perp`:

  (scalar\<logical\>) `TRUE` moves spot -\> perp, `FALSE` perp -\> spot.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `usd_send()`

Send USDC to another address on Hyperliquid (an internal transfer, not a
bridge withdrawal).

#### Usage

    HyperliquidTransfers$usd_send(amount, destination)

#### Arguments

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the USDC amount to send.

- `destination`:

  (scalar\<character\>) the recipient's 0x-prefixed address.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `spot_send()`

Send a spot token to another address on Hyperliquid.

#### Usage

    HyperliquidTransfers$spot_send(amount, destination, token)

#### Arguments

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the token amount to send.

- `destination`:

  (scalar\<character\>) the recipient's 0x-prefixed address.

- `token`:

  (scalar\<character\>) the token in `NAME:0x<tokenId>` form, e.g.
  `"PURR:0xc1fb593aeffbeb02f85e0308e9956a90"`.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `withdraw()`

Withdraw USDC from Hyperliquid out to the bridge (an on-chain withdrawal
to the destination address; a fee applies).

#### Usage

    HyperliquidTransfers$withdraw(amount, destination)

#### Arguments

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the USDC amount to withdraw.

- `destination`:

  (scalar\<character\>) the recipient's 0x-prefixed address.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `send_asset()`

Send a token between dexes and/or to another address. For the default
perp dex use the empty string `""`; for spot use `"spot"`. The token
must match the collateral token when transferring to or from a perp dex.
When the client carries a `vault_address` it is sent as the
`fromSubAccount`.

#### Usage

    HyperliquidTransfers$send_asset(
      destination,
      source_dex,
      destination_dex,
      token,
      amount
    )

#### Arguments

- `destination`:

  (scalar\<character\>) the recipient's 0x-prefixed address.

- `source_dex`:

  (scalar\<character\>) the source dex name (`""` for the default perp
  dex, `"spot"` for spot).

- `destination_dex`:

  (scalar\<character\>) the destination dex name.

- `token`:

  (scalar\<character\>) the token in `NAME:0x<tokenId>` form.

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the amount to send.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `sub_account_transfer()`

Transfer USDC perp collateral between the acting account and one of its
sub-accounts (an L1 action). The amount is scaled to a micro-USD integer
before signing.

#### Usage

    HyperliquidTransfers$sub_account_transfer(sub_account_user, is_deposit, usd)

#### Arguments

- `sub_account_user`:

  (scalar\<character\>) the sub-account's 0x-prefixed address.

- `is_deposit`:

  (scalar\<logical\>) `TRUE` deposits into the sub-account, `FALSE`
  withdraws from it.

- `usd`:

  (scalar\<numeric in \]0, Inf\[\>) the USD amount.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `sub_account_spot_transfer()`

Transfer a spot token between the acting account and one of its
sub-accounts (an L1 action).

#### Usage

    HyperliquidTransfers$sub_account_spot_transfer(
      sub_account_user,
      is_deposit,
      token,
      amount
    )

#### Arguments

- `sub_account_user`:

  (scalar\<character\>) the sub-account's 0x-prefixed address.

- `is_deposit`:

  (scalar\<logical\>) `TRUE` deposits into the sub-account, `FALSE`
  withdraws from it.

- `token`:

  (scalar\<character\>) the token in `NAME:0x<tokenId>` form.

- `amount`:

  (scalar\<numeric in \]0, Inf\[\>) the token amount.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `vault_transfer()`

Deposit into or withdraw from a vault (an L1 action). The amount is
scaled to a micro-USD integer before signing.

#### Usage

    HyperliquidTransfers$vault_transfer(vault_address, is_deposit, usd)

#### Arguments

- `vault_address`:

  (scalar\<character\>) the vault's 0x-prefixed address.

- `is_deposit`:

  (scalar\<logical\>) `TRUE` deposits into the vault, `FALSE` withdraws
  from it.

- `usd`:

  (scalar\<numeric in \]0, Inf\[\>) the USD amount.

#### Returns

(promise\<TransferAck\>) a single-row
[data.table::data.table](https://rdrr.io/pkg/data.table/man/data.table.html)
with `status` and `response_type`, or a promise thereof.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidTransfers$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
transfers <- HyperliquidTransfers$new()
# Move $100 of collateral from the spot wallet into the perp wallet:
transfers$usd_class_transfer(100, to_perp = TRUE)
# Send 25 USDC to another address:
transfers$usd_send(25, "0x5e9ee1089755c3435139848e47e6635505d5a13a")
} # }
```
