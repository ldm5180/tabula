with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Config;        use Tabula.Config;
with Tabula.Config.Values; use Tabula.Config.Values;

with Tabula_World; use Tabula_World;

--  The walk of every value a table or a list holds, each with its kind
--  and its text, gathered as key:KIND:text, a table's values in braces
--  and a list's in brackets.

package body Tabula_Config_Values_Tests is

   use AUnit.Test_Cases.Registration;

   LF : constant Character := ASCII.LF;

   --  Content parsed under a listener of the test's own, which must hear
   --  nothing.
   procedure Parse_Silently
     (Content : String; Heard : aliased in out Recorder; Root : out Table)
   is
      Result : Load_Outcome;
   begin
      Parse (Content, "values config", Heard'Access, Root, Result);
      Assert
        (Result.Status = Loaded,
         "the sample parses: " & To_String (Result.Error));
   end Parse_Silently;

   --  What a walk of Root gathers.
   function Walked (Root : Table) return String is
      Gathered : Value_Gatherer;
   begin
      Each_Value (Root, Gathered);
      return Items (Gathered);
   end Walked;

   --  A table's values in the order the file wrote their keys, each with
   --  its kind and its text: a string as it reads, an integer as its
   --  decimal digits, a flag as true or false.
   procedure Test_Scalars (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
   begin
      Parse_Silently
        ("zeta = ""ada"""
         & LF
         & "count = 7"
         & LF
         & "negative = -12"
         & LF
         & "hex = 0xff"
         & LF
         & "flag = true"
         & LF
         & "alpha = false"
         & LF,
         Heard,
         Root);
      Assert
        (Walked (Root)
         = "zeta:A_TEXT:ada,count:AN_INTEGER:7,negative:AN_INTEGER:-12,"
           & "hex:AN_INTEGER:255,flag:A_FLAG:true,alpha:A_FLAG:false",
         "each value, in file order: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Scalars;

   --  A table or a list among the values is handed over as a table the
   --  walk takes in turn: a list's values have no key.
   procedure Test_Nesting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
   begin
      Parse_Silently
        ("list = [1, ""two"", [3, []]]"
         & LF
         & "inline = { b = 1, a = 2 }"
         & LF
         & "[section]"
         & LF
         & "inner = ""x"""
         & LF
         & "[[runs]]"
         & LF
         & "n = 1"
         & LF,
         Heard,
         Root);
      Assert
        (Walked (Root)
         = "list:AN_ARRAY:[:AN_INTEGER:1,:A_TEXT:two,"
           & ":AN_ARRAY:[:AN_INTEGER:3,:AN_ARRAY:[]]],"
           & "inline:A_TABLE:{b:AN_INTEGER:1,a:AN_INTEGER:2},"
           & "section:A_TABLE:{inner:A_TEXT:x},"
           & "runs:AN_ARRAY:[:A_TABLE:{n:AN_INTEGER:1}]",
         "tables and lists, walked in turn: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Nesting;

   --  An empty table, a missing section and a value that is neither a
   --  table nor a list walk nothing, silently.
   procedure Test_Nothing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
      Empty : Table;
      Seen  : Unbounded_String;
   begin
      Parse_Silently ("scalar = 1" & LF, Heard, Root);
      Append (Seen, Walked (Empty));
      Append (Seen, Walked (Section (Root, "absent")));
      Append (Seen, Walked (Section (Root, "scalar")));
      Assert (To_String (Seen) = "", "nothing walked: " & To_String (Seen));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Nothing;

   Decimal_Sample : constant String :=
     "plain = 0.2621"
     & LF
     & "small = 0.02"
     & LF
     & "long = 0.123456789012345678"
     & LF
     & "trailing = 1.50"
     & LF
     & "grouped = 1_000.000_25"
     & LF
     & "signed = +2.5"
     & LF
     & "exponent = -1.5e-3"
     & LF
     & "large = 6.02E+23"
     & LF
     & "tabbed ="
     & ASCII.HT
     & "2.5"
     & LF
     & "list = [1.5,2.25, [-0.0]]"
     & LF
     & "inline = { x = 0.75 }"
     & LF;

   Decimal_Walk : constant String :=
     "plain:A_DECIMAL:0.2621,small:A_DECIMAL:0.02,"
     & "long:A_DECIMAL:0.123456789012345678,trailing:A_DECIMAL:1.50,"
     & "grouped:A_DECIMAL:1000.00025,signed:A_DECIMAL:2.5,"
     & "exponent:A_DECIMAL:-0.0015,"
     & "large:A_DECIMAL:602000000000000000000000,tabbed:A_DECIMAL:2.5,"
     & "list:AN_ARRAY:[:A_DECIMAL:1.5,:A_DECIMAL:2.25,"
     & ":AN_ARRAY:[:A_DECIMAL:-0.0]],"
     & "inline:A_TABLE:{x:A_DECIMAL:0.75}";

   --  A float with digits is a decimal whose text is the document's
   --  literal as a plain decimal, exactly: every digit written, none a
   --  binary double would add or lose.
   procedure Test_Decimals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
   begin
      Parse_Silently (Decimal_Sample, Heard, Root);
      Assert
        (Walked (Root) = Decimal_Walk,
         "each decimal as written: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Decimals;

   --  A decimal's text reads back as the very float the parser read.
   type Round_Trip is limited new Value_Visitor with record
      From  : Table;
      Fails : Unbounded_String;
   end record;

   overriding
   procedure Visit_Value
     (V    : in out Round_Trip;
      Key  : String;
      Kind : Value_Kind;
      Text : String;
      Item : Table);

   overriding
   procedure Visit_Value
     (V    : in out Round_Trip;
      Key  : String;
      Kind : Value_Kind;
      Text : String;
      Item : Table)
   is
      pragma Unreferenced (Item);
   begin
      if Kind = A_Decimal
        and then Long_Float'Value (Text) /= Get (V.From, Key, Long_Float'Last)
      then
         Append (V.Fails, " " & Key & "=" & Text);
      end if;
   end Visit_Value;

   procedure Test_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Trip  : Round_Trip;
   begin
      Parse_Silently (Decimal_Sample, Heard, Trip.From);
      Each_Value (Trip.From, Trip);
      Assert
        (To_String (Trip.Fails) = "",
         "every decimal reads back as parsed:" & To_String (Trip.Fails));
   end Test_Round_Trip;

   --  A file loaded keeps its text, so its decimals read as written,
   --  CR LF line ends among them.
   procedure Test_Loaded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path   : constant String := Scratch ("values.toml");
      Heard  : aliased Recorder;
      Root   : Table;
      Result : Load_Outcome;
   begin
      Write_File
        (Path,
         "a = 0.10"
         & ASCII.CR
         & LF
         & "b = ["
         & ASCII.CR
         & LF
         & "2.5e1]"
         & ASCII.CR
         & LF);
      Load (Path, "values file", Heard'Access, Root, Result);
      Assert (Result.Status = Loaded, "the file loads");
      Assert
        (Walked (Root) = "a:A_DECIMAL:0.10,b:AN_ARRAY:[:A_DECIMAL:25]",
         "its decimals as written: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Loaded;

   --  A float that is not a number, and an infinite one, are kinds of
   --  their own, their text the value's sign and name.
   procedure Test_Specials (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
   begin
      Parse_Silently
        ("a = nan"
         & LF
         & "b = -nan"
         & LF
         & "c = +inf"
         & LF
         & "d = -inf"
         & LF
         & "e = inf"
         & LF,
         Heard,
         Root);
      Assert
        (Walked (Root)
         = "a:NOT_A_NUMBER:nan,b:NOT_A_NUMBER:-nan,c:AN_INFINITY:inf,"
           & "d:AN_INFINITY:-inf,e:AN_INFINITY:inf",
         "the special floats: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Specials;

   --  A date, a time and a date-time, local or with an offset, are each a
   --  kind of their own, their text the canonical TOML form: a T between
   --  date and time, milliseconds when the time has a fraction, Z for
   --  UTC; in a list as at a key.
   procedure Test_Calendar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
   begin
      Parse_Silently
        ("day = 2020-01-01"
         & LF
         & "open = 09:30:00"
         & LF
         & "fine = 09:30:00.25"
         & LF
         & "local = 2020-01-01T09:30:00"
         & LF
         & "spaced = 2020-01-01 09:30:00.5"
         & LF
         & "zulu = 1979-05-27T07:32:00Z"
         & LF
         & "east = 1979-05-27T07:32:00+05:30"
         & LF
         & "west = 1979-05-27T07:32:00.999-08:00"
         & LF
         & "unknown = 1979-05-27T07:32:00-00:00"
         & LF
         & "days = [2020-01-01, 2030-12-31]"
         & LF,
         Heard,
         Root);
      Assert
        (Walked (Root)
         = "day:A_DATE:2020-01-01,open:A_TIME:09:30:00,"
           & "fine:A_TIME:09:30:00.250,"
           & "local:A_LOCAL_DATETIME:2020-01-01T09:30:00,"
           & "spaced:A_LOCAL_DATETIME:2020-01-01T09:30:00.500,"
           & "zulu:AN_OFFSET_DATETIME:1979-05-27T07:32:00Z,"
           & "east:AN_OFFSET_DATETIME:1979-05-27T07:32:00+05:30,"
           & "west:AN_OFFSET_DATETIME:1979-05-27T07:32:00.999-08:00,"
           & "unknown:AN_OFFSET_DATETIME:1979-05-27T07:32:00-00:00,"
           & "days:AN_ARRAY:[:A_DATE:2020-01-01,:A_DATE:2030-12-31]",
         "each calendar value: " & Walked (Root));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Calendar;

   --  The walk to a procedure: the same values as to a visitor.
   procedure Test_Procedure (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard : aliased Recorder;
      Root  : Table;
      Seen  : Unbounded_String;

      procedure Take
        (Key : String; Kind : Value_Kind; Text : String; Item : Table);

      procedure Take
        (Key : String; Kind : Value_Kind; Text : String; Item : Table) is
      begin
         Append (Seen, " " & Key & "=" & Kind'Image & ":" & Text);
         Each_Value (Item, Take'Access);
      end Take;
   begin
      Parse_Silently
        ("a = 0.5" & LF & "b = [2020-01-01]" & LF & "[c]" & LF & "d = 1" & LF,
         Heard,
         Root);
      Each_Value (Root, Take'Access);
      Assert
        (To_String (Seen)
         = " a=A_DECIMAL:0.5 b=AN_ARRAY: =A_DATE:2020-01-01 c=A_TABLE:"
           & " d=AN_INTEGER:1",
         "each value, nested in turn: " & To_String (Seen));
      Assert (Silent (Heard), "silently: " & Warnings_Text (Heard));
   end Test_Procedure;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Scalars'Access, "values in file order");
      Register_Routine (T, Test_Nesting'Access, "tables and lists in turn");
      Register_Routine (T, Test_Nothing'Access, "nothing to walk");
      Register_Routine (T, Test_Decimals'Access, "a decimal as written");
      Register_Routine
        (T, Test_Round_Trip'Access, "a decimal's text reads back");
      Register_Routine (T, Test_Loaded'Access, "a loaded file's decimals");
      Register_Routine (T, Test_Specials'Access, "nan and infinities");
      Register_Routine (T, Test_Calendar'Access, "dates, times, date-times");
      Register_Routine (T, Test_Procedure'Access, "values to a procedure");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config.Values (every value, walked)");
   end Name;

end Tabula_Config_Values_Tests;
