# Hyperliquid return shapes

Reusable roxyassert `@type` record shapes for the `data.table`s returned
by the Hyperliquid client classes. `@genassert` emits a standalone
`assert_type_<Shape>()` validator for each shape and `@exportassert`
exports them (alongside this block's `assert_args_*`/`assert_return_*`),
so callers and the backtester can validate any value against a
Hyperliquid shape as a conformance oracle.

Shapes: `PerpMeta`, `Candles`, `L2Level`, `Position`, `MarginSummary`,
`Fill`, `OrderResult`, `FundingHistory`, `StakingSummary`,
`TransferAck`.
