# tabula

Tables in and out for Ada 2022: TOML read and written, CSV read and
written.

`tabula` (Latin: *tablet* — TOML is tables, and so is a CSV file)
started as the one policy a config file needs: **an absent knob
silently keeps the caller's default; a present-but-wrong knob warns
through the caller's handler and keeps the default.** A config file can
degrade a run — it can never crash it.  The writers and the CSV reader
keep the same spirit, and two rules hold for every part of it:

- **Text in, text out.**  The CSV reader hands fields over as text, and
  the writers take text.  A consumer that wants exact decimals parses
  and prints them itself; tabula forms no number on the way.
- **Outcomes, never exceptions.**  No getter raises; an absent knob
  keeps the caller's fallback; a present but wrong knob warns through
  the table's `Warner` and keeps the fallback.  A writer refuses what it
  cannot write and lands nothing; a reader reports a refused file with
  the line it refused.

## What's in it

- **`Tabula.Config`** — typed knob getters over
  [ada_toml](https://github.com/pmderodat/ada-toml): `Load` (file, with
  distinct `Missing` / `Malformed` outcomes) or `Parse` (in-memory),
  `Section`, overloaded `Get` for Boolean / Natural (with a `Min` guard) /
  String (with `Require_Non_Empty`) / Long_Float, `Get_Scaled` for a
  number as a whole count of a scale's units (no floating point needed:
  0.2621 at a scale of a million is 262100), `Get` for a `Tabula.Date`
  or a `Tabula.Time_Of_Day` (bare `2020-01-01` / `09:30:00` or quoted;
  a day the calendar lacks is refused), `Each_String` for string
  arrays, `Each_Section` for arrays of tables, and `Each_Key` for the
  keys a table holds, in the file's order.  Every table carries a label
  and a `Warner` callback, so complaints read like `feed config: retries
  is not a number in 1 .. Natural'Last; using default`.
- **`Tabula.Decimals`** — the SPARK-proven shape check behind quoted exact
  decimals. ada_toml 0.5.0 reassembles bare floats from an INTEGER
  fraction, dropping leading zeros (`0.02` loads as `0.2`!), so
  decimal-shaped knobs are quotable: `bump = "0.02"` converts exactly, and
  the proven `Is_Plain_Decimal` keeps `'Value` exotica (exponents, based
  literals) out.  The proven `Scaled` takes a decimal's digits to a
  scaled integer, rounded half away from zero, with no float formed.
- **`Tabula.Emit`** — a TOML document written in order: comments,
  `[tables]`, `[[arrays of tables]]`, and keys (`Text`, `Number` from
  decimal text, `Flag`, `Count`, `Strings`, `Numbers`, `Date`, `Time`).
  What cannot be written is refused, never raised: the first refusal
  names its key, and a document that refused anything is not saved.
  `Save` writes beside the path and renames, so the file in place is
  the old one or the whole new one.  What it writes reads back through
  `Tabula.Config` to the values written.
- **`Tabula.Csv`** — a CSV file read by its rows: `Each_Row` takes the
  first record as the header and hands each later one over, its fields
  by the header's names (`Field (Row, "entry_time")`) or by position.
  One dialect, never guessed: comma, double quote, a doubled quote
  inside quotes, LF or CRLF.  The file is read in blocks, one record
  held at a time; a refused text (`Malformed`) and a record whose
  field count differs from the header's (`Ragged`) come back with the
  line the record began on.  A `Writer` writes one: `Open (W, Path,
  Header)`, `Put (W, Fields)`, `Close (W, Ok)`, a field quoted when it
  holds a comma, a quote or a line break, buffered beside the path and
  landed whole by `Close`; a row unlike the header is refused.
- **`Tabula.Csv_Scan`** — the proven scanner under it, an sml machine
  over one character at a time, its record bounded and a record past
  the bounds refused, never cut.
- **`Tabula.Toml_Text`** — the proven text of TOML scalars, both ways:
  keys bare or quoted, basic strings with their escapes, the decimal
  text a writer may pass unquoted, dates and times.

## Use it

Add the dependency (via a git pin until it is in the community index):

```toml
[[depends-on]]
tabula = "*"
```

Read a config:

```ada
with Tabula.Config;

Root    : Tabula.Config.Table;
Status  : Tabula.Config.Load_Status;
Error   : Ada.Strings.Unbounded.Unbounded_String;
...
Tabula.Config.Load
  ("app.toml", "app config", My_Log.Warn'Access, Root, Status, Error);

Trading : constant Tabula.Config.Table :=
  Tabula.Config.Section (Root, "trading");
Dry_Run : constant Boolean :=
  Tabula.Config.Get (Trading, "dry_run", Fallback => True);
```

Write one:

```ada
with Tabula.Emit;

Doc : Tabula.Emit.Document;
Ok  : Boolean;
...
Tabula.Emit.Comment (Doc, "written by statera");
Tabula.Emit.Begin_Array_Table (Doc, "trades");
Tabula.Emit.Strings (Doc, "templates", ["CS_COMMON", "IN_ROTH"]);
Tabula.Emit.Text (Doc, "entry_time", "10:10:11");
Tabula.Emit.Number (Doc, "quantity_target", "0.0314");  --  decimal text
Tabula.Emit.Save (Doc, Path, Ok);  --  whole or not at all
```

Read a CSV file by its rows, and write one:

```ada
with Tabula.Csv;

procedure Take (Row : Tabula.Csv.Row) is
begin
   Put_Line (Tabula.Csv.Field (Row, "entry_time"));
end Take;
...
Result : Tabula.Csv.Outcome;
Tabula.Csv.Each_Row ("trades.csv", Take'Access, Result);

W : Tabula.Csv.Writer;
Tabula.Csv.Open (W, "report.csv", ["name", "pnl"]);
Tabula.Csv.Put (W, ["alpha", "12.50"]);
Tabula.Csv.Close (W, Ok);
```

## Develop

```sh
make build    # build the library
make test     # AUnit suite, both -O modes, fully offline
make features # the Gherkin features, both -O modes, fully offline
make features-report  # the features as an HTML page (needs node)
make prove    # SPARK proof, --checks-as-errors=on
make format   # gnatformat --check
make run      # run the toml_fields example (pure; CI runs it too)
make help     # all targets
```

What a config does to a run, and what is written and read back, stated
as Gherkin features and run on every push, is published at
https://ldm5180.github.io/tabula/.

Conventions (SPARK, strict TDD, commit style) live in [CLAUDE.md](CLAUDE.md).
