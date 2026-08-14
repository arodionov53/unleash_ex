# Precompute parsed constraint values at poll time

## Summary

Constraint `"value"` strings (numeric, semver, date) are re-parsed on every
`enabled?`/`get_variant` call. Parse them once when features are fetched from the
server and store the result alongside the constraint — same pattern as the existing
`precompute_context_atom`.

## Expected outcome

- Zero string-parsing allocations on the feature-evaluation hot path for NUM_*,
  SEMVER_*, and DATE_* constraint operators.
- No behavior change for callers — identical evaluation results.

## Acceptance criteria

- [ ] `precompute/1` (or extended `precompute_context_atom/1`) pre-parses and stashes
      the constraint value for numeric, semver, and date operators when features are
      stored in ETS.
- [ ] `check/3` clauses use the pre-parsed value; fall back to runtime parsing if the
      key is absent (backward compat with in-flight constraints).
- [ ] `mk_semver/1` does not crash on malformed version strings (e.g. `"1.2.3-beta"`).
- [ ] Existing tests pass; new unit tests cover the precompute path and the `mk_semver`
      edge case.
- [ ] `mix credo --strict` and `mix dialyzer` remain clean.
