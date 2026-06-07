# Fixtures for HyperliquidTransfers.
#
# Every /exchange transfer action returns the same acknowledgement envelope on
# success: {status:"ok", response:{type:"default"}}. These functions return the
# R list that jsonlite::fromJSON(simplifyVector = FALSE) yields for that body.
# Shapes are taken from the reference SDK
# (_research_hyperliquid/hyperliquid-python-sdk/hyperliquid/exchange.py): the
# transfer actions are not order actions, so they resolve to the "default"
# response type rather than the order "statuses" envelope.
#
# One function per endpoint (all identical bodies) so the integration mock
# router can dispatch on the action `type`.

# The shared success acknowledgement for any transfer action.
fixture_transfer_ack_body <- function() {
  return(list(status = "ok", response = list(type = "default")))
}

fixture_usd_class_transfer <- function() {
  return(fixture_transfer_ack_body())
}

fixture_usd_send <- function() {
  return(fixture_transfer_ack_body())
}

fixture_spot_send <- function() {
  return(fixture_transfer_ack_body())
}

fixture_withdraw <- function() {
  return(fixture_transfer_ack_body())
}

fixture_send_asset <- function() {
  return(fixture_transfer_ack_body())
}

fixture_sub_account_transfer <- function() {
  return(fixture_transfer_ack_body())
}

fixture_sub_account_spot_transfer <- function() {
  return(fixture_transfer_ack_body())
}

fixture_vault_transfer <- function() {
  return(fixture_transfer_ack_body())
}
