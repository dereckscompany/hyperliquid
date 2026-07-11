# Client-order-id helpers (R/cloid.R): the format predicate `is_cloid()` and the
# deterministic tag -> cloid map `as_cloid()`. Covers the regex acceptance and
# rejection table, vectorisation, NA handling, case normalisation, determinism, a
# pinned known-answer, and round-trip stability.

test_that("is_cloid accepts only the 0x + 32-hex form (case-insensitively)", {
  valid <- c(
    "0x1234567890abcdef1234567890abcdef",
    "0xABCDEF7890ABCDEF1234567890ABCDEF", # upper-case hex accepted
    "0X1234567890abcdef1234567890abcdef", # upper-case prefix accepted
    new_cloid()
  )
  expect_true(all(is_cloid(valid)))

  invalid <- c(
    "1234567890abcdef1234567890abcdef", # no 0x prefix
    "0x1234567890abcdef1234567890abcde", # 31 hex, too short
    "0x1234567890abcdef1234567890abcdef0", # 33 hex, too long
    "0x1234567890abcdefg234567890abcdef", # non-hex character
    "0x", # prefix only
    "", # empty
    "my-run-42:BTC:entry" # a free-form tag
  )
  expect_false(any(is_cloid(invalid)))
})

test_that("is_cloid is vectorised and preserves NA", {
  out <- is_cloid(c("0x1234567890abcdef1234567890abcdef", "nope", NA))
  expect_identical(out, c(TRUE, FALSE, NA))
  expect_identical(is_cloid(character(0)), logical(0))
})

test_that("as_cloid passes a valid cloid through, lowercased", {
  expect_identical(
    as_cloid("0xABCDEF7890ABCDEF1234567890ABCDEF"),
    "0xabcdef7890abcdef1234567890abcdef"
  )
  cl <- new_cloid() # already lowercase and valid: returned unchanged
  expect_identical(as_cloid(cl), cl)
})

test_that("as_cloid maps a free-form tag to a valid, canonical cloid", {
  out <- as_cloid("my-run-42:BTC:entry")
  expect_true(is_cloid(out))
  expect_identical(out, tolower(out))
  expect_identical(nchar(out), 34L)
})

test_that("as_cloid is deterministic and matches the pinned known answer", {
  tag <- "trader:BTC:long:2026-07-11"
  expect_identical(as_cloid(tag), as_cloid(tag))
  # Pinned once against "0x" + first 16 bytes of openssl::sha256(charToRaw(tag)).
  # A change here means the idempotency mapping moved and every previously stored
  # cloid would silently orphan, so this value is load-bearing.
  expect_identical(as_cloid(tag), "0x1e147a9ee9732b1b21238ed02f682b35")
})

test_that("as_cloid is vectorised, NA-preserving, and idempotent", {
  x <- c("tag-one", "0xABCDEF7890ABCDEF1234567890ABCDEF", NA, "tag-two")
  out <- as_cloid(x)
  expect_identical(length(out), length(x))
  expect_true(all(is_cloid(out[!is.na(x)])))
  expect_true(is.na(out[3]))
  # Round-trip stability: as_cloid(as_cloid(x)) == as_cloid(x).
  expect_identical(as_cloid(out), out)
  expect_identical(as_cloid(character(0)), character(0))
})
