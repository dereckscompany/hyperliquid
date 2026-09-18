# Fixtures for the staking domain. Each function returns the R list that
# jsonlite::fromJSON(simplifyVector = FALSE) yields for the corresponding
# endpoint, so parsers and the mock router can be exercised offline.
#
# Every READ fixture is AUTHORED SYNTHETIC DATA, hand-written to be
# shape-faithful to Hyperliquid's own documented /info responses for a
# staker/validator (the rewards fixture is a representative four-row slice
# standing in for a much longer history) -- it is never captured from a live
# mainnet account, not even scrubbed, and the validator is a patterned
# placeholder address (`0x000...0010`), never a real validator's identity. This
# is a public repository; nothing here may ever be replaced with a live
# capture (fleet fixture-authoring rule, ratified 2026-07-05, re-ratified
# 2026-09-17). The tokenDelegate WRITE fixture is the standard /exchange
# success envelope (the SDK posts a user-signed action and receives
# {status:"ok", response:...}).

# delegatorSummary -> parse_staking_summary (single object).
fixture_staking_summary <- function() {
  return(list(
    delegated = "50000.0",
    undelegated = "0.0",
    totalPendingWithdrawal = "0.0",
    nPendingWithdrawals = 0
  ))
}

# delegations -> parse_staking_delegations (array of objects).
fixture_staking_delegations <- function() {
  return(list(
    list(
      validator = "0x0000000000000000000000000000000000000010",
      amount = "50000.0",
      lockedUntilTimestamp = 1735466781353
    )
  ))
}

# delegatorRewards -> parse_staking_rewards (array of objects).
fixture_staking_rewards <- function() {
  return(list(
    list(time = 1780790400085, source = "delegation", totalAmount = "5.0"),
    list(time = 1780790400085, source = "commission", totalAmount = "100.0"),
    list(time = 1780704000050, source = "delegation", totalAmount = "4.5"),
    list(time = 1780704000050, source = "commission", totalAmount = "95.0")
  ))
}

# delegatorHistory -> parse_delegator_history (array of {time, hash, delta}).
# delta is key-discriminated: {delegate:{...}} and {cDeposit:{...}} both occur.
fixture_delegator_history <- function() {
  return(list(
    list(
      time = 1735380381353,
      hash = "0x000000000000000000000000000000000000000000000000000000000000000c",
      delta = list(
        delegate = list(
          validator = "0x0000000000000000000000000000000000000010",
          amount = "10000.0",
          isUndelegate = FALSE
        )
      )
    ),
    list(
      time = 1735380381116,
      hash = "0x000000000000000000000000000000000000000000000000000000000000000d",
      delta = list(
        cDeposit = list(
          amount = "10000.0"
        )
      )
    )
  ))
}

# tokenDelegate -> parse_token_delegate (/exchange success envelope).
fixture_token_delegate_response <- function() {
  return(list(
    status = "ok",
    response = list(type = "default")
  ))
}
