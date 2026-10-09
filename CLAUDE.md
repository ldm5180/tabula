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
  float the crate touches is a TOML float, and `Get_Scaled` (or
  `Each_Scaled`, for a list) lets it leave at once as an integer; the
  value walk hands it over as the literal the document wrote, read from
  the text, never through the double.
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
  `Tabula.Toml_Source`, `Tabula.Csv_Scan`, and the root's calendar
  types and `Continues_Codepoint`): every unit carries
  `SPARK_Mode`, does zero IO, and may `with` only other core units and
  sml (the CSV scanner is an sml machine; `sml` is a declared
  dependency that takes fabula's pin).
- `src/app/`  — the ada_toml adapter (`Tabula.Config`, and its child
  `Tabula.Config.Values`, the walk of every value with its kind and
  text): all ada_toml specifics stay behind these two, which share the
  helpers `Tabula.Config`'s private part declares; parser refusals
  become a `Malformed` status at this boundary and never escape as
  exceptions.  The parser is handed the text with a line end after it
  when it has none (`Tabula.Toml_Source.Line_Ended`): ada_toml's lexer
  fails a precondition on a date or a time that ends the text.  A table
  carries its document's text, so a float's
  literal is read as written (`Tabula.Toml_Source` finds it by the
  place the parser recorded, `Tabula.Toml_Text.Decimal_Of` reads it).
  The writer (`Tabula.Emit`) holds the lines of the table entry at
  hand until a header ends it, so a `Document (Aligned)` can pad each
  key to the entry's widest; it builds on the core's text functions and
  `Tabula.Staged_Files` (write beside, rename into place);
  `Tabula.Text_Lists` is the list of texts the writers take.  The CSV
  reader (`Tabula.Csv`) feeds the core scanner a block at a time.
- `tests/` — AUnit suite (`test_tabula.gpr`, driver `test_runner.adb`)
  and the Gherkin features: `tests/features/*.feature`, run by
  `tabula_features.ads` (`Fabula.Main` over `Tabula_Steps`).  The steps
  are events of sml machines, one region per thing a step acts on --
  `Tabula_Steps.Configs` (where the table comes from), `.Knobs` (what
  is read from it), `.Walks` (the array, key and value walkers), `.Emits` (a
  document written and saved), `.Csv_Files` (a CSV file given, read and
  checked) -- each a child with
  its own transition table, over the `Tabula_Steps.Flows` runner; a
  step no region takes fails naming every region's state.
  `Tabula_World` is the recording warner, the parse and the load the
  suite and the features share, and the `Recorder` listener a test or
  a scenario owns.  A config a scenario needs is a doc
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

## Dependency injection

- No package-level variable, set-once cell or singleton, in the crate or
  forced on its callers.  What a subprogram needs arrives as a
  parameter, a generic formal, or a field of an object it was handed.
  Constants are fine.
- Every callback API has a form that carries the caller's state as an
  object: the table's warnings go to a `Tabula.Config.Listener`, and
  each walker hands its items to a visitor interface
  (`String_Visitor`, `Scaled_Visitor`, `Section_Visitor`,
  `List_Visitor`, `Key_Visitor`, `Tabula.Config.Values.Value_Visitor`,
  `Tabula.Csv.Row_Visitor`), each with
  its own primitive's name so one caller type can be several.  A list
  of lists (`Each_List`) hands each inner list over as a `Table`, not
  a new type, so the keyless `Each_String` / `Each_Scaled` read it and
  a reader learns no second shape; its name (key and place) rides in
  the table, privately, for the warnings.  The older
  access-to-procedure forms stay, as thin adapters over these: a new
  callback API gets the object form first.

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
  through the table's `Warner` or `Listener`, prefixed with the table's
  label.
- The quoted exact-decimal form (`bump = "0.02"`) exists because ada_toml
  0.5.0 drops the leading zeros of a bare float's fraction (0.02 → 0.2);
  keep the quoted path exact (`'Value` on a shape the proven
  `Is_Plain_Decimal` accepted) and keep rejecting exotica (exponents,
  based literals, underscores).
- `Load` distinguishes `Missing` (no file — callers usually keep defaults
  and log at most an info line) from `Malformed` (parser refusal, with its
  message as `TOML.Format_Error` writes it, `3:1: invalid syntax`, the
  line and column first); both leave the empty table, whose every getter
  falls back.
- fructus, arb-ada and firescan-ada read through the getters: never
  change what an existing getter returns or warns.
- The value walk (`Tabula.Config.Values.Each_Value`) never warns: every
  value has a kind.  The one complaint it can make is a float whose
  literal is not found at the place the parser recorded, which only a
  parser whose places differ from ada_toml's would produce; that value
  is skipped rather than handed over inexactly.

## Writing and CSV contracts (do not break)

- What `Tabula.Emit` writes, `Tabula.Config` reads back to the same
  values; a number is written only when `Is_Number_Text` says it reads
  back as written.  A default-initialized `Document` is `Plain` and
  writes `key = value` byte for byte as it always has; aligned keys
  (`Document (Aligned)`) are the caller's choice, never a default.
  A document that refused anything is not saved, and `Save` and the
  CSV `Close` land a file whole by a rename, or not at all.
- What the CSV `Writer` writes, `Each_Row` reads back the same; the
  writer refuses a record past the scanner's bounds rather than write
  one the reader would refuse.
- The scanner's record is bounded (`Max_Record_Length`, `Max_Fields`);
  a record past a bound is refused, never cut.
