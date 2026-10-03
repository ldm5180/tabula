# Feature tests plan

The crate's behavior, stated in Gherkin and run against the real
reader.  `*.feature` files under `tests/features/` say what a config
file does to a run -- a knob reads with its type, an absent knob keeps
the default silently, a wrong one warns and keeps the default, a bare
`0.02` reads as `0.02` -- and a small Ada step registry on
[fabula](https://github.com/ldm5180/fabula) runs them, each feature's
steps an sml state machine.  The AUnit suite keeps the mechanism; the
features keep the story, and are published as living documentation.

This is the third plan of a family.  `fructus/docs/feature-tests-plan.md`
set the shape and `nuntius/docs/feature-tests-plan.md` (implemented
and merged 2026-10-03) settled the rest; every decision below that is
not tabula's own comes from there.  What is tabula's own: the world
is a TOML document, so the "bytes that do not fit a line" rule
becomes "a config that does not fit a line", and there are two ways
to hold one.

## How to use this plan

Work the items in order; each is one TDD cycle (RED first, the exact
assertion given) and one commit, logged in `docs/tdd-log.md`.  F0 is
the dependency, F1 the runner and the machine runner, F2 the world;
F3-F6 are the four features of the first wave, each lifted from named
AUnit tests; F7 the living documentation; F8 the testing-layers
judgement; F9 the docs.  After each item: `alr --non-interactive
build --validation`, `make test`, `make features`, `make format`.
Nothing here touches `src/`, so `make prove` is never owed by it.

Decisions, taken up front, all settled by the nuntius work:

- **Steps are sml machines from the first commit.**  One generic
  runner (`Tabula_Steps.Flows`: `Sml.Simple_Machines` over the whole
  `Step_Kind`, a `Step_Context`, the operator layer, `Take`); one
  machine per feature in its own child; the registry a table of
  regions.  Every condition that chose a body is a guard, followed by
  an unguarded fallback row whose action fails the step with the
  reason; "act, then branch" is a follow-up event.  A step taken out
  of order fails naming every feature's state.
- **`make features` streams, in colour.**  Each mode tees the
  runner's report and checks its exit status and summary line from
  the copy; on a terminal the runner runs under `script(1)` so fabula
  still sees a terminal and colours.
- **Living documentation, published.**  `--report-json`, rendered by
  multiple-cucumber-html-reporter, kept as a CI artifact on every run
  and deployed to GitHub Pages from main.
- **One test project, two mains.**  `tests/test_tabula.gpr` gains
  `with "fabula"` and `tabula_features.ads`; step packages in
  `tests/src/`, features in `tests/features/`.
- **A config that does not fit a line is a doc string or a named
  file** (section 3.2).
- **Tests are layers; coverage first.**  Unit tests fully cover the
  function they test; a test is removed only when it is an
  integration test a BDD scenario fully supplants.  Judged in F8, and
  the honest expectation for tabula is no removals.
- **A feature binds behavior, never implementation.**  Every check
  reads something a consumer of tabula observes and the spec
  promises: what a getter returns, a `Load_Status`, that a knob was
  complained about through the caller's own `Warner` (the contract's
  observation point) and which knob.  How a complaint is worded,
  which getter branch ran, what the gate function answers for a
  shape -- those are mechanism, and stay in the AUnit tests, which
  keep every assertion they have; a feature restates outcomes only.
  Setup stays white-box (doc strings, named configs, a recording
  warner).

### Do not

- Do not convert a captured decimal through `Long_Float`.  A `{float}`
  capture of `0.02` becomes `2.0000000000000000416E-02`, and the
  feature that exists to prove `0.02` reads exactly would then be
  comparing two inexact values.  A step compares what the reader
  returned against the capture's TEXT through the crate's own path:
  the reader's `Long_Float` against `Long_Float'Value` of a text the
  proven `Is_Plain_Decimal` accepted -- the same conversion the
  quoted form uses -- and never through fabula's `Real`.
- Do not put a quote inside a `{string}` capture.  fabula's `{string}`
  is double-quoted only, so a TOML line with a quoted value (`name =
  "ada"`) cannot be a quoted step argument.  It is a doc string or a
  named file (3.2).
- Do not spell a `/` after a letter in a step pattern.  fabula reads
  it as a choice (`is/are`) and it cannot be escaped; a path is a
  `{word}` capture.
- Do not read a file the feature did not name.  `Load` scenarios use
  `tests/features/configs/<name>.toml`, found from the feature file's
  own directory through the step's frame; a scenario that names a
  file the directory lacks fails saying so.
- Do not check how.  A step that wants a warning's wording, a byte,
  an internal count or which branch ran is a unit test; the feature's
  step stays at the outcome.  "a wrong-typed knob keeps its default
  and is complained about by name" is a feature; the exact text
  `wrong is not a number in 0 .. Natural'Last; using default` stays in
  `Tabula_Config_Tests`, and the truth table of `Is_Plain_Decimal`
  stays in `Tabula_Decimals_Tests`.
- Do not call a core function from a feature to test it.  The
  feature reads the consequence through the reader (a quoted `"1e3"`
  keeps its default); the function's own table is the unit test's.
- Do not add fabula to `proof/proof.gpr`.  The proof tree sources
  `src/core` and withs nothing.
- Do not fix fabula's `-gnatwu` warning (`fabula-run.adb:258`, a GNAT
  15 false positive) from here; it is a warning under the dependency
  profile and this crate builds clean with it (section 5).

## 1. What fabula is, in the terms this crate uses

A fabula binary is one instantiation of `Fabula.Main` over a
`Fabula.Registry` instance: an enumeration of step kinds, a table
mapping a Cucumber-expression pattern to a kind, an enumeration of
hook kinds with its table, a `Context` record one scenario owns, and
`Execute` / `Run_Hook`.  Checks record into an `Outcome`
(`Fabula.Check.Ints.Equal`, `Fabula.Check.Reals.Equal`,
`Fabula.Check.Text_Equal`, `Fabula.Check.Is_True`, `Fail_Step`); a
step that raises becomes a failed step and the run goes on.  Captures
read 1-based (`Fabula.Args.Int`, `.Text`, `.Word`); a step's doc
string reads through `Fabula.Args.Doc_String` (the lines joined by LF)
and `Doc_Type` (the content type after the opening fence); a data
table as raw cells or hashes.  The binary walks its paths sorted,
exits 1 on any failed scenario, prints `N Scenarios (...)`, and with
`--report-json FILE` writes the Cucumber JSON the living docs render.

Two limits matter here.  `Fabula.Limits.Max_Line_Length` is 2 048, and
a doc string's lines are each a line; `Max_Doc_Lines` is 4 096.  No
config this crate's features need approaches either, which is why the
doc string, not the file, is the default form (3.2).

In this crate the `Context` is small by nature: the parsed table, the
label, the recorded warnings and the last reading.  `Tabula.Config.
Table` is a record over an ada_toml value (a reference), so it copies
cheaply; nothing needs to live at library level except the warner,
which must be a library-level procedure because `Warner` is a
library-level access type -- the suite already keeps `Warnings` as
package state for that reason, and the world does the same.

## 2. Where things live

```
tests/
  features/
    knobs.feature              F3
    decimals.feature           F4
    sections.feature           F5
    files.feature              F6
    configs/                   named configs, one .toml per name (3.2)
      broken.toml
  src/
    tabula_features.ads        F1  the main: Fabula.Main instantiated
    tabula_steps.ads/.adb      F1  Step_Kind, Hook_Kind, the tables, the regions
    tabula_steps-flows.ads/.adb F1 the machine runner (nuntius's, verbatim)
    tabula_steps-configs.ads/.adb F1 region "config": where the table comes from
    tabula_steps-knobs.ads/.adb  F1 region "knobs": what is read from it
    tabula_steps-walks.ads/.adb  F5 region "walks": the array walkers
    tabula_world.ads/.adb      F2  the warner, the parse, the configs dir
  test_tabula.gpr              F1  with "fabula"; a second main
tools/
  features-report/             F7  package.json, package-lock.json, report.js
```

## 3. The step vocabulary

Every pattern, the kind it names (the `E_` literal), and what the
body does.  The "warned" steps read the warnings the world's recording
`Warner` received -- the handler a consumer passes, so what reaches it
is the contract, and the steps check WHICH knob was complained about,
never the wording; a check of a reading compares against the capture's
text, never through a `Long_Float` capture (the first Do-not).

| Pattern | Kind | Body |
|---|---|---|
| `a config labelled {string}:` + doc string | `E_Parse_Doc` | `Parse` the doc string under that label with the recording warner; the status kept |
| `a config labelled {string} from the file {word}` | `E_Load_File` | `Load (configs/<word>.toml)` (3.2); the status and error kept |
| `a config labelled {string} from a file that does not exist` | `E_Load_Missing` | `Load` of a name the directory lacks |
| `the section {word}` | `E_Take_Section` | the current table becomes `Section (T, word)` |
| `the boolean {word} is read with default {word}` | `E_Read_Bool` | `Get (T, key, Fallback)`; the reading kept |
| `the count {word} is read with default {int}` | `E_Read_Count` | `Get (T, key, Fallback)` |
| `the count {word} is read with default {int} and at least {int}` | `E_Read_Count_Min` | `Get (T, key, Fallback, Min)` |
| `the string {word} is read with default {string}` | `E_Read_String` | `Get (T, key, Fallback)` |
| `the non-empty string {word} is read with default {string}` | `E_Read_Required` | `Get (..., Require_Non_Empty => True)` |
| `the real {word} is read with default {word}` | `E_Read_Real` | `Get (T, key, Fallback)`, the fallback's text through the crate's own decimal path |
| `the strings of {word} are walked` | `E_Walk_Strings` | `Each_String`, the items kept in order |
| `the sections of {word} are walked` | `E_Walk_Sections` | `Each_Section`, each item's `name` kept |
| `{word} is asked for` | `E_Ask_Has` | `Has (T, key)` |
| `the config loaded` / `is malformed` / `is missing` | `E_Check_Status` | the kept `Load_Status`; `malformed` also wants a non-empty error |
| `the reading is {word}` | `E_Check_Reading` | the kept reading against the capture's text, by the reading's kind (3.3) |
| `the reading is the default` | `E_Check_Default` | the kept reading equals the fallback the read step gave |
| `nothing was warned` | `E_Check_Silent` | the recorded warnings are empty |
| `{word} was complained about` | `E_Check_Warned` | a recorded warning carries the table's label and names that key; its wording is the unit test's |
| `the items were {string}` | `E_Check_Items` | the walked items, comma-joined |
| `it is present` / `it is absent` | `E_Check_Present` / `E_Check_Absent` | the kept `Has` |

### 3.1 The features as machines

**As built (F1):** the four features share one vocabulary -- every
one of them gives a config and reads knobs from it -- and a step is
taken by exactly one region, so the regions split by what a step acts
on, not by which file the scenario sits in.  `config`
(`Tabula_Steps.Configs`): where the table comes from -- a doc string,
a named file, a section of it -- `Unparsed` -> `Parsed` / `Refused`.
`knobs` (`Tabula_Steps.Knobs`): what is read from it and the checks
of the reading -- `Unread` -> `Read`; its read rows ask `config`
whether a table is in hand (`Configs.Holds_Table`, a guard, refused
with "no config was given to read from").  `walks` (F5): the two
walkers and their items.  `decimals.feature` reads through `knobs`.
The design below was the draft; its states and guards survive, its
one-machine-per-feature split does not.

Each feature's machine has real states.  `knobs.feature`: `Unparsed`
(nothing to read from) -> `Parsed` (a table in hand) -> `Read` (a
reading in hand, checks allowed).  `files.feature`: `Unloaded` ->
`Loaded` / `Refused` (a `Load` that was `Missing` or `Malformed`, whose
only legal next steps are the status check and a read that must fall
back).  A `the reading is ...` step in `Parsed` -- nothing read yet --
is a step no region takes, and fails naming every feature's state.

The guards: `Key_Given` (the capture is a word), `Int_Given` (a count
capture reads as a whole number), `Decimal_Given` (the capture's text
passes `Is_Plain_Decimal` -- test machinery that says the feature
wrote a readable default, not an assertion about the gate), `Doc_Given` (the step
carries a doc string), `File_Named` (the named config exists in the
feature's directory), `Bool_Word` (`true`/`false`).  Each guarded row
has an unguarded fallback that fails the step with the reason: "no
config named retries in tests/features/configs", "0.0.2 is not a
plain decimal".

Two follow-up events: `E_Parsed` after a parse or load, whose guard
asks the kept status (Loaded moves to `Parsed`, anything else to
`Refused`); and a read step re-posted as `E_Reading_Kept` so the
"reading is ..." checks are rows of their own state.

### 3.2 A config that does not fit a line

A TOML document with a quoted value cannot be a `{string}` capture,
and one with several lines cannot be a line.  Two forms, chosen by
what the reader of the feature should see:

- **A short config is a doc string**, inline, where the reader can
  see the document and the expectation together.  This is the
  default form; every scenario of `knobs`, `decimals` and `sections`
  uses it.  The content type after the fence is `toml`, which the
  living docs render as such:

  ```gherkin
  Given a config labelled "feed config":
    """toml
    retries = 12
    bump = "0.05"
    """
  ```

- **A config on disk is a named file**, `tests/features/configs/<name>
  .toml`, when the behavior IS about the file: `Load`'s `Missing`
  versus `Malformed`, and a document long enough that inline it would
  bury the scenario.  The step names it (`from the file broken`), the
  world finds it beside the feature file through the step's frame
  (`Ada.Directories.Containing_Directory (Info.File) & "/configs"`),
  and a name the directory lacks fails the step saying so.  This is
  the same rule as nuntius's `bytes/<name>.hex`: the feature names
  the document, it never spells a path.

A doc string's lines are joined with LF, which is what ada_toml reads;
the world's `Parse_Doc` hands `Fabula.Args.Doc_String` to
`Tabula.Config.Parse` unchanged.

### 3.3 Comparing a reading

A reading is one of four kinds, kept in the context as a variant
(`Bool`, `Count`, `Text`, `Real`), and `the reading is {word}`
compares by kind: a boolean against `true`/`false`, a count against
the capture through `Fabula.Args.Int`, a string against the capture's
text, a real against `Long_Float'Value` of the capture's text once
`Is_Plain_Decimal` has accepted it -- so `the reading is 0.02` is
exact by construction, and a capture the gate refuses fails the step
("0.0.2 is not a plain decimal") rather than comparing wrong.  That
use of the gate is the test's own machinery for an exact comparison,
not a check of the gate; the gate's behavior is bound only through
what the reader returns (F4).  A
string with a space or a quote is not a `{word}`; `the reading is the
text {string}` takes it, and a string default is `{string}` in the
read step for the same reason.

## 4. Items

### F0 -- fabula is a test dependency

- **Where:** `alire.toml:16` (`aunit`, the one test dependency);
  `:22-23` (`[[pins]]`, `ada_toml`).
- **What is wrong:** nothing runs a `.feature` file.
- **Why:** the suite is AUnit end to end.
- **Fix:** `fabula = "*"` after `aunit`, and under `[[pins]]`
  `fabula = { url = "https://github.com/ldm5180/fabula.git", commit = "746a234df5581c2e38c4202aeee8b07473fb6a51" }`
  with a comment in the house shape.  tabula pins no `sml` of its
  own, so fabula's pin (`3ccd0e4`, sml-ada's main) brings `sml` in
  with no chain to run -- the opposite of nuntius, where the pins had
  to agree.  Should tabula ever pin `sml` itself, it must be that
  commit (Alire refuses two links to one crate).
- **RED first:** `alr --non-interactive build --validation` with the
  dependency line and no pin: alr warns `Generating possibly
  incomplete configuration because of missing dependencies` (fabula is
  in no index).  GREEN with the pin, verified in section 5.

### F1 -- The feature binary, the machine runner, and `make features`

- **Where:** `tests/test_tabula.gpr:1-2` (`with "aunit"; with
  "../tabula.gpr";`) and `:16` (`for Main`); `alire.toml:35-50` (the
  four `[[actions]]` of type `test`); `Makefile:17-21` (`test:`),
  `:29-33` (`format:`, whose `tests/src/*.ad[sb]` glob covers the new
  packages); `.github/workflows/ci.yml:64-69` (the `alr test` step).
- **What is wrong:** no runner, no machine runner, no target.
- **Why:** nothing of fabula is here yet.
- **Fix, three commits:**
  1. `with "fabula";` beside `aunit`, `for Main use ("test_runner.adb",
     "tabula_features.ads");` (a generic instantiation is a SPEC);
     `tests/src/tabula_features.ads` instantiating `Fabula.Main` over
     `Tabula_Steps`.  `Tabula_Steps` declares `Step_Kind` (`E_`
     literals), `Hook_Kind` (`Fresh_World`, `Stop_World`), `World`,
     `Step_Context` (`W`, `A`, `Info`, `R`, `Has_Next`, `Next`),
     `Then_Take`, the count helpers (`Count_Read`, `Count`,
     `Refuse_Count`), the `Steps` registry instance and the tables; its
     body is the regions table and the two hooks.
     `Tabula_Steps.Flows` is nuntius's `Nuntius_Steps.Flows` with the
     parent renamed: `with Sml.Machines.Operators; with
     Sml.Simple_Machines;`, the `Machines` instance over `Step_Kind`
     and `Step_Context`, `Op`, and `Take` with its bounded follow-ups.
     One smoke feature over a first `Tabula_Steps.Knobs` region
     (`Unparsed` -> `Parsed` -> `Read`, three steps) proves the
     wiring (section 5); F3 grows that region into the feature, and
     the smoke feature goes then.
     **As built:** the smoke feature is `knobs.feature`'s first
     scenario, "A count reads", which F3 grows -- nothing is added to
     be removed.  Two regions from the first commit (`config`,
     `knobs`; 3.1), and one hook, `Fresh_World`: the world holds no
     socket or task, so there is nothing for a `Stop_World` to stop.
  2. Two `[[actions]]` after the four: `["alr", "exec", "--",
     "tests/bin/release/tabula_features", "tests/features"]` and its
     `debug` twin.
  3. The `features` target, nuntius's verbatim (the `script(1)` form):

     ```make
     features:
     	alr exec -- gprbuild -p -j0 -XMODE=debug -P tests/test_tabula.gpr
     	alr exec -- gprbuild -p -j0 -XMODE=release -P tests/test_tabula.gpr
     	@log=$$(mktemp) && rc=$$(mktemp) && trap 'rm -f $$log $$rc' EXIT && \
     	if [ -t 1 ]; then tty=yes; else tty=; fi; \
     	for mode in debug release; do \
     	  echo "== features ($$mode)"; \
     	  run="alr exec -- tests/bin/$$mode/tabula_features tests/features"; \
     	  { if [ -n "$$tty" ]; then script -qefc "$$run" /dev/null; \
     	    else $$run; fi; echo $$? > $$rc; } | tee $$log; \
     	  [ "$$(cat $$rc)" = 0 ] || \
     	    { echo "features: $$mode: the runner failed"; exit 1; }; \
     	  sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$$//' $$log | \
     	    grep -qE '^[1-9][0-9]* Scenarios? \([0-9]+ passed\)$$' || \
     	    { echo "features: $$mode: a scenario did not pass"; exit 1; }; \
     	done; echo 'features: every scenario passed in both modes'
     ```

     fabula exits 0 for a missing path or an empty file, so the
     summary line is the check; the colour codes are stripped before
     the grep because on a terminal the runner coloured them.
- **RED first:** `make features` -- "No rule to make target".  Then,
  with the target and an empty step table, the smoke scenario's steps
  are `UNDEFINED` and the binary exits 1; the rows turn it green.

### F2 -- The world: the warner, the parse, the configs directory

- **Where:** `tests/src/tabula_config_tests.adb:14-32` (`Warnings`,
  `Record_Warning`, `Parse_Sample`, `Warned`).
- **What is wrong:** the recording warner and the parse-and-assert
  helper live inside one suite body.
- **Why:** they were written for one suite.
- **Fix:** `tests/src/tabula_world.ads/.adb` holds `Warnings` and
  `Record_Warning` (library-level, since `Warner` is a library-level
  access), `Warned`, `Reset` (the `Before` hook: clear the warnings),
  `Parse_Doc (Content, Label, Root, Status, Error)` and
  `Load_Named (Dir, Name, Label, Root, Status, Error)` over
  `Tabula.Config.Load`, plus `Named_Exists (Dir, Name)` for the guard
  and `Configs_Dir (Info)` from a frame.  The suite `with`s it and
  deletes its copies; `Parse_Sample`'s `Assert (Status = Loaded)`
  stays in the suite as its own one-line wrapper, since the world
  must not assert.  Only the fixture moves: every assertion the suite
  makes -- the warning texts above all -- stays in the suite, and the
  features restate outcomes only.
- **RED first:** the suite with its helpers deleted and `with
  Tabula_World;` added fails to compile (`file "tabula_world.ads" not
  found`); green when
  `make test` passes both modes with no assertion changed.
- **As built:** `Tabula_World` holds `Reset`, `Parse` (the recording
  parse, which starts each table's warnings empty, as `Parse_Sample`
  did), `Silent` and `Warned`; the warnings are a vector of messages,
  not one `;`-joined text, since a message itself carries `;` ("...;
  using default").  The suite's `Warnings = Null_Unbounded_String`
  reads `Silent`, the same claim.  `Load_Named`, `Named_Exists` and
  `Configs_Dir` arrive with F6, the first step that needs them.  The
  features' parse moved onto `Tabula_World.Parse` and the
  `Fresh_World` hook resets it.

### F3 -- `knobs.feature`: a knob reads with its type, or falls back

- **Where:** `tests/src/tabula_config_tests.adb:34-63` (`Test_Policy`),
  `:65-88` (`Test_Bounds`), `:252-263` (`Test_Has`); the policy at
  `src/app/tabula-config.ads:5-11`.
- **What is wrong:** the crate's one policy -- absence is silent,
  presence-but-wrong warns and falls back -- is stated as `Assert`
  messages across three tests and a README paragraph.
- **Why:** that is what a unit test is.
- **Fix:** the first feature and the first machine (`Unparsed` ->
  `Parsed` -> `Read`):

  ```gherkin
  Feature: A knob reads with its type, or keeps its default

    An absent knob keeps the caller's default silently: a config
    states only what it changes.  A present knob of the wrong type,
    out of range, or empty when substance is required keeps the
    default and is complained about through the handler the caller
    gave, by its table's label and its name.  No getter raises.

    Background:
      Given a config labelled "test config":
        """toml
        flag = true
        count = 7
        name = "ada"
        wrong = "not a number"
        zero = 0
        empty = ""
        """

    Scenario: A boolean reads
      When the boolean flag is read with default false
      Then the reading is true
      And nothing was warned

    Scenario: A count reads
      When the count count is read with default 0
      Then the reading is 7

    Scenario: A string reads
      When the string name is read with default "x"
      Then the reading is ada

    Scenario: An absent knob keeps its default, silently
      When the count absent is read with default 9
      Then the reading is the default
      And nothing was warned

    Scenario: A wrong-typed knob keeps its default, and is complained about
      When the count wrong is read with default 9
      Then the reading is the default
      And wrong was complained about

    Scenario: A count below its floor keeps its default, and is complained about
      When the count zero is read with default 5 and at least 1
      Then the reading is the default
      And zero was complained about

    Scenario: An empty string is a string, unless substance is required
      When the string empty is read with default "d"
      Then the reading is the text ""
      When the non-empty string empty is read with default "d"
      Then the reading is the default
      And empty was complained about

    Scenario: Presence is asked without a fallback, and never warns
      When wrong is asked for
      Then it is present
      When absent is asked for
      Then it is absent
      And nothing was warned
  ```

  The last scenario's `Then it is present` after a read: the machine
  allows `E_Ask_Has` from `Parsed` and from `Read`, both to `Read`.
  **As built:** `Has` is a reading of its own kind (`Presence`), so
  `it is present` / `it is absent` are rows of `Read` like every other
  check; a read in `Read` re-posts itself into `Unread` (`A_Again`),
  so each read's guarded rows are written once.  `nothing was warned`
  and `{word} was complained about` are rows of the `config` region:
  a complaint is the table's, made under its label, and a walk (F5)
  warns as much as a read does.  A check of the wrong kind fails
  saying so ("the reading is a COUNT, which ada cannot be"; "nothing
  was asked for: the reading is a COUNT").
- **RED first:** `make features` reports `a config labelled "test
  config":` `UNDEFINED`; the doc-string parse row turns it green, then
  each read and check in the order the scenario reads.  The values
  are `Test_Policy`'s and `Test_Bounds`' own; their assertions on the
  warnings' wording (`is not a number in 0 .. Natural'Last`, `in 1
  ..` for the floor, `is not a non-empty string`) stay there.

### F4 -- `decimals.feature`: a decimal reads exactly, and the gate holds

- **Where:** `tests/src/tabula_config_tests.adb:90-126` (`Test_Reals`);
  `tests/src/tabula_decimals_tests.adb:12-31` (`Test_Shapes`);
  `src/app/tabula-config.ads:76-89` (the real `Get` and the quoted
  form's reason); `src/core/tabula-decimals.ads:8-13`.
- **What is wrong:** the crate's reason to exist -- ada_toml 0.5.0
  read `0.02` as `0.2`, the pin fixes it, the quoted exact form stays
  -- is the most important fact in the tree and lives in a spec
  comment, a manifest comment and one test.
- **Why:** it is a bug's history, and histories get written where
  the fix landed.
- **Fix:** one feature, its reading checks exact by construction
  (3.3), and an outline over quoted shapes as the READER treats them
  -- a plain decimal reads exactly, anything fancier keeps the
  default and is complained about:

  ```gherkin
  Feature: A decimal reads exactly, bare or quoted

    Background:
      Given a config labelled "prices":
        """toml
        whole = 2
        plain = 1.5
        small = 0.02
        mixed = 1.05
        quoted = "0.02"
        signed = "-1.5"
        fancy = "1e3"
        based = "16#FF#"
        spaced = "1_000"
        """

    Scenario Outline: The real <key> reads as <value>
      When the real <key> is read with default 0
      Then the reading is <value>
      And nothing was warned

      Examples:
        | key    | value |
        | whole  | 2     |
        | plain  | 1.5   |
        | small  | 0.02  |
        | mixed  | 1.05  |
        | quoted | 0.02  |

    Scenario: A quoted signed decimal reads exactly
      When the real signed is read with default 0
      Then the reading is -1.5
      And nothing was warned

    Scenario Outline: A quoted <key> is not a plain decimal: it keeps its default
      When the real <key> is read with default 7
      Then the reading is the default
      And <key> was complained about

      Examples:
        | key    |
        | fancy  |
        | based  |
        | spaced |
  ```

  The quoted shapes are checked through the reader, as a consumer
  meets them; `Is_Plain_Decimal`'s own truth table -- the leading
  point, the trailing point, two points, the empty text, a leading
  blank, every accepted sign form -- is the unit test's
  (`Test_Shapes`, which keeps every shape) and is not restated here.
- **RED first:** `the real small is read with default 0` is
  `UNDEFINED`; green when `the reading is 0.02` passes through the
  text comparison -- and the mutation `the reading is 0.2` fails with
  `the reading was 0.02`.  `Test_Reals`' assertion on the wording
  (`fancy is not a number`) stays in the suite.

### F5 -- `sections.feature`: a config is tables and arrays

- **Where:** `tests/src/tabula_config_tests.adb:128-148`
  (`Test_Sections`), `:150-176` (`Test_Arrays`), `:209-250`
  (`Test_Table_Arrays`).
- **What is wrong:** that a missing section keeps every default
  silently, that a non-table key yields the empty section, and how
  the two walkers treat an absent key, a non-array and a wrong entry,
  are three tests with the same shape.
- **Fix:** scenarios over a doc string with `[trading]`, `names =
  ["a", 3, "b"]` and two `[[trades]]`; the walkers' items are read
  back joined (`the items were "a,b"` -- the skip is visible in what
  came out), and each unusable entry or non-array is seen to be
  complained about by name (`names was complained about`, `scalar was
  complained about`); that the complaint says `skipped` or `not an
  array` is the suite's assertion and stays there.
- **RED first:** `the section trading` is `UNDEFINED`; green on the
  section's boolean reading false through `Section`.

### F6 -- `files.feature`: a file is loaded, missing, or malformed

- **Where:** `tests/src/tabula_config_tests.adb:178-190`
  (`Test_Malformed`), `:192-203` (`Test_Missing_File`);
  `src/app/tabula-config.ads:26-48` (`Load`, `Parse` and their
  statuses).
- **What is wrong:** `Load`'s three outcomes, and that the empty
  table after a refusal still falls back everywhere, are two tests
  and a contract comment.
- **Fix:** the first named configs: `tests/features/configs/
  broken.toml` (`not = = toml`) and `tests/features/configs/
  feed.toml` (a small real one), and a second machine (`Unloaded` ->
  `Loaded` / `Refused`):

  ```gherkin
  Feature: A config file is loaded, missing, or malformed -- never a crash

    Scenario: A file loads
      Given a config labelled "feed config" from the file feed
      Then the config loaded
      When the count retries is read with default 3
      Then the reading is 12

    Scenario: A missing file is reported missing, and every knob keeps its default
      Given a config labelled "feed config" from a file that does not exist
      Then the config is missing
      When the boolean anything is read with default true
      Then the reading is the default

    Scenario: A broken file is refused as malformed, with the parser's message
      Given a config labelled "feed config" from the file broken
      Then the config is malformed
      When the count not is read with default 3
      Then the reading is the default
  ```
- **RED first:** `from the file feed` is `UNDEFINED`; green on the
  status, and the mutation `from the file nothere` fails with `no
  config named nothere in tests/features/configs`.

### F7 -- The living documentation

- **Where:** `Makefile:8` (`.PHONY`), `:23` (before `prove:`);
  `.github/workflows/ci.yml:71-76` (the example step the new steps
  follow); `.gitignore:9` (`/example/bin/`, where `node_modules` joins).
- **What is wrong:** the features are readable only with a checkout.
- **Fix:** nuntius's, renamed: `tools/features-report/package.json`
  (`multiple-cucumber-html-reporter ^3.9.0`), its `package-lock.json`
  committed so CI can `npm ci`, `report.js` (page title `tabula --
  features`, the commit and run from `GITHUB_SHA`/`GITHUB_RUN_ID`,
  `displayDuration: false` since fabula reports none); a
  `features-report` target that runs the release binary with
  `--report-json obj/features-report/json/features.json`, renders into
  `obj/features-report/html`, and fails with the runner AFTER the page
  is made; `/tools/features-report/node_modules/` ignored.  In CI, in
  the build job after the example: `actions/setup-node@v7` (node 22,
  npm cache on the lockfile), `make features-report` with `if:
  success() || failure()`, `actions/upload-artifact@v7` of the html,
  and on a push to main `actions/upload-pages-artifact@v5`; a `pages`
  job (`needs: build-and-test`, `permissions: pages: write, id-token:
  write`, environment `github-pages`) runs `actions/deploy-pages@v5`.
  Pages is enabled once, by hand: `gh api -X POST
  repos/ldm5180/tabula/pages -f build_type=workflow`.
- **RED first:** `make features-report` -- "No rule to make target";
  then the page at `obj/features-report/html/index.html` with four
  features on it, and a broken expectation still rendering the page
  before the target fails.

### F8 -- The testing layers, judged

- **Where:** `tests/src/tabula_config_tests.adb` (nine tests),
  `tests/src/tabula_decimals_tests.adb` (one).
- **What is wrong:** nothing, and this item exists to say so with the
  judgement written down.  A unit test typically tests a single
  function or a simple interaction between two, and must cover its
  function completely; a feature tests the larger interactions that
  form a conceptual feature; a test is removed only when it is an
  integration test a BDD scenario fully supplants.
- **The judgement:** every test in `Tabula_Config_Tests` exercises one
  getter (or one walker) of `Tabula.Config` over a parsed sample, and
  asserts the exact warning text the getter emits -- a single unit
  against ada_toml, with byte-level detail no feature states.
  `Test_Shapes` is a pure function's table, the whole truth table of
  `Is_Plain_Decimal`; the feature binds only what the reader does
  with a quoted shape.  **No test is removed.**  The features duplicate the
  behavior at the integration level, which is wanted.
- **RED first:** none -- this item changes no code; it lands as the
  paragraph in the plan's revision notes and the line in CLAUDE.md
  (F9).

### F9 -- The docs say so

- **Where:** `CLAUDE.md:14-20` ("Commands"), `:31` (the `tests/`
  layout line), `:44-53` ("TDD protocol"); `README.md:53-61`
  ("Develop").
- **Fix:** `make features` and `make features-report` lines in both;
  the layout line names `tests/features/`, `tabula_features.ads`,
  `Tabula_Steps` with one machine per feature, `Tabula_World`, and
  `tests/features/configs/`; the TDD protocol gains the testing-layers
  guidance in nuntius's wording (unit tests fully cover their
  function; features are never removed; a test goes only when it is
  an integration test a scenario fully supplants; byte-level detail
  stays below); the README links the published page at
  `https://ldm5180.github.io/tabula/`.

## 5. Verified in a scratch worktree (iteration 3)

Against the tree at `9dfb98de`, in a detached worktree under the
session scratchpad, GNAT 15.2.0, gprbuild 26.0.1, 2026-10-03:

1. `fabula = "*"` pinned at `746a234` beside `aunit`:
   `alr --non-interactive build --validation` succeeds in 2.6 s (5.2 s
   wall), deploying `fabula_746a234d` and, through it, `sml_3ccd0e4b`
   beside `ada_toml_485b71c8` -- no pin conflict, since tabula pins no
   `sml` of its own.  fabula compiles under the dependency profile with
   its one `-gnatwu` line as a warning.
2. The F1 sketch typed in, in the plan's own shape rather than a
   flat three-step registry: `with "fabula"`, the second main
   `tabula_features.ads`, `Tabula_Steps` with `Step_Context` and the
   regions dispatch, `Tabula_Steps.Flows` (nuntius's runner renamed),
   and `Tabula_Steps.Knobs` as a real machine -- `Unparsed`, `Parsed`,
   `Read`; `Doc_Given` and `Int_Given` guards with refusing fallback
   rows; `A_Parse` over `Fabula.Args.Doc_String` into
   `Tabula.Config.Parse`.  `gprbuild -P tests/test_tabula.gpr` builds
   both mains in 2.6 s.  A three-scenario smoke feature then shows
   each behavior the plan promises: a doc string holding `retries = 12`
   and `name = "ada"` (a quoted value, which no `{string}` could carry)
   parses and the count reads 12 -- `1 passed`; a check before anything
   was parsed fails `E_CHECK_READING is not a step this scenario can
   take now: knobs=UNPARSED`; a default of `-3` fails `the default must
   be a count`.  The mutation `the reading is 13` fails `Value 12 is
   not equal to 13`.
3. Not verified here, and the reason it is F2's and F6's RED: the
   library-level warner recording through the world (the sketch's
   warner was a null procedure), and `Load` of a named file found
   through the step's frame.  Both are the nuntius shapes
   (`Nuntius_World.Web.Cells`, `Named_Bytes (Dir, ...)`) with the
   frame's `Info.File` already shown to carry the feature's path.

## 6. The second wave, sketched

- **The example as a feature.**  `example/src/toml_fields.adb` is the
  consumer story on one sample; once the features exist it is the
  same story told twice, and could become `tests/features/
  consumer.feature` with the example kept as the README's code.
- **Layered configs.**  `Has` exists so a consumer can layer tables
  and ask which one set a key (`tabula-config.ads:55-62`); a feature
  stating that policy belongs in the consumer that has it (fructus's
  `[[accounts]]` resolution), not here.

## Revision notes

- **Iteration 1 (draft):** the seam (the real reader over a doc
  string), the layout, the step table, ten items, a second wave.
- **Iteration 2 (as a newcomer):** added "How to use this plan" with
  the six up-front decisions the nuntius work settled, the "Do not"
  list, section 1 with the two fabula limits and the library-level
  warner, section 3.1 (the machines, their states, guards and
  follow-ups) so the sml shape is designed in rather than retrofitted,
  3.2 (doc string by default, a named file when the file is the
  behavior) and 3.3 (comparing a reading by kind, exact by
  construction), full Gherkin for F3, F4 and F6, the Makefile for F1
  verbatim, F8 as a written judgement, and a RED per item.  Moved the
  decimal comparison off fabula's `{float}` after writing the first
  Do-not and seeing `0.02` become inexact on the way to the check it
  exists to make.
- **Iteration 3 (against the tree at `9dfb98de`, and the scratch
  builds of section 5):** every `file:line` re-located.  Corrected:
  the `[[actions]]` block is `35-50`, not `33-47`; `for Main` is at
  `test_tabula.gpr:16`; `.PHONY` is `Makefile:8` and `test:` `17-21`;
  CLAUDE.md's layout line is `:31` and its "TDD protocol" `44-53`;
  README's "Develop" is `53-61`; the world helpers start at `:14`;
  `Test_Has` ends at 263, `Test_Missing_File` at 203, `Test_Shapes` at
  31; in the config spec `Load`/`Parse` are `26-48`, `Has` and its
  comment `55-62`, the real `Get` and its reason `76-89`; the decimals
  spec's contract is `8-13`.  The scratch typing changed the plan in
  one place: F1's sketch is a real machine region from the first
  commit (the three-step flat registry nuntius started with would have
  been rewritten by F3 anyway), which is what section 5 item 2
  records.  Confirmed: `aunit` at `alire.toml:16`, `[[pins]]` at
  `:22`, the CI test step `64-69` and example step `71-76`, every
  Config test's start line, the spec's policy comment `5-11`.
- **After the behavior guidelines (2026-10-03):** every check step
  was re-read against "a feature binds behavior, never
  implementation".  Changed: the two warning checks that matched the
  complaint's wording (`a warning named {word} as not {word}`, `a
  warning said {word} was skipped`) became one, `{word} was complained
  about` -- the spec promises a complaint per unusable knob, prefixed
  by the label, not its words -- and the wording assertions are noted
  as staying in `Tabula_Config_Tests` (F3, F4, F5); F4's shape outline,
  which called `Is_Plain_Decimal` directly, became an outline over
  quoted knobs as the reader treats them, with the function's truth
  table left to `Test_Shapes`; the section-3 intro names the recording
  `Warner` as the contract's observation point; 3.1 and 3.3 say the
  gate's use in a guard and in the comparison is test machinery, not
  a check; F6's two titles lost the status literals' capitals; the
  up-front decision and two Do-not entries state the rule.  Already
  clean: the reading checks, `the reading is the default`, the
  status checks, `it is present/absent`, `the items were`, `nothing
  was warned` -- each reads a public result.
