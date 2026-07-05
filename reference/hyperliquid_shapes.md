# Hyperliquid return shapes

Reusable roxyassert `@type` record shapes for the `data.table`s returned
by the Hyperliquid client classes. Each shape is referenced by a
method's `@return` as `promise<Shape>`, so the contract roclet expands
it inline into that method's generated `assert_return_*` – no standalone
`assert_type_<Shape>()` is emitted. hyperliquid is a leaf connector:
nothing internal calls a per-shape validator and no downstream package
validates against these shapes, so there is no `@genassert` (no callable
validators to generate) and no `@exportassert` (nothing to export).

Shapes: `PerpMeta`, `Candles`, `L2Level`, `Position`, `MarginSummary`,
`Fill`, `OrderResult`, `FundingHistory`, `StakingSummary`,
`TransferAck`.
