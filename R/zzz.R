# File: R/zzz.R
# Package load hook and data.table non-standard-evaluation symbol declarations.

# Suppress R CMD check NOTES for data.table non-standard evaluation symbols.
# The column symbols below are referenced bare inside data.table `[` calls in the
# backfill layer (R/backfill.R).
utils::globalVariables(c(
  ".",
  ".N",
  ".SD",
  ":=",
  "..out_cols",
  "symbol",
  "interval",
  "datetime",
  "coin",
  "time"
))
