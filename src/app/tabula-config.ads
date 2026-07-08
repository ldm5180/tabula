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

   --  One TOML table plus the label and warner its getters report
   --  through.  Default-initialized: empty, so every getter falls back
   --  silently.
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

   --  The named sub-table, carrying Root's label and warner along.
   --  Absent or not-a-table yields the empty table: a missing section
   --  keeps every default, silently.
   function Section (Root : Table; Name : String) return Table;

   function Get (T : Table; Key : String; Fallback : Boolean) return Boolean;

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
   --  quoted form exists because ada_toml 0.5.0 reassembles bare floats
   --  from an INTEGER fraction, dropping the fraction's leading zeros --
   --  0.02 loads as 0.2 and 1.05 as 1.5 -- so decimal-shaped knobs must
   --  be quotable.  The quoted shape is checked by the proven
   --  Tabula.Decimals.Is_Plain_Decimal before conversion.
   function Get
     (T : Table; Key : String; Fallback : Long_Float) return Long_Float;

   --  Walk the strings of an array knob: an absent key does nothing, a
   --  non-array warns and does nothing, each non-string entry warns and
   --  is skipped.
   procedure Each_String
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : String));

private

   type Table is record
      Value : TOML.TOML_Value := TOML.No_TOML_Value;
      Label : Ada.Strings.Unbounded.Unbounded_String;
      Warn  : Warner;
   end record;

end Tabula.Config;
