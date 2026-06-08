# Funding a Wallet and Running a Live Testnet Trade

This vignette is a plain-language, chronological account of taking the
package all the way to a **real, filled trade on the Hyperliquid
testnet** – and, just as importantly, every point of confusion hit along
the way. If you have never moved crypto between networks or used a
decentralised exchange, read it start to finish; the jargon is explained
as it appears.

> **Security, up front.** Your wallet’s **secret recovery phrase** and
> your **main private key** must never be pasted into a terminal, a
> file, a chat, or any website. They control your money. Everything
> below uses either your *public address* (safe to share, like an
> account number) or a Hyperliquid **API/agent wallet** key, which can
> place trades but **cannot withdraw funds** – so even if it leaked,
> your balance is safe.

## Why bother at all

The package’s signing was already proven correct two ways before any
money was involved:

1.  **Byte-for-byte test vectors.** `tests/testthat/test-signing.R`
    reproduces the official Hyperliquid SDK signatures exactly.
2.  **A zero-funds live check.** Posting a *signed* order from a
    brand-new wallet makes the exchange reply
    `"User or API Wallet 0x… does not exist"` – and the address it
    echoes back is the one it recovered *from our signature*. When that
    matches our wallet, the entire build → sign → send → verify path is
    confirmed without spending anything.

So the funded run below proves only one extra thing: that an order
actually **fills** end to end. It is optional. If you only need
confidence the code is correct, you already have it.

## Step 1 – A wallet to trade from

We used a fresh **MetaMask** browser extension (Hyperliquid’s web app
connects to browser wallets cleanly). A mobile wallet such as Exodus can
connect via WalletConnect, but a desktop extension is far smoother.

## Step 2 – Getting money onto the right “lane” (the confusing part)

Hyperliquid’s deposit screen asks for **“USDC from Arbitrum,”** and this
is where most newcomers (including us) get stuck. The vocabulary:

- **USDC** is a *stablecoin* – a digital US dollar, worth ~\$1. It is
  the money a Hyperliquid account trades with.
- **Arbitrum** is **not a company, platform, or account** – there is
  nothing to sign up for and no KYC. It is a *network*: think of it as a
  cheaper express lane built on top of Ethereum. Hyperliquid only
  accepts USDC that is sitting on the **Arbitrum** lane.
- **HYPE** is Hyperliquid’s own token (for staking, fees, governance,
  trading). It is **not** the cash your account trades with, so holding
  HYPE does not fund an account.

> **Snag we hit \#1 – “I thought Ethereum was just Ethereum.”** There is
> now one main Ethereum network *plus* several cheaper “layer-2” lanes
> built on it (Arbitrum, Optimism, Base, …). The same coin can live on
> different lanes, and a coin on one lane cannot be used on another
> until it is *bridged* across.

> **Snag \#2 – fees are paid in ETH, not USDC.** Every move *on* a
> network costs a fee (“gas”), and each lane charges gas in **its own
> ETH**. Our USDC started on the main Ethereum lane, so we first needed
> a little **ETH on Ethereum** to move it – and later a little **ETH on
> Arbitrum** to deposit. Moving \$9 ended up needing ~\$1 of ETH for
> gas, then a swap of that ETH onto Arbitrum.

> **Snag \#3 – the main Ethereum lane is expensive.** Moving small
> amounts *off* Ethereum mainnet can cost several dollars in gas.
> Cheaper ways to land USDC and a little ETH **directly on Arbitrum**
> (skipping the costly hops):
>
> - A centralised exchange withdrawal, choosing **Arbitrum** as the
>   network (flat fee, no slippage) – needs a KYC account.
> - A dedicated bridge such as **Across** or **Jumper** (tighter pricing
>   than a wallet’s built-in bridge).
> - Some wallets support Arbitrum directly and can send to MetaMask on
>   Arbitrum.

To switch USDC from Ethereum to Arbitrum we used MetaMask’s built-in
**Bridge** (its “swap”): *from* USDC on Ethereum *to* USDC on Arbitrum.

> **Snag \#4 – MetaMask’s swap/bridge takes a cut.** It charges a
> service fee (~0.9%) plus slippage. Convenient, but not the cheapest
> route (see the bridges above).

## Step 3 – Deposit on Hyperliquid mainnet

With USDC (and a little ETH for gas) on Arbitrum, the Hyperliquid
**Deposit** screen works:

- The **minimum deposit is \$5 USDC** – anything less is not credited.
- There is a small (~\$0.20) deposit fee.
- The deposit is an Arbitrum transaction, so it needs a *tiny* bit of
  Arbitrum ETH for gas (cents).

We deposited ~\$9. **This mainnet deposit is only there to unlock the
testnet faucet** – the actual test trades use *free* testnet money, so
there is no reason to deposit more.

## Step 4 – Claim the testnet faucet

The testnet faucet at the testnet site’s **/drip** page gives **1000
mock USDC**, but only *“if you have deposited on mainnet.”* That single
mainnet deposit in Step 3 is what satisfies this gate. Connect the same
wallet and click **“Claim 1000 mock USDC.”**

> **Snag \#5 – “I claimed it but my MetaMask shows nothing.”** Correct,
> and expected. MetaMask shows coins *in your wallet*. The mock USDC is
> a balance *inside your Hyperliquid account* (like money shown on an
> exchange’s website), and it is **testnet** money that only exists on
> the testnet site. To see it, open the **testnet** site → **Trade**
> page and look at the account panel (the Portfolio page showed \$0 for
> us; the Trade panel showed “Available to trade ~999 USDC”).

You can also confirm it directly, bypassing the UI entirely, with a
public `/info` request – no key needed:

``` r

box::use(hyperliquid[HyperliquidAccount])

acct <- HyperliquidAccount$new(testnet = TRUE)
# Your PUBLIC address (safe to share); not the private key.
acct$get_spot_balances(address = "0xYOUR_MAIN_ADDRESS")
#> shows USDC total ~999 on testnet
```

## Step 5 – Make a safe key to trade with (API / agent wallet)

To let the package sign on your behalf without ever handling your real
key, Hyperliquid provides **API wallets** (also called **agent
wallets**): keys that can place trades but **cannot withdraw**. On the
testnet site, open **More → API**, name the wallet, click **Generate**,
and **authorise** it (your main wallet signs the approval in MetaMask).

> **Snag \#6 – address vs. private key.** “Generate” shows you two
> different strings. The **address** is `0x` + 40 characters (public).
> The **private key** is `0x` + **64** characters (secret, shown once
> with a “save this” warning). The package needs the **private key**. It
> is easy to copy the wrong one.

Put the API key into a gitignored `.Renviron` (never commit it). Because
it is an agent wallet, also set your **main account address** so reads
and order attribution point at the funded account:

``` r

# .Renviron  (chmod 600, listed in .gitignore -- do not commit)
# HYPERLIQUID_PRIVATE_KEY=0x<the 64-char API/agent key>
# HYPERLIQUID_ACCOUNT_ADDRESS=0x<your main account address>
```

A `.Renviron.example` template ships with the package. You can
sanity-check that the key matches the agent address you authorised:

``` r

box::use(ethsign[eth_address])
eth_address("0x<the API/agent key>")  # should equal the authorised agent address
```

## Step 6 – Place a real order, watch it fill

Construct a trading client from the credentials and place the order. A
couple of testnet realities shaped how we did it:

> **Snag \#7 – “Unified” account, and agents can’t move funds.** Our
> faucet USDC landed in the **Spot** balance, while perps trade from the
> **Perps** balance. Normally you transfer Spot → Perps, but our account
> had **Unified** mode on, which merges the two – so spot collateral
> backs perps directly and no transfer was needed. (Worth knowing: an
> **agent wallet cannot do a Spot↔︎Perps transfer** anyway – only your
> main wallet can; the exchange returns *“Must deposit before performing
> actions”* for the agent.)

> **Snag \#8 – “Price too far from oracle.”** A plain market order
> (`market_open()`) prices itself a few percent through the book. On
> testnet the *oracle* price runs ~2–3% away from the live book, so that
> buffer pushed the price outside Hyperliquid’s allowed band and was
> rejected. The fix is to price a precise limit order at the current
> book instead:

``` r

box::use(hyperliquid[HyperliquidTrading, get_api_keys])

readRenviron(".Renviron")
trading <- HyperliquidTrading$new(keys = get_api_keys(), testnet = TRUE)

# A short sell is just is_buy = FALSE; a long is is_buy = TRUE. (Pairs trading is
# one of each on two markets.) Here: a small marketable BUY priced at the ask.
trading$place_order(
  name = "BTC", is_buy = TRUE, sz = 0.0002, limit_px = 64219,
  order_type = list(limit = list(tif = "Gtc"))
)
#> status filled, avg_px 64119  -> long 0.0002 BTC

# Flatten it with a reduce-only sell.
trading$place_order(
  name = "BTC", is_buy = FALSE, sz = 0.0002, limit_px = 63964,
  order_type = list(limit = list(tif = "Gtc")), reduce_only = TRUE
)
#> status filled  -> position closed, account flat
```

> **Snag \#9 – IOC that “could not match.”** On a thin, fast-moving
> testnet book, an Immediate-Or-Cancel order priced at a stale ask can
> miss and cancel. Reading the book immediately before ordering (and/or
> using GTC so any unfilled remainder rests) makes the fill reliable.

That round-trip – open, hold a real position, close – is the whole
proof: the package built, signed (with the agent key), submitted, and
the exchange **matched** the trade, all live.

## What this proved

- Signing is correct against the **real exchange**, not just test
  vectors.
- The full order lifecycle works: **submit → match → position →
  reduce-only close**.
- A **short** is a first-class order (`is_buy = FALSE`), so **pairs
  trading** (long one market, short another) works today.
- Agent/API wallets are the safe way to automate: trade-only, no
  withdrawal.

## Useful links

- Hyperliquid app (mainnet): <https://app.hyperliquid.xyz>
- Hyperliquid app (testnet): <https://app.hyperliquid-testnet.xyz>
- Testnet faucet: <https://app.hyperliquid-testnet.xyz/drip>
- API / agent wallets: <https://app.hyperliquid-testnet.xyz/API>
- Docs – nonces & API wallets:
  <https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/nonces-and-api-wallets>
- Docs – order types:
  <https://hyperliquid.gitbook.io/hyperliquid-docs/trading/order-types>
