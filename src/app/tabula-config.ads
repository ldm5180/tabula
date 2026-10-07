with Ada.Strings.Unbounded;

private with TOML;

--  Typed knob reading over one parsed TOML document.  The policy every
--  getter shares: an ABSENT key silently keeps the caller's fallback (a
--  config file states only what it changes), while a PRESENT but
--  wrong-typed, out-of-range, or otherwise unusable value keeps the
--  fallback AND warns through the table's handler -- a config file can
--  degrade a run, never crash it.  All ada_toml specifics stay behind
--  this one unit.

package Tabula.Config is

   --  Receives one human-readable complaint per unusable knob; null
   --  means silent fallbacks.  Callers typically pass their logger.
   type Warner is access procedure (Message : String);

   --  One TOML table plus the label and the warner or listener its
   --  getters report through.  Default-initialized: empty, so every
   --  getter falls back silently.
   type Table is private;

   type Load_Status is (Loaded, Missing, Malformed);

   --  Read Path.  Missing means no such file (Root is empty; commonly
   --  fine -- the caller keeps its defaults and says so); Malformed
   --  means the parser refused (Error carries its message; Root is
   --  empty).  Label prefixes every warning this table and its sections
   --  later emit (e.g. "feed config").
   procedure Load
     (Path   : String;
      Label  : String;
      Warn   : Warner;
      Root   : out Table;
      Status : out Load_Status;
      Error  : out Ada.Strings.Unbounded.Unbounded_String);

   --  The same over an in-memory document (tests, embedded defaults);
   --  Status is never Missing.
   procedure Parse
     (Content : String;
      Label   : String;
      Warn    : Warner;
      Root    : out Table;
      Status  : out Load_Status;
      Error   : out Ada.Strings.Unbounded.Unbounded_String);

   --  What hears a table's complaints and keeps them in the caller's own
   --  object: a Warner that carries state.  Warn takes one complaint per
   --  unusable knob, prefixed with the table's label as a Warner's is.
   type Listener is limited interface;

   procedure Warn (L : in out Listener; Message : String) is abstract;

   --  What came of a Load or Parse: its status, and the parser's message
   --  when Malformed (else empty).
   type Load_Outcome is record
      Status : Load_Status := Loaded;
      Error  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Load, with the table's complaints heard by Heard_By, which Root and
   --  every table taken from it carry: Heard_By must outlive them all.
   procedure Load
     (Path     : String;
      Label    : String;
      Heard_By : not null access Listener'Class;
      Root     : out Table;
      Result   : out Load_Outcome);

   --  Parse, with the table's complaints heard by Heard_By, as Load's.
   procedure Parse
     (Content  : String;
      Label    : String;
      Heard_By : not null access Listener'Class;
      Root     : out Table;
      Result   : out Load_Outcome);

   --  The named sub-table, carrying Root's label and warner or listener
   --  along.
   --  Absent or not-a-table yields the empty table: a missing section
   --  keeps every default, silently.
   function Section (Root : Table; Name : String) return Table;

   function Get (T : Table; Key : String; Fallback : Boolean) return Boolean;

   --  Whether Key is present at all, of any type, valid or not -- no
   --  fallback, no coercion, never warns.  The one presence primitive a
   --  caller needs to build its OWN resolution policy (e.g. layering
   --  several tables and asking which one actually set a key) over the
   --  typed Get functions; that policy is application-specific and does
   --  not belong in this generic reader.
   function Has (T : Table; Key : String) return Boolean;

   --  A count knob; Min guards the knobs a zero (or too-small value)
   --  would break.  Out-of-range values warn and fall back like wrong
   --  types.
   function Get
     (T : Table; Key : String; Fallback : Natural; Min : Natural := 0)
      return Natural;

   --  Require_Non_Empty treats a present-but-empty string as a
   --  misconfiguration (an empty URL can never connect), warned like a
   --  wrong type -- never a value the caller would act on forever.
   function Get
     (T                 : Table;
      Key               : String;
      Fallback          : String;
      Require_Non_Empty : Boolean := False) return String;

   --  A real-valued knob: TOML integers (2 is as good as 2.0), regular
   --  floats, or quoted plain decimals ("0.02", always exact).  The
   --  quoted form predates the ada_toml pin: 0.5.0 reassembled bare
   --  floats from an INTEGER fraction, dropping the fraction's leading
   --  zeros -- 0.02 loaded as 0.2 and 1.05 as 1.5 -- so decimal-shaped
   --  knobs had to be quotable.  The pinned parser keeps those zeros;
   --  the quoted shape stays supported, checked by the proven
   --  Tabula.Decimals.Is_Plain_Decimal before conversion.
   function Get
     (T : Table; Key : String; Fallback : Long_Float) return Long_Float;

   --  A number as a whole count of Scale's units (0.2621 at a scale of a
   --  million is 262100), for a caller with no floating point: rounded
   --  to the nearest unit, a half away from zero.  A TOML integer is
   --  multiplied exactly, a quoted plain decimal is scaled from its
   --  digits exactly, and a TOML float is scaled and rounded.  A result
   --  outside Tabula.Decimals.Scaled_Value warns and falls back, as a
   --  value that is not a number does.
   function Get_Scaled
     (T : Table; Key : String; Scale : Positive; Fallback : Long_Long_Integer)
      return Long_Long_Integer;

   --  A date knob: a TOML local date (start = 2020-01-01) or the same
   --  text quoted.  A day the calendar lacks (2021-02-29, which the
   --  parser lets through) warns and falls back, as does any other
   --  value, a date with a time among them.
   function Get (T : Table; Key : String; Fallback : Date) return Date;

   --  A time-of-day knob: a TOML local time (open = 09:30:00) or the
   --  same text quoted.  A time finer than a second warns and falls
   --  back rather than lose its fraction, as does any other value.
   function Get
     (T : Table; Key : String; Fallback : Time_Of_Day) return Time_Of_Day;

   --  Walk the strings of an array knob: an absent key does nothing, a
   --  non-array warns and does nothing, each non-string entry warns and
   --  is skipped.
   procedure Each_String
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : String));

   --  Walk the numbers of an array knob, each as a whole count of
   --  Scale's units, taken as Get_Scaled takes one number: an absent key
   --  does nothing, a non-array warns and does nothing, and each entry
   --  that is not a number, or is outside Tabula.Decimals.Scaled_Value
   --  at Scale, warns and is skipped while the walk goes on.
   procedure Each_Scaled
     (T       : Table;
      Key     : String;
      Scale   : Positive;
      Process : not null access procedure (Item : Long_Long_Integer));

   --  Walk the sub-tables of an array-of-tables knob ([[trades]]),
   --  each carrying the root's label and warner or listener: an absent
   --  key does nothing, a non-array warns and does nothing, each
   --  non-table entry warns and is skipped.
   procedure Each_Section
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : Table));

   --  Walk the keys T holds, in the order the file first wrote each,
   --  sub-tables and arrays of tables among them: how a caller finds a
   --  key it did not know to ask for, a misspelled knob among them.  An
   --  empty or non-table T walks nothing, silently.
   procedure Each_Key
     (T : Table; Process : not null access procedure (Key : String));

   --  What a walk hands its items to, in an object of the caller's own:
   --  one interface per walk, each primitive named for its walk, so one
   --  caller type may visit several.  Each walk below is the walk of the
   --  same name above, item for item and warning for warning.

   type String_Visitor is limited interface;

   procedure Visit_String (V : in out String_Visitor; Item : String)
   is abstract;

   type Scaled_Visitor is limited interface;

   procedure Visit_Scaled (V : in out Scaled_Visitor; Item : Long_Long_Integer)
   is abstract;

   type Section_Visitor is limited interface;

   procedure Visit_Section (V : in out Section_Visitor; Item : Table)
   is abstract;

   type Key_Visitor is limited interface;

   procedure Visit_Key (V : in out Key_Visitor; Key : String) is abstract;

   --  Each_String, handing each string to Visitor.
   procedure Each_String
     (T : Table; Key : String; Visitor : in out String_Visitor'Class);

   --  Each_Scaled, handing each number to Visitor.
   procedure Each_Scaled
     (T       : Table;
      Key     : String;
      Scale   : Positive;
      Visitor : in out Scaled_Visitor'Class);

   --  Each_Section, handing each sub-table to Visitor.
   procedure Each_Section
     (T : Table; Key : String; Visitor : in out Section_Visitor'Class);

   --  Each_Key, handing each key to Visitor.
   procedure Each_Key (T : Table; Visitor : in out Key_Visitor'Class);

   --  What a walk of a list of lists hands each inner list to: a table
   --  that is the list.
   type List_Visitor is limited interface;

   procedure Visit_List (V : in out List_Visitor; Item : Table) is abstract;

   --  Walk the lists of a list-of-lists knob -- a grid, whose outer list
   --  is the options and each inner list one option's value
   --  (entry_targets = [[15, 25, 35], [20, 30]]) -- handing each inner
   --  list to Visitor as a table carrying T's label and warner or
   --  listener, whose entries the keyless Each_String and Each_Scaled
   --  below walk.  An absent key does nothing, a non-array warns and does
   --  nothing, and each entry that is not an array warns and is skipped.
   --
   --  A flat list (entry_targets = [25, 35]) -- an array none of whose
   --  entries is an array, the empty one among them -- is one option,
   --  the whole list, silently: how a single-run config writes the value,
   --  and the only reading of it where a grid is wanted that means
   --  anything.
   procedure Each_List
     (T : Table; Key : String; Visitor : in out List_Visitor'Class);

   --  Walk the strings of List, a list Each_List handed over, as
   --  Each_String walks a knob's: each non-string entry warns and is
   --  skipped.  The warning names the list by its key and its place in
   --  the grid counting from one (entry_targets[2]), or by its key alone
   --  when it was a flat list.  A table that is not such a list walks
   --  nothing, silently.
   procedure Each_String (List : Table; Visitor : in out String_Visitor'Class);

   --  Walk the numbers of List, a list Each_List handed over, at Scale,
   --  as Each_Scaled walks a knob's: each entry that is not a number, or
   --  does not fit, warns, naming the list as the keyless Each_String
   --  does, and is skipped.  A table that is not such a list walks
   --  nothing, silently.
   procedure Each_Scaled
     (List : Table; Scale : Positive; Visitor : in out Scaled_Visitor'Class);

   --  Each_List, handing each list to Process.
   procedure Each_List
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : Table));

   --  The keyless Each_String, handing each string to Process.
   procedure Each_String
     (List : Table; Process : not null access procedure (Item : String));

   --  The keyless Each_Scaled, handing each number to Process.
   procedure Each_Scaled
     (List    : Table;
      Scale   : Positive;
      Process : not null access procedure (Item : Long_Long_Integer));

private

   type Listener_Access is access all Listener'Class;

   --  Where a table's complaints go: its listener when it has one, else
   --  its warner, else nowhere.
   type Sink is record
      Warn     : Warner;
      Heard_By : Listener_Access;
   end record;

   --  Name is what a list's complaints call it: its key and its place in
   --  the list of lists it came from; empty for any other table.
   type Table is record
      Value : TOML.TOML_Value := TOML.No_TOML_Value;
      Label : Ada.Strings.Unbounded.Unbounded_String;
      To    : Sink;
      Name  : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Tabula.Config;
