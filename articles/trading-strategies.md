# Trading Strategies: Long, Short, and Pairs Trading

This guide is for readers who are new to derivatives trading. It
explains the vocabulary as it goes and then builds up to a
**market-neutral pairs trade**. All code executes against a
deterministic mock, so the printed output is real in *shape* but moves
no money. Before doing any of this for real, read the [live testnet
walkthrough](https://dereckscompany.github.io/hyperliquid/articles/live-testnet-walkthrough.md)
and practise on testnet.

> Trading leveraged derivatives is risky and can lose more than your
> deposit. Nothing here is financial advice.

## The vocabulary, in one minute

- **Spot** trading means buying and *owning* the asset (you hold the
  coin).
- A **perpetual future (“perp”)** is a contract that tracks an asset’s
  price without ever expiring. You never own the coin; you hold a
  *position* that gains or loses as the price moves. Perps are the core
  of Hyperliquid.
- **Long** = you profit when the price goes **up** (`is_buy = TRUE`).
- **Short** = you profit when the price goes **down**
  (`is_buy = FALSE`). A short is a first-class position, not a
  workaround.
- **Leverage** lets a small amount of collateral control a larger
  position (e.g. 5x). It magnifies gains *and* losses, and can trigger
  **liquidation** (your position is force-closed) on an adverse move.
- **Funding** is a small payment exchanged between longs and shorts
  every few hours to keep the perp price tethered to the spot price.

## Reading the market

Market data needs no credentials.

``` r

md <- HyperliquidMarketData$new()

# Mid prices across all perps (one row per coin).
head(md$get_all_mids(), 4)

# The order book for BTC: bids and asks stacked long, with a `side` column.
head(md$get_l2_book("BTC"), 4)
```

    #>      coin        mid
    #>    <char>      <num>
    #> 1:    BTC 61958.5000
    #> 2:    ETH  1605.4500
    #> 3:     @1     9.6738
    #>      side level    px       sz     n
    #>    <char> <int> <num>    <num> <num>
    #> 1:    bid     1 61945  0.03164     3
    #> 2:    bid     2 61944  0.00085     4
    #> 3:    ask     1 61946 13.32523    39
    #> 4:    ask     2 61947  0.06724     6

## Opening a position, and the order types

`HyperliquidTrading` signs and sends orders. The two everyday order
types:

- **Limit order** — rests on the book at a price you choose; fills only
  at that price or better. Its **time-in-force** controls how it lives:
  `"Gtc"` (good-til-cancelled, the default), `"Ioc"`
  (immediate-or-cancel — fill now or die), `"Alo"` (add-liquidity-only /
  post-only — never crosses the spread).
- **Market order** — fills immediately by crossing the spread
  (`market_open()` implements this as an aggressive IOC).

``` r

trading <- HyperliquidTrading$new(keys = KEYS)

# A good-til-cancelled limit BUY (a long): rest a bid at 60,000.
trading$place_order(
  name = "BTC", is_buy = TRUE, sz = 0.001, limit_px = 60000,
  order_type = list(limit = list(tif = "Gtc"))
)

# Or take liquidity immediately with a market buy.
trading$market_open(name = "BTC", is_buy = TRUE, sz = 0.001)
```

    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.
    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

## Going short

Selling a perp you do not hold *opens a short* – you are now positioned
to profit if the price falls. The only change is `is_buy = FALSE`.

``` r

# A market SHORT on ETH.
trading$market_open(name = "ETH", is_buy = FALSE, sz = 0.05)
```

    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

## Leverage and margin

Set the leverage per market before sizing up. **Cross** margin shares
collateral across all positions; **isolated** margin walls off a single
position so a liquidation there cannot drain the rest.

``` r

# 5x cross-margin leverage on BTC.
trading$update_leverage(name = "BTC", leverage = 5, is_cross = TRUE)
```

    #>    status response_type
    #>    <char>        <char>
    #> 1:     ok       default

## Pairs trading (market-neutral)

This is the strategy that motivated the example. A **pairs trade** holds
**one leg long and one leg short** at the same time – so you profit from
the *relative* move between the two, not the market’s overall direction.
If you are long BTC and short ETH and BTC outperforms ETH, you win
**even if both fall**, because the short leg gains while the long leg
loses less (and vice-versa).

Open both legs – a long and a short – with whatever order types you
prefer (here: a resting limit on the long, a market fill on the short):

``` r

# Leg 1: LONG BTC (limit).
trading$place_order(
  name = "BTC", is_buy = TRUE, sz = 0.002, limit_px = 62000,
  order_type = list(limit = list(tif = "Gtc"))
)

# Leg 2: SHORT ETH (market).
trading$market_open(name = "ETH", is_buy = FALSE, sz = 0.4)
```

    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.
    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

Once filled, the account holds the two opposing legs. `get_positions()`
returns one row per open position, with a signed `szi` (positive = long,
negative = short):

``` r

account <- HyperliquidAccount$new(keys = KEYS)
account$get_positions()[, .(coin, szi, entry_px, position_value, unrealized_pnl)]
```

    #>      coin      szi entry_px position_value unrealized_pnl
    #>    <char>    <num>    <num>          <num>          <num>
    #> 1:    BTC  0.61148 61699.10     37899.5304       171.7548
    #> 2:    ETH -0.37080  1606.85       595.6902         0.1306

> On a real testnet run this exact pair filled as **long 0.0002 BTC @
> \$64,424** and **short 0.01 ETH @ \$1,688.9** – a balanced spread. The
> spread’s profit and loss is the *difference* between the two legs’
> moves.

## Protecting a position: take-profit and stop-loss

A **trigger order** fires when the market reaches a `triggerPx`. Use
`tpsl = "tp"` to take profit, `tpsl = "sl"` to stop a loss;
`isMarket = TRUE` fills at market once triggered. Make it `reduce_only`
so it can only *close* the position.

``` r

# Stop-loss on the BTC long: if BTC trades down to 60,000, market-sell to exit.
trading$place_order(
  name = "BTC", is_buy = FALSE, sz = 0.002, limit_px = 60000,
  order_type = list(trigger = list(isMarket = TRUE, triggerPx = 60000, tpsl = "sl")),
  reduce_only = TRUE
)
```

    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

## Monitoring and closing

Check your fills, then flatten each leg with `market_close()` (a
reduce-only market order sized to the open position).

``` r

# Most recent fills.
head(account$get_user_fills(), 3)

# Close both legs of the pair.
trading$market_close(name = "BTC")
trading$market_close(name = "ETH")
```

    #>      coin       px    sz   side                time start_position        dir
    #>    <char>    <num> <num> <char>              <POSc>          <num>     <char>
    #> 1:   IOTA 0.045274   371    buy 2026-06-07 05:19:59         259108  Open Long
    #> 2: PENDLE 1.245300   253   sell 2026-06-07 05:19:58         -26314 Open Short
    #>    closed_pnl
    #>         <num>
    #> 1:          0
    #> 2:          0
    #>                                                                  hash
    #>                                                                <char>
    #> 1: 0x0d3fdb3600e5d56a0eb9043d26c359020299001b9be8f43cb1088688bfe9af54
    #> 2: 0xb35e4a190053fac6b4d8043d26c35302054600fe9b5719985726f56bbf57d4b1
    #>             oid crossed   fee fee_token          tid
    #>           <num>  <lgcl> <num>    <char>        <num>
    #> 1: 461291888494    TRUE     0      USDC 4.500545e+14
    #> 2: 461291857900   FALSE     0      USDC 1.789294e+14
    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.
    #>     status      oid total_sz avg_px                                 error
    #>     <char>    <num>    <num>  <num>                                <char>
    #> 1: resting 77738308       NA     NA                                  <NA>
    #> 2:  filled 77747314     0.02 1891.4                                  <NA>
    #> 3:   error       NA       NA     NA Order must have minimum value of $10.

## Putting it together

- `is_buy = TRUE` longs, `is_buy = FALSE` shorts – both first-class.
- Choose the order type to control execution: limit + `Gtc`/`Ioc`/`Alo`,
  or market.
- A pairs trade is just **a long and a short held together**, profiting
  from the spread and shrinking exposure to the overall market.
- Bracket positions with `reduce_only` trigger orders (TP/SL), and size
  with leverage you can survive.

For the full account and market-data surface, see the [Getting
Started](https://dereckscompany.github.io/hyperliquid/articles/getting-started.md)
guide; for the real funded round-trip and its pitfalls, see the [live
testnet
walkthrough](https://dereckscompany.github.io/hyperliquid/articles/live-testnet-walkthrough.md).
