# Build and Execute a Hyperliquid API Request

Serialises `body` to the byte-exact signed JSON and routes it through
[`connectcore::build_request()`](https://rdrr.io/pkg/connectcore/man/build_request.html)
as a raw body, to one of Hyperliquid's two POST endpoints (`/info` or
`/exchange`). This is the single point through which all Hyperliquid API
calls flow.

## Usage

``` r
hyperliquid_build_request(
  base_url,
  path,
  body,
  .perform = httr2::req_perform,
  .parser = identity,
  is_async = FALSE,
  timeout = 30,
  parse_envelope = parse_hyperliquid_response
)
```

## Arguments

- base_url:

  (scalar\<character\>) the REST base URL (scheme + host).

- path:

  (scalar\<character\>) the endpoint path, `"/info"` or `"/exchange"`.

- body:

  (list) the request body, serialised with `auto_unbox`.

- .perform:

  (function) the httr2 perform function. Default
  [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html).

- .parser:

  (function) post-processing applied to the parsed response body.
  Default `identity`.

- is_async:

  (scalar\<logical\>) whether `.perform` returns promises. Default
  `FALSE`.

- timeout:

  (scalar\<numeric in \]0, Inf\[\>) request timeout in seconds. Default
  `30`.

- parse_envelope:

  (function) turns a response into data and raises on error; the
  overridable error seam. Default `parse_hyperliquid_response()`.

## Value

(any) parsed and post-processed API response data, or a promise thereof.

## Details

Hyperliquid authenticates by signing the request **body** (a wallet
signature embedded as a `signature` field), not the HTTP request, and
requires the body on the wire exactly as it was signed — including
`vaultAddress`/`expiresAfter` serialised as JSON `null`. The body is
therefore pre-serialised here with
`jsonlite::toJSON(..., auto_unbox = TRUE, null = "null")` and passed to
connectcore's funnel with `body_format = "raw"`, which sends it
byte-verbatim via httr2::req_body_raw — no `NULL`-pruning, no
re-encoding — so the exact signed bytes reach the wire. (The default
request-signing `.sign` seam is a no-op for Hyperliquid; signing happens
in the body content, not the request.)

### Sync vs Async

The `.perform` argument controls execution mode:

- [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html)
  (default): synchronous, returns an
  [httr2::response](https://httr2.r-lib.org/reference/response.html).

- [`httr2::req_perform_promise`](https://httr2.r-lib.org/reference/req_perform_promise.html):
  asynchronous, returns a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html).

Errors are surfaced by `parse_envelope`, not httr2: connectcore's funnel
disables httr2's auto-error so the API's own error body (HTTP 422 text
for `/info`, an `{status:"err"}` envelope for `/exchange`) is formatted
by the parser.
