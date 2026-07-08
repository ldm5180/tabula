# tabula

Narrow TOML reading for Ada 2022 — typed knob getters with fallbacks over
ada_toml (`Tabula.Config`) and a SPARK-proven decimal shape check
(`Tabula.Decimals`) gating the quoted exact-decimal form, packaged as a
reusable, independently proven crate.

The policy is the product: an ABSENT knob silently keeps the caller's
fallback (a config file states only what it changes); a PRESENT but
wrong-typed, out-of-range, or empty-when-required knob keeps the fallback
AND warns through the table's `Warner`. A config file can degrade a run,
never crash it — no getter raises.

## Commands

- `make build`   — build the library (`alr build`)
- `make test`    — AUnit suite in BOTH modes (release -O3, debug -O0), offline
- `make prove`   — SPARK proof, `--checks-as-errors=on`; must exit 0
- `make format`  — `gnatformat --check` over all committed Ada sources
- `make example` / `make run` — build / run the demo main (pure, so CI
  runs it)
- `alr --non-interactive build --validation` — warnings-as-errors gate (CI)

## Layout

- `src/core/` — the SPARK core (`Tabula.Decimals`): every unit carries
  `SPARK_Mode`, does zero IO, and may `with` only other core units.
- `src/app/`  — the ada_toml adapter (`Tabula.Config`): all ada_toml
  specifics stay behind this one unit; parser refusals become a
  `Malformed` status at this boundary and never escape as exceptions.
- `tests/` — AUnit suite (`test_tabula.gpr`, driver `test_runner.adb`).
- `example/` — standalone demo main; pure, built and run in CI.
- `proof/` — gnatprove harness (`proof.gpr`; sources `../src/core`
  directly and withs nothing, keeping foreign code out of the proof tree).
- `docs/tdd-log.md` — git-ignored TDD audit log.

## SPARK

- Every `src/core` unit carries `SPARK_Mode`. After any core change,
  `make prove` must exit 0 (level 2, checks-as-errors). CI enforces the same.
- Prefer results over exceptions; document and prove behavior with
  contracts (`Pre`, `Post`, loop invariants).

## TDD protocol (strict)

- Red/green/refactor, always: failing test first (RED = compile error or
  failed assertion), then the minimal code (GREEN), then refactor under
  green. No production code without a preceding failing test.
- Log every cycle in `docs/tdd-log.md` (git-ignored, newest entries on top):
  date, what changed, exact RED output, GREEN pass counts.
- One `<unit>_tests.ads/.adb` pair per library unit under `tests/src/`,
  registered in `tabula_suite.adb`. Test routines use
  `AUnit.Assertions.Assert` and are wired via `Register_Routine`.

## Programming best practices

- Lean hard into the type system; keep code DRY.
- Extract pure functions whenever possible — it forces naming and generality.
- Keep functions and procedures short and focused; move any second code block
  into its own named subprogram.
- Push exceptions and defensive programming into contracts and let the proof
  system do the heavy lifting; `SPARK_Mode => On` as much as possible.

## Style

- Formatting is `gnatformat`-enforced; wrap hand-aligned tables in
  `--!format off` / `--!format on`.
- Follow the Alire validation-profile switch set; fix warnings, never
  suppress them without a comment saying why.

## Commit style

- gitmoji `:code:` shortcode prefix + capitalized, imperative subject, no
  trailing period (`:sparkles:` feature, `:bug:` fix, `:recycle:` refactor,
  `:white_check_mark:` tests, `:wrench:` tooling, `:memo:` docs, `:fire:`
  removal).
- Never put test / prove / format result counts in commit messages.

## Reading contracts (do not break)

- Absence is silent; only a present-but-unusable knob warns, exactly once,
  through the table's `Warner`, prefixed with the table's label.
- The quoted exact-decimal form (`bump = "0.02"`) exists because ada_toml
  0.5.0 drops the leading zeros of a bare float's fraction (0.02 → 0.2);
  keep the quoted path exact (`'Value` on a shape the proven
  `Is_Plain_Decimal` accepted) and keep rejecting exotica (exponents,
  based literals, underscores).
- `Load` distinguishes `Missing` (no file — callers usually keep defaults
  and log at most an info line) from `Malformed` (parser refusal, with its
  message); both leave the empty table, whose every getter falls back.
