# Tables in and out plan

**Status (2026-10-06):** built.  B1-B7 are on `tables-in-and-out`, one
commit per cycle; every gate passes (suite, features, format,
validation, proof).  What differs from the plan below is in the
revision notes.  B8, a list of numbers at a scale, was added after
B7 at the user's decision and is built.  B9, callbacks that carry the
caller's state, was added after B8 on `context-callbacks`.  B10, a
list of lists, was added after B9 on `nested-lists` and is built.  B11,
every value with its kind and its text, was added after B10 on
`values` and is built.  B12, two fixes to loading -- a document that
ends without a line end, and where a refusal is -- was added after B11
on `load-fixes` and is built.  B13, keys aligned on their equals signs,
was added after B12 on `aligned-keys`.

tabula reads TOML knobs today.  This plan adds what statera
(`~/git/statera/docs/statera-plan.md`) needs from the crate whose
name means "table": three small getters, a TOML writer, and a CSV
reader and writer.  The user placed the writers and CSV here on
2026-10-06, so that the next project does not write them again.

## How to use this plan

Work B1-B7 in order; B1-B3 are small and independent of the rest.
Each item is one or more TDD cycles (RED first), logged in
`docs/tdd-log.md`, one commit per cycle, `make test`, `make
features`, `make format` after each, and `make prove` when
`src/core` changed.

Each item has five parts: **Where**, **What is wrong**, **Why**,
**Fix**, **RED first**.  Lines are tabula at `42ed689`; ada_toml
lines are the pinned copy (`485b71c`), `src/toml.ads`.

Two things are true of every addition:

- **Text in, text out.**  The CSV reader hands fields over as text
  and the writers take text.  A consumer that wants exact decimals
  parses and prints them itself; tabula forms no number on the way.
- **The existing policy stands.**  No getter raises; an absent knob
  keeps the caller's fallback; a present but wrong knob warns
  through the table's `Warner` and keeps the fallback.  A consumer
  that wants a wrong knob to be an error collects the warnings.

### Do not

- Do not change what an existing getter returns or warns.  fructus,
  arb-ada and firescan-ada depend on them.
- Do not add a dependency.  The crate depends on ada_toml and, for
  tests, aunit and fabula.
- Do not form a floating-point value in new code.  `Get_Scaled` (and
  `Each_Scaled`, through the same conversion) is the one place a TOML
  float is touched, and it leaves as an integer.
- Do not raise from a new subprogram.  Outcomes and warnings.
- Do not guess a CSV dialect.  Comma, double quote, a doubled quote
  inside quotes, LF or CRLF; anything else is the caller's to say.
- Do not hold a whole CSV file in memory to read it or to write it.

## 1. Shape

| unit | layer | new or changed | holds |
|---|---|---|---|
| `Tabula.Config` | app | changed | `Each_Key`, `Get_Scaled`, `Get` for a local date and a local time |
| `Tabula.Toml_Text` | core | new | key quoting, string escaping, the text of a scalar |
| `Tabula.Emit` | app | new | a TOML document written in order: tables, arrays of tables, keys, comments |
| `Tabula.Csv_Scan` | core | new | the field scanner, one record at a time, an sml machine |
| `Tabula.Csv` | app | new | read a file by rows; write rows |

The consumer's view of the writers:

```ada
declare
   Doc : Tabula.Emit.Document;
begin
   Tabula.Emit.Comment (Doc, "written by statera");
   Tabula.Emit.Begin_Array_Table (Doc, "trades");
   Tabula.Emit.Strings (Doc, "templates", ["CS_COMMON", "IN_ROTH"]);
   Tabula.Emit.Text (Doc, "entry_time", "10:10:11");
   Tabula.Emit.Number (Doc, "quantity_target", "0.0314");  --  decimal text
   Tabula.Emit.Save (Doc, Path, Ok);                       --  atomic
end;
```

and of the CSV reader:

```ada
procedure Each_Row
  (Path    : String;
   Process : not null access procedure (Row : Tabula.Csv.Row);
   Result  : out Tabula.Csv.Outcome);
--  Tabula.Csv.Field (Row, "entry_time") by header name, or by index
```

## 2. Items

### B1 -- Walk a table's keys

- **Where:** `src/app/tabula-config.ads:94` (`Each_String`) and
  `:103` (`Each_Section`), which this sits beside; ada_toml
  `src/toml.ads:198` (`Keys`).
- **What is wrong:** a consumer cannot find a key it does not know
  to ask for, so a misspelled knob is silently an absent one.
- **Why:** the policy is "state only what you change"; nothing
  needed the list.
- **Fix:** `procedure Each_Key (T : Table; Process : not null access
  procedure (Key : String))`, in the file's order.  An absent or
  non-table value does nothing.
- **RED first:** `sections.feature`: "A table lists the keys it
  holds" -- a table with `a`, `b` and a sub-table `c` lists a, b, c.
  The step is undefined.

### B2 -- A number as a scaled integer

- **Where:** `src/app/tabula-config.ads:88`, the `Long_Float`
  getter; its body's float branch at
  `src/app/tabula-config.adb:174`.
- **What is wrong:** a consumer with no floating-point type cannot
  take a number.  fructus scales by hand after the getter
  (`fructus/src/app/bot/fructus-config-knobs.adb`).
- **Why:** the getter predates a fixed-point consumer.
- **Fix:** `function Get_Scaled (T : Table; Key : String; Scale :
  Positive; Fallback : Long_Long_Integer) return Long_Long_Integer`:
  the value times `Scale`, rounded to nearest, ties away from zero.
  A TOML integer is multiplied exactly; a quoted plain decimal is
  scaled from its digits without forming a float; a TOML float is
  scaled and rounded.  Out of range warns and falls back.
- **RED first:** `knobs.feature`: "0.2621 at a scale of one million
  is 262100", for the bare and the quoted form.

### B3 -- Dates and times

- **Where:** `src/app/tabula-config.ads`, after the getters; ada_toml
  `src/toml.ads:64` (`Any_Local_Date`), `:79` (`Any_Local_Time`).
- **What is wrong:** `start = 2020-01-01` and `start_time =
  09:30:00` are TOML values no getter returns.
- **Why:** no consumer had them.
- **Fix:** `type Date is record Year, Month, Day`, `type Time_Of_Day
  is record Hour, Minute, Second`, and a `Get` for each with a
  fallback.  A quoted string of the same shape is accepted, as
  quoted decimals are.
- **RED first:** `knobs.feature`: "A bare date reads as its year,
  month and day".

### B4 -- TOML text

- **Where:** `src/core/tabula-toml_text.ads/.adb`, new, SPARK.
- **What is wrong:** nothing in the crate can write TOML.  Each
  consumer that needs to has written strings by hand.
- **Why:** the crate was a reader.
- **Fix:** pure functions: `Key_Text` (bare when it may be, quoted
  otherwise), `String_Text` (basic string with the escapes TOML
  requires), `Is_Number_Text` (the shape of a decimal the writer
  will pass through unquoted), `Date_Text`, `Time_Text`.  Bounded
  results; proved free of run-time errors.
- **RED first:** `Tabula_Toml_Text_Tests.Test_Quote_In_String`:
  `a"b` is written `"a\"b"`.  Fails to compile.

### B5 -- A TOML document, written

- **Where:** `src/app/tabula-emit.ads/.adb`, new.
- **What is wrong:** as B4.
- **Why:** as B4.
- **Fix:** an append-only `Document`: `Comment`, `Begin_Table`,
  `Begin_Array_Table`, and per key `Text`, `Number` (decimal text,
  checked by `Is_Number_Text`), `Flag`, `Count`, `Strings`,
  `Numbers`, `Date`, `Time`.  `Save` writes to a temporary file and
  renames.  Keys come out in the order they went in.  What `Emit`
  writes, `Tabula.Config` reads back to the same values; that round
  trip is the feature.
- **RED first:** `emit.feature`: "A document written is read back
  the same" -- a table with a string, a count, a decimal and a list.

### B6 -- CSV, read

- **Where:** `src/core/tabula-csv_scan.ads/.adb` (SPARK),
  `src/app/tabula-csv.ads/.adb`, new.
- **What is wrong:** nothing in the family reads CSV; statera has
  three kinds to read (strategy definitions, dated market files, an
  earlier run's report).
- **Why:** nothing needed it.
- **Fix:** the scanner is an sml machine over one character at a
  time: `Field_Start`, `Unquoted`, `Quoted`, `Quote_In_Quoted`,
  `Record_End`, `Malformed`.  A quoted field may hold commas,
  doubled quotes and line breaks.  `Each_Row` reads the file in
  blocks, takes the first record as the header, and hands each
  later record to the caller as fields addressable by index or by
  header name.  Outcomes: `Read`, `Missing`, `Malformed` with the
  line, `Ragged` with the line (a record with a different field
  count).
- **RED first:** `Tabula_Csv_Scan_Tests.Test_Doubled_Quote`: the
  record `"a ""b"" c",d` is the two fields `a "b" c` and `d`.

### B7 -- CSV, written; and the documents

- **Where:** `src/app/tabula-csv.ads/.adb`; `README.md`,
  `CLAUDE.md`.
- **What is wrong:** as B6, for writing; and the README says the
  crate is "narrow TOML reading".
- **Why:** it was.
- **Fix:** a `Writer`: `Open (Path, Header)`, `Put (Fields)`,
  `Close`; a field is quoted when it holds a comma, a quote or a
  line break; output is buffered; `Close` renames a temporary file
  into place.  The README and `CLAUDE.md` describe the crate as
  tables in and out, with the two rules of this plan.
- **RED first:** `csv.feature`: "A file written is read back the
  same", with a field holding a comma, a quote and a line break.

### B8 -- A list of numbers as scaled integers

- **Where:** `src/app/tabula-config.ads`, beside `Each_String`; the
  body's `Scaled_Knob_Of`, which `Get_Scaled` reads one number
  through.
- **What is wrong:** statera's config holds lists of decimals
  (`entry_targets = [15, 25, 35]`, `[0.0210, 0.2621]`), and no getter
  walks a list of numbers.  statera has no floating-point type, so it
  makes its users quote each number as text and parses it itself.
- **Why:** B2 gave one number at a scale; nothing asked for a list
  until statera's lists did.
- **Fix:** `procedure Each_Scaled (T : Table; Key : String; Scale :
  Positive; Process : not null access procedure (Item :
  Long_Long_Integer))`: each entry taken exactly as `Get_Scaled`
  takes one number (the same `Scaled_Knob_Of`, so the same proven
  `Tabula.Decimals.Scaled` and the one float conversion).  The
  walkers' policy: an absent key does nothing, a non-array warns and
  does nothing, and an entry that is not a number, or does not fit at
  the scale, warns and is skipped while the walk goes on.
- **RED first:** `knobs.feature`: "A list of decimals reads as scaled
  integers" -- `[15, "0.0210", 0.2621]` at a scale of one million is
  15000000, 21000 and 262100.  The step is undefined, and
  `Tabula_Config_Tests` fails to compile on `Each_Scaled`.

### B9 -- Callbacks that carry the caller's state

- **Where:** `src/app/tabula-config.ads`, the `Warner` the table
  carries and the walkers `Each_String`, `Each_Scaled`,
  `Each_Section` and `Each_Key`; `src/app/tabula-csv.ads`,
  `Each_Row`.
- **What is wrong:** every callback is a bare access-to-procedure
  with no context.  A caller that collects or accumulates anything
  must keep it in package-level variables, and `Warner` is a
  library-level access type, so its target and what it records are
  library-level too.  statera does exactly that in three units (its
  config warnings, its config reader, its dated-file loader), which
  also makes them unsafe on a task pool.  A nested callback is no way
  out: the house shape rules forbid nested subprogram bodies.
- **Why:** the APIs were written for loggers and one-off walks, where
  nothing is carried from one call to the next.
- **Fix:** beside every existing callback API, an overload that takes
  the caller's object, and nothing existing changes.  Interfaces, one
  per callback, each with its own primitive's name so one caller type
  may be several of them: `Listener.Warn`,
  `String_Visitor.Visit_String`, `Scaled_Visitor.Visit_Scaled`,
  `Section_Visitor.Visit_Section`, `Key_Visitor.Visit_Key`, and
  `Tabula.Csv.Row_Visitor.Visit_Row`.  `Load` and `Parse` gain an
  overload whose warnings go to a `not null access Listener'Class`
  the caller owns and the table (and every table taken from it)
  carries.  Each walker gains an overload taking `in out
  <Kind>_Visitor'Class`.  The existing access-to-procedure walkers
  become thin adapters over the new ones (a private visitor whose
  discriminant is the procedure), so each walk has one
  implementation.
- **RED first:** `Tabula_Config_Tests` collects warnings and walked
  items in local objects, with no package variable, and fails to
  compile on `Listener`; a new `context.feature` -- "A reader's own
  listener hears what its table complains about" and a scenario per
  walker and for CSV rows, visited into the reader's own object --
  has undefined steps.

### B10 -- A list of lists

- **Where:** `src/app/tabula-config.ads`, beside the walkers and their
  visitors; the body's `Each_Entry`, which every array walk goes
  through.
- **What is wrong:** PRO's grid configs hold lists of lists -- the
  outer list is the grid's options, each inner list one option's value
  (`entry_targets = [[15, 25, 35]]`, `custom_filters = [['skip EOM',
  'skip FOMC']]`, `day_of_week = [[2, 3, 4, 5]]`) -- and every walker
  skips an entry that is an array, with a warning.  statera's PRO
  converter therefore reads those knobs through ada_toml directly, a
  second TOML reader beside tabula.
- **Why:** nothing asked for a nested list until statera's converter
  had to read PRO's grids.
- **Fix:** a walk of the inner arrays, in both styles:
  `type List_Visitor is limited interface; procedure Visit_List (V :
  in out List_Visitor; Item : Table) is abstract;` and `Each_List (T :
  Table; Key : String; Visitor : in out List_Visitor'Class)`, with the
  access-to-procedure form as the usual adapter.  `Item` is a `Table`
  that *is* the inner array; a keyless `Each_String (List : Table;
  ...)` and `Each_Scaled (List : Table; Scale : Positive; ...)`, in
  both styles, walk its entries as the keyed walks walk a knob's, and
  their warnings name the option (`entry_targets[2]`, counting from
  one).  A table that is not a list walks nothing, silently, as
  `Each_Key` walks nothing of a table that is not one.  The policy:
  an absent key does nothing; a non-array warns and does nothing; an
  entry of a grid that is not an array warns and is skipped.  A flat
  list -- an array none of whose entries is an array, the empty one
  among them -- is one option, the whole list, silently.  PRO reads
  that shape two ways: its single-run loader takes `entry_targets =
  [25, 35]` as the value (its own test fixtures write it so), while
  its grid search takes each entry as an option, which for a
  list-valued knob is a scalar its model rejects, so no run comes of
  it.  One option is the reading under which the file means anything.
  Nothing existing changes.
- **RED first:** `context.feature`: "A grid of lists reads one list
  per option" -- `entry_targets = [[15, 25, 35], [20, 30]]` visited as
  numbers at a scale of 1 gathers `[15,25,35],[20,30]`.  The step is
  undefined, and `Tabula_Config_Tests` fails to compile on
  `List_Visitor`.

### B11 -- Every value, with its kind and its text

- **Where:** a child of `Tabula.Config` (`src/app/tabula-config-values.ads`),
  beside `Each_Key`, whose file order it shares; ada_toml's
  `Location` (`src/toml.ads:133`) and `Any_Float` (`:47`).
- **What is wrong:** statera's PRO converter keeps every key of a PRO
  file -- its report lists each one, known to statera or not -- with
  its kind, and reads them through ada_toml directly, a second TOML
  reader beside tabula.  tabula cannot (1) read a date or a time inside
  a list (`start_date = [2020-01-01]`), (2) say what kind a value is,
  nor read a local or offset date-time at all, or (3) hand a float over
  exactly without a floating-point type: `Get_Scaled` stops at a scale
  of 10^9 and rounds.
- **Why:** every getter asks for one knob by its key and its type;
  nothing needed a whole document until the converter did.
- **Fix:** `type Value_Kind is (A_Table, An_Array, A_Text, An_Integer,
  A_Decimal, A_Flag, A_Date, A_Time, A_Local_Datetime,
  An_Offset_Datetime, Not_A_Number, An_Infinity)`; `type Value_Visitor
  is limited interface; procedure Visit_Value (V; Key, Kind, Text, Item
  : Table)`; `Each_Value (T, Visitor)` and its procedure form.  A
  table's values in file order (Each_Key's), a list's in its order with
  no key; a table or a list among them handed over as a `Table` the
  walk takes in turn.  Text: a string as it reads, an integer's decimal
  digits, a flag's true or false, a date, a time (milliseconds when it
  has a fraction) or a date-time as TOML writes it, a special float's
  sign and name -- and a decimal as the literal the document wrote, a
  plain decimal digit for digit.  The parser keeps a float as a double,
  so the literal is read from the document's text, at the line and
  column the parser recorded: the table carries the text (Load reads
  the file whole and parses that text), a new core unit
  `Tabula.Toml_Source` maps the place back to the literal, and
  `Tabula.Toml_Text.Decimal_Of` turns the literal into the plain
  decimal, both proved, with no floating point.  Nothing an existing
  getter or walk returns or warns changes.
- **RED first:** `Tabula_Toml_Text_Tests` fails to compile on
  `Decimal_Of`; a new `Tabula_Config_Values_Tests` on the missing
  child; `values.feature` has undefined steps.

### B12 -- A document that ends without a line end; where a refusal is

- **Where:** `src/app/tabula-config.adb` at `a1c4d25`: `Parsed_Of`
  (`:75`), which every `Parse` and every readable `Load` goes
  through, and `Wrap` (`:80`), which turns the parser's refusal into
  `Load_Outcome.Error` and, through `Split`, the older form's `Error`.
  ada_toml: `Reemit_Codepoint`'s precondition
  (`src/toml-generic_parse.adb:168`), and `Format_Error`
  (`src/toml.ads:433`).
- **What is wrong:** (1) A document whose last value is a date, a
  time without a fraction, a local date-time, or a date-time with a
  numeric offset, with no line end after it (`start = 2020-01-01`,
  end of text), makes the parser's lexer read past the end and fail
  `Reemit_Codepoint`'s precondition; `Parse` and `Load` let the
  `Assertion_Error` escape, where the crate's contract is that nothing
  raises.  Since B11 `Load` parses the file's text, so a file reaches
  it as a doc string does.  (2) A refusal's message is the parser's
  message alone (`invalid syntax`), without the line and column the
  parser recorded, so a reader cannot be told where a file is broken.
  statera's converter, which read through ada_toml before it read
  through tabula, printed `3:1: invalid syntax` (`TOML.Format_Error`),
  and its users lost the place when it moved to tabula.
- **Why:** (1) went unseen because every test document of a date or
  a time had a line after it; B11's `values.feature` found it.  (2)
  `Wrap` has handed over `Read_Result.Message` since the getters were
  first written; the place sits beside it, in `Read_Result.Location`.
- **Fix:** (1) tabula hands the parser the text with a line feed
  after it when the text ends with neither a line feed nor a carriage
  return -- a TOML document may end with a line end or not, so no
  document's meaning changes.  A lone carriage return at the end is
  left alone: it is refused already (`invalid stray carriage return`),
  and a line feed after it would make it a line end and accept the
  document.  The decision is a proved core function,
  `Tabula.Toml_Source.Line_Ended`; the table keeps the text it parsed,
  whose places are the document's own, since the line feed comes after
  every one of them.  (2) The message is `TOML.Format_Error`'s:
  `LINE:COLUMN: message`, and the message alone when the parser
  recorded no place (a file it could not open, whose message is
  unchanged).  Both forms of `Load` and `Parse`.  Nothing else
  changes, with one consequence of (1) to know: a broken document
  that ends without a line end is refused where the parser now meets
  the end, the line after its last (`[run` is `2:1: invalid syntax`).
- **RED first:** a new `Tabula_Config_Load_Tests`: a document ending
  in a date, a time and a date-time, each with and without a line
  end, parses and reads (the build first fails on `Line_Ended` in
  `Tabula_Toml_Source_Tests`; the parse raises); a malformed document
  is refused with `3:1: invalid syntax` by `Parse` and `Load`, in both
  forms.  `files.feature`: a file and a doc string that end with a date
  and a time load.

### B13 -- Keys aligned on their equals signs

- **Where:** `src/app/tabula-emit.ads/.adb` at `6af8926`: `Put_Pair`
  (`tabula-emit.adb:60`), which writes every `key = value` line as it
  comes, and `Begin_Header` (`:117`), which ends a table entry; the
  private `Document` record (`tabula-emit.ads:92`).
  `Tabula.Toml_Text` (core) for the width of a key's text.
- **What is wrong:** a document `Emit` writes for a person to read and
  edit -- a bot lane's trades file, one `[[trades]]` entry per trade --
  has its `=` signs wherever each key ends, so a column of values does
  not read as a column:

  ```toml
  [[trades]]
  templates       = ["CS_COMMON", "IN_ROTH", "CS_AM", "R_0dte_CS_CCS"]
  entry_time      = "09:56:28"
  entry_target    = 35
  stoploss_target = 20
  quantity_target = 0.0308
  ```

  is what such a file looks like when a person writes it, and what
  `Emit` cannot write.
- **Why:** `Emit` writes each line as it is asked for; the widest key
  of an entry is not known until the entry ends.
- **Fix:** an opt-in layout, chosen when the document is made:
  `type Key_Layout is (Plain, Aligned)` and `type Document (Layout :
  Key_Layout := Plain) is private`.  `Doc : Document (Aligned)` pads
  each key, after its text (quoted when it must be), to the width of
  the widest key of the same table entry: the root's keys among the
  root's, each `[table]` and each `[[array]]` entry on its own.  A
  default-initialized `Document` is `Plain` and writes byte for byte
  what it wrote before, so no caller changes.  The document holds the
  lines of the entry at hand until the entry ends (a header, or
  `Text_Of` and `Save`, which read the held lines with the rest);
  comments keep their place among the keys and are written as they
  were, and the blank line before a header is unchanged.  Every value
  `Emit` writes is one line (an array on one line, a string's line
  ends escaped), so no value spans lines.  A key's width is its count
  of codepoints, so a quoted key that holds UTF-8 lines up with the
  rest: `Tabula.Toml_Text.Width`, proved.  What an aligned document
  writes reads back through `Tabula.Config` to the values written, as
  a plain one does.

  Why a discriminant, over the other places the choice could go: a
  flag on `Begin_Table` and `Begin_Array_Table` would leave the
  root's keys without one (no call begins the root) and would ride on
  every header; a setter (`Align_Keys (Doc)`) could change the layout
  half way through an entry; a constructor (`Doc : Document :=
  Aligned_Document`) would do, but hides the choice in a field.  The
  discriminant fixes the layout when the document is made, says it
  where the document is declared, and its default keeps every
  existing declaration what it was.
- **RED first:** `Tabula_Toml_Text_Tests` fails to compile on `Width`;
  `Tabula_Emit_Tests` on `Document (Aligned)`: the text of a document
  with root keys, a comment among a table's keys, and two `[[trades]]`
  entries whose widest keys differ, and that it saves and reads back
  to the values written; `emit.feature` has an undefined step for a
  document whose keys are aligned.

## 3. Features

| file | new scenarios |
|---|---|
| `sections.feature` | a table lists its keys |
| `knobs.feature` | scaled numbers, bare and quoted; a list of them (B8); dates; times; each out-of-range or wrong-typed value warns and falls back |
| `emit.feature` | a document reads back the same; a key that needs quoting gets it; text that is not a number is refused as a number; a document whose keys are aligned lines up each entry's `=` signs and reads back the same (B13) |
| `csv.feature` | fields by header name; quoted fields; a ragged record and an unclosed quote are refused with their line; a file written reads back the same |
| `context.feature` | a reader's own listener hears its table's complaints, a section's among them; each walker, and a CSV file's rows, visited into the reader's own object (B9); a grid of lists, one list per option, a flat list as one option, and a grid's entry that is not a list (B10) |
| `values.feature` | every value with its kind and its text, in file order; a decimal as written; dates inside a list; tables and lists walked in turn, to a visitor and to a procedure (B11) |
| `files.feature` | a file and a doc string that end with a date or a time and no line end load; a refusal names its line and column (B12) |

## Revision notes

- **Iteration 1 (draft):** the three getters, as a list in
  statera's plan.
- **Iteration 2 (as a newcomer, after the user placed the writers
  and CSV here):** became its own plan in this repository, with the
  two standing rules, the Do-not list, the consumer's view of the
  writer and the reader, and a RED assertion per item.  Split TOML
  text (pure, proved) from the document (file IO), and the CSV
  scanner (pure, proved) from the file reader, the way the crate
  already splits `Decimals` from `Config`.
- **Iteration 3 (against tabula at `42ed689` and ada_toml at
  `485b71c`):** re-located: `Each_String` at
  `tabula-config.ads:94`, `Each_Section` at `:103`, the float
  getter at `:88` and its float branch at `tabula-config.adb:174`;
  ada_toml's `Keys` at `toml.ads:198`, `Any_Local_Date` at `:64`,
  `Any_Local_Time` at `:79`.  Confirmed the crate has four feature
  files and a `Flows` runner already, so B1-B3 add scenarios to
  existing files and only `emit` and `csv` are new.  Corrected: the
  draft had `Get_Scaled` always going through the float; the quoted
  decimal form can be scaled from its digits, which keeps exact
  decimals exact.
- **Implementation (as built, against the plan above):**
  - *B1.*  ada_toml's `Keys` and `Iterate_On_Table` come back sorted,
    not in file order; `Each_Key` orders the entries by the source
    location the parser recorded for each value (the key breaks a
    tie), which is the file's order.
  - *B2.*  The digit scaling is pure arithmetic, so it went into the
    proven core beside the shape check, as `Tabula.Decimals.Scaled`
    (an integer overload too), rather than into `Config`.  The range
    is symmetric, `-Long_Long_Integer'Last .. Long_Long_Integer'Last`,
    so `Long_Long_Integer'First` is out of range.  The fraction is
    taken from its last digit with a carry below the scale; the first
    digit's step alone decides the rounding, so every digit counts.
  - *B3.*  `Date` and `Time_Of_Day` are declared in the root package
    `Tabula`, not in `Config`, so the writer (B5) and the text
    functions (B4) share them; `Tabula.Toml_Text` was created here for
    the quoted forms' readers and B4 added the writers to it.  ada_toml
    accepts a day its month lacks (2021-02-29), so the getter checks
    the calendar; a local time with a fraction of a second warns and
    falls back rather than lose the fraction; a second may be 60, as
    TOML allows.
  - *B4.*  `Is_Number_Text` is stricter than "the shape of a decimal",
    so that what is written reads back as written: no leading zero
    (TOML forbids one), an integer within 64 bits (a larger one does
    not parse), and a decimal with a point of at most 15 significant
    digits (what a double holds exactly).
  - *B5.*  Two app units the shape table did not list:
    `Tabula.Staged_Files` (write beside the path, rename into place,
    abandon on any failure or when let go of; the CSV writer uses it
    too) and `Tabula.Text_Lists` (the list of texts the writers take,
    so a caller writes `["A", "B"]`).  The refusals are a number text
    `Is_Number_Text` rejects, a key twice in one table, a header name
    already at the root (an array of tables may continue), a control
    in a comment, a day the calendar lacks, and text too long to
    escape; `Refusal` names the first, beginning with its key.  A
    table name is one key, quoted when it must be, never a dotted
    path.
  - *B6.*  The scanner makes `sml` a dependency of the library: it is
    declared in `alire.toml` with no pin of its own and resolves to
    the commit fabula pins (`3ccd0e4b`); nothing was re-pinned.  The
    record is bounded (64 KiB of text, 1024 fields), and a record past
    a bound is refused (`Too_Long`, `Too_Many_Fields`), never cut.
    Two states beyond the plan's six: `Line_Feed_Due` (after a CR; a
    CR no LF follows is refused) and `Finished`.  The CR and LF events
    take the `ASCII` names.  A file that exists but cannot be read is
    `Malformed` at line 0.  A row also offers `Column`, `Has_Column`
    and `Line`; a repeated header name reads as its first column.
  - *B7.*  The writer refuses a header of no columns and any record the
    reader could not read back (past the scanner's bounds), and offers
    `Failed`.  `Field_Text`, the quoting, sits in `Tabula.Csv_Scan`
    beside the scanner, so the dialect's special characters are named
    once, and is proved.
  - *Found on the way.*  `make format` reads `git ls-files`, so a new
    file must be staged before it is checked.  gnatformat's lexer takes
    a container aggregate opening on a short hex-digit string
    (`["a"]`) for a bad brackets encoding.  fabula ends a doc string at
    a quote fence anywhere on a line, so a feature's CSV avoids `"""`.
- **B8 (added after the build, at the user's decision):** the plan
  gained an item, as built.  `Each_Scaled` takes the sketch's shape
  with no fallback and no count: the other walkers have neither, an
  absent list is already "nothing to walk", and the warnings are how a
  caller learns an entry was skipped.  The visitor's parameter is
  `Item`, as `Each_String`'s and `Each_Section`'s are.  An entry too
  large warns `<key> entry out of range at a scale of N; skipped`, a
  non-number `non-number <key> entry skipped`, matching the
  `non-string` and `non-table` warnings.  The refactor put the three
  walkers over one private `Each_Entry` (absent, non-array, the loop)
  and named `Get_Scaled`'s out-of-range wording once; nothing either
  existing walker or `Get_Scaled` returns or warns changed.
- **B9 (added after B8, at the user's decision):** the user's rule
  is dependency injection everywhere -- no package-level variable,
  set-once cell or singleton -- and the callback APIs made every
  caller break it.  Interfaces were chosen over generics over a
  context type: a caller with several callbacks (statera's reader
  walks keys, sections, strings and numbers, and hears warnings) can
  be one object implementing several interfaces, with no
  instantiation per pair of context and callback; distinct primitive
  names (`Visit_String`, `Visit_Key`, ...) are what let one type be
  both a string and a key visitor, whose items are both `String`.
  As built:
  - The listener's `Load` and `Parse` return a `Load_Outcome` (status
    and message) rather than two out parameters: five parameters and
    two results, where the warner's forms have six and three.  The
    table keeps a private sink (warner or listener access), and stores
    the listener with `'Unchecked_Access`, so the caller's object must
    outlive the table and every table taken from it, as the spec says.
  - The procedure forms are adapters: a private visitor whose
    discriminant is the procedure (an anonymous access-to-subprogram
    discriminant), so no walk is written twice and the library holds
    no nested subprogram body.  The array walks share `Each_Entry`
    over a private entry visitor per kind, declared in a nested
    package spec because an interface's primitives must be declared
    in one.
  - The test fixture gained a `Recorder` (a listener) and a
    `Gatherer` (all four config visitors at once); the features hold
    a scenario's recorder on the heap, since fabula copies the world
    per step.  The warner's own recorder, the region states and the
    CSV procedure form's gatherer stay package state in the tests:
    the procedure forms they exercise carry no object.
- **B10 (added after B9, at the user's decision):** statera's PRO
  converter reads PRO's grids, lists of lists, through ada_toml
  directly; the user chose to extend tabula so statera has one TOML
  reader.  The item was written against tabula at `f8a6432` and PRO's
  `src/config/grid_search.py` and `iterables.py`, whose
  `separate_iterable_and_non_iterable_configs` takes a non-empty list
  at an iterable path as the options and leaves anything else as the
  one value -- which is where the flat-list reading above comes from.
  The inner list is handed over as a `Table` rather than as a new
  type, so the walks a caller already knows read it, and the item's
  name (its key and place) rides in the table, private, for the
  warnings.
  As built, in seven cycles: the shape above held.  The walk of a
  knob's array became `Each_Item` over an array value, shared by the
  keyed walks (`Each_Entry`) and the keyless ones (`Each_List_Entry`),
  so a list's entries are taken by the very entry visitors a knob's
  are.  A grid's entry that is not a list warns `non-array <key> entry
  skipped`, as the `non-string` and `non-table` warnings read; the
  count of places runs over it, so a later list keeps the place a
  reader would count to (`mixed[3]`).  The keyless walk of a table
  that is not a list walks nothing, silently.  The test fixture gained
  a `List_Gatherer` (strings, or numbers at a scale, bracketed per
  list), and `context.feature` three scenarios.  Nothing an existing
  getter or walker returns or warns changed; the private `Table`
  gained a `Name`.
- **B11 (added after B10, at the user's decision):** statera's PRO
  converter keeps every key of a PRO file with its kind and reads them
  through ada_toml directly; the user chose one TOML reader, so tabula
  walks every value.  As built, in eight cycles:
  - The walk lives in a child, `Tabula.Config.Values`, so
    `Tabula.Config`'s body stays under the 1,000 lines a body may hold;
    the helpers both share -- `Within`, `Complain`, `Written_Entries`,
    and `To_Date` / `To_Time`, which turn the parser's calendar values
    into Tabula's for the getters and the walk alike -- are declared in
    Config's private part, which the child's body sees.
  - The kinds take the article prefix (`A_Table`, `An_Integer`): bare
    `Array` is reserved, and `Table`, `Integer` and `Date` would hide a
    type of the same name.
  - Exact decimals.  ada_toml records each value's line and column, and
    no text.  Its places are particular: the codepoint before the
    value, or the value's own first codepoint when the parser read it
    ahead (after a `[`); a tab to a stop of 8; a column per codepoint,
    not byte; CR LF as one line end, which is column one of the line it
    opens; the document's first codepoint line one, column one, even a
    line end.  `Tabula.Toml_Source.Number_At` counts exactly so and
    takes the run of number characters at the codepoint or the byte
    after it; `Decimal_Of` checks the literal's grammar (digit groups
    with single underscores, no leading zero, a fraction, an exponent
    or both) and places the point, keeping the digits as written
    (`1.50` stays `1.50`, `1e2` is `100`).  The literal and the
    exponent are bounded (`Max_Literal_Length`, `Max_Exponent`) so the
    length of the result is proved.  A table carries its document's
    text privately; `Load` reads the file whole and parses that text,
    and falls back to the parser's own file read when the text cannot
    be read, so a refusal's message is the one it always was.  The
    unit tests check every decimal's text against what the float getter
    reads (`Long_Float'Value` in the test, never in the crate).
  - A float whose literal is not found is complained of and skipped,
    not handed over inexactly; no document ada_toml reads reaches it.
  - The parser keeps a time's fraction to the millisecond and cuts a
    finer one, as TOML allows; a time's text carries three digits when
    it has a fraction (`09:30:00.25` is `09:30:00.250`).  An unknown
    offset (`-00:00`) keeps that text; offset zero is `Z`.
  - *Found on the way.*  ada_toml refuses a float whose fraction has
    more than eighteen digits ("too large float": it reads the fraction
    as a 64-bit integer).  And a document that ends with a date or a
    time and no line end makes its lexer fail a precondition, which
    `Parse` and `Load` let escape as an exception; statera appends a
    line end before parsing for this reason.  Left for the user: a fix
    in tabula (append a line end) or upstream.
- **B12 (added after B11, at the user's decision):** two faults in
  loading that statera found, fixed in tabula rather than upstream.  As
  built, in four cycles (two fixes, a scenario for each):
  - The line end.  `Tabula.Toml_Source.Line_Ended` (core, proved) gives
    the text from one with a line feed after it when it ends with
    neither a line feed nor a carriage return; `Parsed_Of` hands that
    to the parser, so `Parse` and every readable `Load` take it, and the
    table keeps it as its source -- the line feed comes after every
    place the parser records, so the decimal walk is unchanged.  The
    shapes that failed: a date, a time without a fraction, a local
    date-time, and a date-time with a numeric offset; a time with a
    fraction, a `Z` date-time and a date inside a list never did.
  - The place.  `Wrap` hands over `TOML.Format_Error`, `LINE:COLUMN:
    message`.  The text a consumer saw before B11 had no place either:
    tabula has handed over `Read_Result.Message` since the getters were
    first written, from `TOML.File_IO.Load_File` until B11 and from
    `Load_String` since, and both give `invalid syntax` for a broken
    third line.  `3:1: invalid syntax` is what statera's converter
    printed through `Format_Error` while it read ada_toml directly; that
    is the text matched.  A file the parser cannot open keeps its
    message, which has no place.
  - The consequence named in the Fix: a broken document that ends
    without a line end is refused as the same document with one is --
    `[run` at `2:1`, and an unterminated string at the end as `2:1:
    invalid string` where the bare text gave `1:7: unterminated string`.
    Before this item neither carried a place.
  - Tests: a new `Tabula_Config_Load_Tests` (every load outcome, read
    four ways -- Parse and Load, warner and listener), to which the
    two load-outcome tests moved from `Tabula_Config_Tests`; and
    `Line_Ended` in `Tabula_Toml_Source_Tests`.  `files.feature` gained
    a file (`configs/dated.toml`, committed without a final line end)
    and a doc string that end with a date and a time, and a refusal at
    its line and column, through a new configs-region step.
  - *Found on the way, not changed:* `Load` of a directory raises
    `Device_Error` ("Is a directory"): `Stream_IO` opens a directory and
    fails on the read, and so does the parser's own file read the
    fallback goes to.  It raised before B11 too.
