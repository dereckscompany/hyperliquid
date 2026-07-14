# HyperliquidBase: Abstract Base Class for Hyperliquid API Clients

HyperliquidBase: Abstract Base Class for Hyperliquid API Clients

HyperliquidBase: Abstract Base Class for Hyperliquid API Clients

## Details

Provides shared infrastructure for all Hyperliquid R6 classes: wallet
credentials, network selection, sync/async execution mode, the request
funnel
([`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)),
and lazy exchange-metadata caching.

It **inherits
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html)**,
the shared transport base, for the credential storage, sync/async
perform function, and the overridable `.parse_envelope()` error seam —
which it overrides with Hyperliquid's two-failure-shape parser
(`parse_hyperliquid_response()`). The `.sign()` seam is left at its
no-op default: Hyperliquid does not sign the HTTP request but the
**body** (a wallet signature embedded as a `signature` field, built and
attached by `.submit_l1()` / `.submit_user()` before the funnel), so
request signing does not apply. The body-signed wire contract is
honoured by routing the pre-serialised, byte-exact JSON through
connectcore's shared funnel as a **raw body** (`body_format = "raw"`),
so the connector owns no transport: the request build, perform,
sync/async branch, and monotonic nonce all come from connectcore. Only
the body serialisation and error envelope stay Hyperliquid-specific
([`hyperliquid_build_request()`](https://dereckscompany.github.io/hyperliquid/reference/hyperliquid_build_request.md)).

### Sync vs Async

The `async` parameter controls execution mode for all API methods:

- `async = FALSE` (default): methods return results directly.

- `async = TRUE`: methods return
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html)
  objects that resolve to the same types.

Async mode requires the `promises` package (a `Suggests`). Consume
promises with
[`coro::async()`](https://coro.r-lib.org/reference/async.html) and
`await()` or
[`promises::then()`](https://rstudio.github.io/promises/reference/then.html);
to drive the event loop in a script use the (optional) `later` package,
e.g. `while (!later::loop_empty()) later::run_now()`.

### Hosts

The entire REST API lives behind one host with two POST paths: `/info`
(public reads, unauthenticated) and `/exchange` (writes, authenticated
by a wallet signature in the body). Only the network differs between
mainnet and testnet, and it is chosen by the explicit `testnet` flag,
never by URL sniffing: the network changes the signature itself
(phantom-agent source and `hyperliquidChain` tag). See
[`get_base_url()`](https://dereckscompany.github.io/hyperliquid/reference/get_base_url.md).

### Retries

`max_tries > 1` opts the client's **reads** (`/info`) into automatic
retry on a transient failure (HTTP 408/429/5xx or a dropped connection)
with jittered backoff, delegated to
[`connectcore::build_request()`](https://dereckscompany.github.io/connectcore/reference/build_request.html).
Unlike a typical REST venue, Hyperliquid's entire API is POST — both
`/info` (reads) and `/exchange` (writes) — so the retry decision is by
**idempotency of the path**, not the HTTP verb: `/info` is marked
idempotent (its query is encoded in the body) and retries; `/exchange`
is a write and is **never** auto-retried, so an order or cancel can
never be silently resent and double-submitted. This is hardcoded per
path and not caller-choosable. Leave `max_tries` at the default `1` for
live trading — there the trader layer is the single retry authority (it
routes by typed error class and manages cooldowns); raise it only for
research and backfill reads.

### Design

This class is not meant to be instantiated directly. Subclasses (e.g.
`HyperliquidMarketData`, `HyperliquidTrading`) inherit from it and
define public methods that delegate to `private$.info()` (reads) or
`private$.exchange()` (signed writes). Each subclass method passes a
`.parser` closure and is otherwise sync/async-unaware.

## Fields

All fields are private. `.keys`, `.is_async`, and `.perform` are
inherited from
[connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html);
the rest are Hyperliquid-specific:

- `.keys`: List; wallet credentials from
  [`get_api_keys()`](https://dereckscompany.github.io/hyperliquid/reference/get_api_keys.md)
  (inherited).

- `.signer`:
  [ethsign::EthSigner](https://dereckscompany.github.io/ethsign/reference/EthSigner.html)
  or `NULL`; the wallet signer built from the key (used to sign
  /exchange actions), or `NULL` when no key is set.

- `.base_url`: Character; REST base URL for the selected network
  (inherited).

- `.is_async`: Logical; whether the instance is in async mode
  (inherited).

- `.perform`: Function;
  [httr2::req_perform](https://httr2.r-lib.org/reference/req_perform.html)
  or
  [httr2::req_perform_promise](https://httr2.r-lib.org/reference/req_perform_promise.html)
  (inherited).

- `.testnet`: Logical; whether the instance targets testnet.

- `.vault_address`: Character or `NULL`; vault/sub-account to act for.

- `.account_address`: Character or `NULL`; master account for an agent
  wallet.

- `.meta_cache`: List or `NULL`; cached asset-lookup tables (lazy).

## Super class

[`connectcore::RestClient`](https://dereckscompany.github.io/connectcore/reference/RestClient.html)
-\> `HyperliquidBase`

## Active bindings

- `testnet`:

  Logical; read-only flag indicating whether this instance targets
  testnet. (`is_async` is inherited from
  [connectcore::RestClient](https://dereckscompany.github.io/connectcore/reference/RestClient.html).)

## Methods

### Public methods

- [`HyperliquidBase$new()`](#method-HyperliquidBase-new)

- [`HyperliquidBase$refresh_meta()`](#method-HyperliquidBase-refresh_meta)

- [`HyperliquidBase$name_to_asset()`](#method-HyperliquidBase-name_to_asset)

- [`HyperliquidBase$name_to_coin()`](#method-HyperliquidBase-name_to_coin)

- [`HyperliquidBase$sz_decimals()`](#method-HyperliquidBase-sz_decimals)

- [`HyperliquidBase$clone()`](#method-HyperliquidBase-clone)

------------------------------------------------------------------------

### Method `new()`

Initialise a HyperliquidBase object.

#### Usage

    HyperliquidBase$new(
      keys = get_api_keys(),
      testnet = FALSE,
      async = FALSE,
      vault_address = NULL,
      max_tries = 1L
    )

#### Arguments

- `keys`:

  (list) wallet credentials from
  [`get_api_keys()`](https://dereckscompany.github.io/hyperliquid/reference/get_api_keys.md).
  Defaults to
  [`get_api_keys()`](https://dereckscompany.github.io/hyperliquid/reference/get_api_keys.md).

- `testnet`:

  (scalar\<logical\>) target testnet instead of mainnet. Default
  `FALSE`.

- `async`:

  (scalar\<logical\>) if `TRUE`, methods return promises. Default
  `FALSE`.

- `vault_address`:

  (scalar\<character\> \| NULL) a vault or sub-account address to act on
  behalf of (threaded into the action hash and payload of signed
  actions). Default `NULL`.

- `max_tries`:

  (scalar\<integer in \[1, 10\]\>) retry up to this many times on a
  transient failure. Retry applies to reads (`/info`) only; a write
  (`/exchange`) is never auto-retried. Default `1` (no retry). See the
  class **Retries** section for the write-safety carve-out and why live
  trading should leave this at `1`.

#### Returns

(class\<HyperliquidBase\>) invisible self.

------------------------------------------------------------------------

### Method `refresh_meta()`

Force a refetch of exchange metadata, replacing the cached asset-lookup
tables. Metadata is otherwise fetched lazily on first need; call this
after a new asset is listed.

#### Usage

    HyperliquidBase$refresh_meta()

#### Returns

(class\<HyperliquidBase\>) invisible self.

------------------------------------------------------------------------

### Method `name_to_asset()`

Resolve a friendly name (or canonical coin symbol) to its integer asset
id, fetching and caching metadata on first need.

#### Usage

    HyperliquidBase$name_to_asset(name)

#### Arguments

- `name`:

  (scalar\<character\>) a friendly name or canonical coin symbol.

#### Returns

(scalar\<count\>) the integer asset id used in signed actions. Perp ids
are an R integer (`0L`, `1L`, ...) while spot ids are a double (`10000`,
...), so the honest type is `count` (a non-negative whole number,
integer or double), not `numeric`/double.

------------------------------------------------------------------------

### Method `name_to_coin()`

Resolve a friendly name to its canonical coin symbol, fetching and
caching metadata on first need.

#### Usage

    HyperliquidBase$name_to_coin(name)

#### Arguments

- `name`:

  (scalar\<character\>) a friendly name or canonical coin symbol.

#### Returns

(scalar\<character\>) the canonical coin symbol.

------------------------------------------------------------------------

### Method `sz_decimals()`

Resolve an asset id to its size decimals, fetching and caching metadata
on first need.

#### Usage

    HyperliquidBase$sz_decimals(asset)

#### Arguments

- `asset`:

  (scalar\<count\>) an integer asset id (as returned by
  `name_to_asset()`: an R integer for perps, a double for spot).

#### Returns

(scalar\<count\>) the asset's size decimals.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    HyperliquidBase$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
