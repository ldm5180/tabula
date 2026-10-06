# tabula

Tables in and out for Ada 2022: TOML read (typed knob getters with
fallbacks over ada_toml, `Tabula.Config`) and written (`Tabula.Emit`),
and CSV read and written (`Tabula.Csv`), over a SPARK-proven core --
the decimal shape and scale (`Tabula.Decimals`), the text of TOML
scalars (`Tabula.Toml_Text`) and the CSV scanner (`Tabula.Csv_Scan`) --
packaged as a reusable, independently proven crate.

Two rules hold for every addition:

- **Text in, text out.**  The CSV reader hands fields over as text and
  the writers take text.  A consumer that wants exact decimals parses
  and prints them itself; tabula forms no number on the way.  The one
  float the crate touches is a TOML float, and `Get_Scaled` lets it
  leave at once as an integer.
- **The reading policy stands, and nothing raises.**  An ABSENT knob
  silently keeps the caller's fallback (a config file states only what
  it changes); a PRESENT but wrong-typed, out-of-range, or
  empty-when-required knob keeps the fallback AND warns through the
  table's `Warner`.  A config file can degrade a run, never crash it.  A
  writer refuses what it cannot write and lands nothing; the CSV reader
  reports a refused file as an outcome with its line.  Do not guess a
  CSV dialect, and do not hold a whole CSV file in memory to read or
  write it.

## Commands

- `make build`   — build the library (`alr build`)
- `make test`    — AUnit suite in BOTH modes (release -O3, debug -O0), offline
- `make features` — the Gherkin features under `tests/features/` in both
  modes, on fabula, printing the report as it goes; checks the summary
  line, since fabula exits 0 for a missing path.  `alr test` runs them
  too
- `make features-report` — the living documentation: the features with
  `--report-json`, rendered by multiple-cucumber-html-reporter
  (`tools/features-report`, node) into `obj/features-report/html`.  CI
  keeps it with every run and publishes it from main to
  https://ldm5180.github.io/tabula/
- `make prove`   — SPARK proof, `--checks-as-errors=on`; must exit 0;
  a new core unit is withed by `proof/src/core_closure_proof.ads`
- `make format`  — `gnatformat --check` over all committed Ada sources
  (it reads `git ls-files`: stage a new file first).  gnatformat's
  lexer refuses a container aggregate opening on a short hex-digit
  string (`["a"]`, `["1"]`) as a bad brackets encoding
- `make example` / `make run` — build / run the demo main (pure, so CI
  runs it)
- `alr --non-interactive build --validation` — warnings-as-errors gate (CI)

## Layout

- `src/core/` — the SPARK core (`Tabula.Decimals`, `Tabula.Toml_Text`,
  `Tabula.Csv_Scan`, and the root's calendar types): every unit carries
  `SPARK_Mode`, does zero IO, and may `with` only other core units and
  sml (the CSV scanner is an sml machine; `sml` is a declared
  dependency that takes fabula's pin).
- `src/app/`  — the ada_toml adapter (`Tabula.Config`): all ada_toml
  specifics stay behind this one unit; parser refusals become a
  `Malformed` status at this boundary and never escape as exceptions.
  The writer (`Tabula.Emit`) builds on the core's text functions and
  `Tabula.Staged_Files` (write beside, rename into place);
  `Tabula.Text_Lists` is the list of texts the writers take.  The CSV
  reader (`Tabula.Csv`) feeds the core scanner a block at a time.
- `tests/` — AUnit suite (`test_tabula.gpr`, driver `test_runner.adb`)
  and the Gherkin features: `tests/features/*.feature`, run by
  `tabula_features.ads` (`Fabula.Main` over `Tabula_Steps`).  The steps
  are events of sml machines, one region per thing a step acts on --
  `Tabula_Steps.Configs` (where the table comes from), `.Knobs` (what
  is read from it), `.Walks` (the array and key walkers), `.Emits` (a
  document written and saved), `.Csv_Files` (a CSV file given, read and
  checked) -- each a child with
  its own transition table, over the `Tabula_Steps.Flows` runner; a
  step no region takes fails naming every region's state.
  `Tabula_World` is the recording warner, the parse and the load the
  suite and the features share.  A config a scenario needs is a doc
  string; one whose file is the behavior is a named file,
  `tests/features/configs/<name>.toml`.
- `example/` — standalone demo main; pure, built and run in CI.
- `proof/` — gnatprove harness (`proof.gpr`; sources `../src/core`
  directly and withs only sml, keeping foreign code out of the proof
  tree).
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
- Tests are layers -- guidance for judgement, not a mechanical rule.
  A unit test typically tests a single function, or at most a simple
  interaction between two, and the unit tests always cover the function
  they test completely.  A feature (BDD) tests the larger interactions
  that form a higher-level, conceptual feature, in the consumer's
  words, one fact per step, and checks only what a consumer observes:
  a reading, a status, which knob was complained about -- never a
  warning's wording, which stays in the unit tests.  Coverage is wanted
  and duplication across the layers is fine: a test is removed only
  when it is purely redundant -- an integration test a BDD scenario
  fully supplants.  Features are never removed.

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
- fructus, arb-ada and firescan-ada read through the getters: never
  change what an existing getter returns or warns.

## Writing and CSV contracts (do not break)

- What `Tabula.Emit` writes, `Tabula.Config` reads back to the same
  values; a number is written only when `Is_Number_Text` says it reads
  back as written.  A document that refused anything is not saved, and
  `Save` and the CSV `Close` land a file whole by a rename, or not at
  all.
- What the CSV `Writer` writes, `Each_Row` reads back the same; the
  writer refuses a record past the scanner's bounds rather than write
  one the reader would refuse.
- The scanner's record is bounded (`Max_Record_Length`, `Max_Fields`);
  a record past a bound is refused, never cut.
