# Fixtures for the staking domain. Each function returns the R list that
# jsonlite::fromJSON(simplifyVector = FALSE) yields for the corresponding
# endpoint, so parsers and the mock router can be exercised offline.
#
# READ fixtures are REAL mainnet /info responses captured on 2026-06-06 for the
# staker/validator 0x5ac99df645f3414876c816caa18b2d234024b487 (the rewards
# fixture is a representative four-row slice of a much longer history). The
# tokenDelegate WRITE fixture is the standard /exchange success envelope
# (the SDK posts a user-signed action and receives {status:"ok", response:...}).

# delegatorSummary -> parse_staking_summary (single object).
fixture_staking_summary <- function() {
  return(list(
    delegated = "70064.72854868",
    undelegated = "0.0",
    totalPendingWithdrawal = "0.0",
    nPendingWithdrawals = 0
  ))
}

# delegations -> parse_staking_delegations (array of objects).
fixture_staking_delegations <- function() {
  return(list(
    list(
      validator = "0x5ac99df645f3414876c816caa18b2d234024b487",
      amount = "70064.72854868",
      lockedUntilTimestamp = 1735466781353
    )
  ))
}

# delegatorRewards -> parse_staking_rewards (array of objects).
fixture_staking_rewards <- function() {
  return(list(
    list(time = 1780790400085, source = "delegation", totalAmount = "4.18960439"),
    list(time = 1780790400085, source = "commission", totalAmount = "97.26830074"),
    list(time = 1780704000050, source = "delegation", totalAmount = "4.18331289"),
    list(time = 1780704000050, source = "commission", totalAmount = "97.31493716")
  ))
}

# delegatorHistory -> parse_delegator_history (array of {time, hash, delta}).
# delta is key-discriminated: {delegate:{...}} and {cDeposit:{...}} both occur.
fixture_delegator_history <- function() {
  return(list(
    list(
      time = 1735380381353,
      hash = "0x55492465cb523f90815a041a226ba90147008d4b221a24ae8dc35a0dbede4ea4",
      delta = list(
        delegate = list(
          validator = "0x5ac99df645f3414876c816caa18b2d234024b487",
          amount = "10000.0",
          isUndelegate = FALSE
        )
      )
    ),
    list(
      time = 1735380381116,
      hash = "0xf5e606e23ab64020662e041a226ba7015e00c5caca9f7ec90cf4c99210aa4a89",
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
