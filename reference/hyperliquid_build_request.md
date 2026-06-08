# Build and Execute a Hyperliquid API Request

Constructs an
[httr2::request](https://httr2.r-lib.org/reference/request.html) for one
of Hyperliquid's two POST endpoints (`/info` or `/exchange`), serialises
`body` as JSON, performs it via the supplied `.perform` function, and
parses the response. This is the single point through which all
Hyperliquid API calls flow.

## Usage

``` r
hyperliquid_build_request(
  base_url,
  path,
  body,
  .perform = httr2::req_perform,
  .parser = identity,
  is_async = FALSE,
  timeout = 30
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

## Value

(any) parsed and post-processed API response data, or a promise thereof.

## Details

### Sync vs Async

The `.perform` argument controls execution mode:

- [`httr2::req_perform`](https://httr2.r-lib.org/reference/req_perform.html)
  (default): synchronous, returns an
  [httr2::response](https://httr2.r-lib.org/reference/response.html).

- [`httr2::req_perform_promise`](https://httr2.r-lib.org/reference/req_perform_promise.html):
  asynchronous, returns a
  [promises::promise](https://rstudio.github.io/promises/reference/promise.html).

Errors are surfaced by `parse_hyperliquid_response()`, not httr2: the
request is built with `req_error(is_error = ...)` returning `FALSE` so
the API's own error body (HTTP 422 text for `/info`, an `{status:"err"}`
envelope for `/exchange`) is formatted by the parser.
