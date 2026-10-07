# Tables in and out plan

**Status (2026-10-06):** built.  B1-B7 are on `tables-in-and-out`, one
commit per cycle; every gate passes (suite, features, format,
validation, proof).  What differs from the plan below is in the
revision notes.  B8, a list of numbers at a scale, was added after
B7 at the user's decision and is built.

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

## 3. Features

| file | new scenarios |
|---|---|
| `sections.feature` | a table lists its keys |
| `knobs.feature` | scaled numbers, bare and quoted; a list of them (B8); dates; times; each out-of-range or wrong-typed value warns and falls back |
| `emit.feature` | a document reads back the same; a key that needs quoting gets it; text that is not a number is refused as a number |
| `csv.feature` | fields by header name; quoted fields; a ragged record and an unclosed quote are refused with their line; a file written reads back the same |

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
