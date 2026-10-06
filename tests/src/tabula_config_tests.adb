with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Config; use Tabula.Config;

with Tabula_World; use Tabula_World;

package body Tabula_Config_Tests is

   use AUnit.Test_Cases.Registration;
   use type Tabula.Date;
   use type Tabula.Time_Of_Day;

   procedure Parse_Sample (Content : String; Root : out Table) is
      Status : Load_Status;
      Error  : Unbounded_String;
   begin
      Tabula_World.Parse (Content, "test config", Root, Status, Error);
      Assert (Status = Loaded, "the sample parses");
   end Parse_Sample;

   procedure Test_Policy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("flag = true"
         & ASCII.LF
         & "count = 7"
         & ASCII.LF
         & "name = ""ada"""
         & ASCII.LF
         & "wrong = ""not a number""",
         Root);

      Assert (Get (Root, "flag", Fallback => False), "boolean reads");
      Assert (Get (Root, "count", Fallback => 0) = 7, "count reads");
      Assert (Get (Root, "name", Fallback => "x") = "ada", "string reads");

      Assert
        (Get (Root, "absent", Fallback => 9) = 9,
         "an absent key keeps the fallback");
      Assert (Silent, "and does so silently");

      Assert
        (Get (Root, "wrong", Fallback => 9) = 9,
         "a wrong-typed key keeps the fallback");
      Assert
        (Warned ("test config: wrong is not a number in 0 .. Natural'Last"),
         "and warns with the label and key");
   end Test_Policy;

   procedure Test_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("zero = 0" & ASCII.LF & "negative = -4" & ASCII.LF & "empty = """"",
         Root);

      Assert
        (Get (Root, "zero", Fallback => 5, Min => 1) = 5,
         "a value below Min falls back");
      Assert (Warned ("zero is not a number in 1 .."), "with the Min shown");
      Assert
        (Get (Root, "negative", Fallback => 5) = 5,
         "a negative count falls back");
      Assert
        (Get (Root, "empty", Fallback => "d") = "",
         "an empty string is a string");
      Assert
        (Get (Root, "empty", Fallback => "d", Require_Non_Empty => True) = "d",
         "unless the knob requires substance");
      Assert
        (Warned ("empty is not a non-empty string"), "which warns distinctly");
   end Test_Bounds;

   procedure Test_Reals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("whole = 2"
         & ASCII.LF
         & "plain = 1.5"
         & ASCII.LF
         & "small = 0.02"
         & ASCII.LF
         & "mixed = 1.05"
         & ASCII.LF
         & "quoted = ""0.02"""
         & ASCII.LF
         & "fancy = ""1e3""",
         Root);

      Assert
        (Get (Root, "whole", Fallback => 0.0) = 2.0,
         "an integer is as good as a float");
      Assert
        (Get (Root, "plain", Fallback => 0.0) = 1.5, "a regular float reads");
      Assert
        (Get (Root, "small", Fallback => 0.0) = 0.02,
         "a bare float keeps its fraction's leading zeros");
      Assert
        (Get (Root, "mixed", Fallback => 0.0) = 1.05,
         "even behind a non-zero integer part");
      Assert
        (Get (Root, "quoted", Fallback => 0.0) = 0.02,
         "a quoted plain decimal reads exactly");
      Assert
        (Get (Root, "fancy", Fallback => 7.0) = 7.0,
         "an exotic quoted shape falls back");
      Assert (Warned ("fancy is not a number"), "with a warning");
   end Test_Reals;

   procedure Test_Sections (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("top = 1" & ASCII.LF & "[trading]" & ASCII.LF & "dry_run = false",
         Root);

      Assert
        (not Get (Section (Root, "trading"), "dry_run", Fallback => True),
         "a section's knobs read through Section");
      Assert
        (Get (Section (Root, "missing"), "dry_run", Fallback => True),
         "a missing section keeps every default");
      Assert
        (Get (Section (Root, "top"), "dry_run", Fallback => True),
         "a non-table key yields the empty section");
      Assert
        (Silent,
         "missing sections are silent -- a config states only changes");
   end Test_Sections;

   procedure Test_Arrays (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
      Seen : Unbounded_String;

      procedure Collect (Item : String);

      procedure Collect (Item : String) is
      begin
         Append (Seen, Item & ",");
      end Collect;
   begin
      Parse_Sample
        ("names = [""a"", 3, ""b""]" & ASCII.LF & "scalar = 1", Root);

      Each_String (Root, "names", Collect'Access);
      Assert (To_String (Seen) = "a,b,", "strings visit in order");
      Assert
        (Warned ("non-string names entry skipped"),
         "the non-string entry warns");

      Each_String (Root, "absent", Collect'Access);
      Assert (To_String (Seen) = "a,b,", "an absent array does nothing");

      Each_String (Root, "scalar", Collect'Access);
      Assert (Warned ("scalar is not an array"), "a non-array warns");
   end Test_Arrays;

   procedure Test_Malformed (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root   : Table;
      Status : Load_Status;
      Error  : Unbounded_String;
   begin
      Parse ("not = = toml", "test config", null, Root, Status, Error);
      Assert (Status = Malformed, "a broken document is Malformed");
      Assert (Length (Error) > 0, "with the parser's message");
      Assert
        (Get (Root, "not", Fallback => 3) = 3,
         "and the empty table falls back everywhere");
   end Test_Malformed;

   procedure Test_Missing_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root   : Table;
      Status : Load_Status;
      Error  : Unbounded_String;
   begin
      Load ("no-such-file.toml", "test config", null, Root, Status, Error);
      Assert (Status = Missing, "a missing file is Missing, not Malformed");
      Assert
        (Get (Root, "anything", Fallback => True),
         "and the empty table falls back everywhere");
   end Test_Missing_File;

   --  Array-of-tables walking ([[trades]]): each sub-table arrives
   --  carrying the root's label and warner; an absent key does
   --  nothing silently; a non-array warns and does nothing; a
   --  non-table entry warns and is skipped.
   procedure Test_Table_Arrays (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root  : Table;
      Seen  : Unbounded_String;
      Count : Natural := 0;

      procedure Note (Item : Table) is
      begin
         Count := Count + 1;
         Append (Seen, Get (Item, "name", "?") & ";");
      end Note;

   begin
      Parse_Sample
        ("[[trades]]"
         & ASCII.LF
         & "name = ""alpha"""
         & ASCII.LF
         & "[[trades]]"
         & ASCII.LF
         & "name = ""beta"""
         & ASCII.LF,
         Root);

      Each_Section (Root, "trades", Note'Access);
      Assert (Count = 2, "both sub-tables walked");
      Assert (To_String (Seen) = "alpha;beta;", "in file order");

      Each_Section (Root, "absent", Note'Access);
      Assert (Count = 2, "an absent key walks nothing");
      Assert (Silent, "and does so silently");

      Parse_Sample ("trades = 5", Root);
      Each_Section (Root, "trades", Note'Access);
      Assert (Count = 2, "a non-array walks nothing");
      Assert (Warned ("not an array"), "and warns");

      Parse_Sample ("trades = [1, 2]", Root);
      Each_Section (Root, "trades", Note'Access);
      Assert (Count = 2, "non-table entries are skipped");
      Assert (Warned ("non-table"), "each with a warning");
   end Test_Table_Arrays;

   procedure Test_Has (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("flag = false" & ASCII.LF & "wrong = ""not a number""", Root);

      Assert (Has (Root, "flag"), "a present key, even a falsy one");
      Assert (Has (Root, "wrong"), "a present key of any type/validity");
      Assert (not Has (Root, "absent"), "an absent key");
      Assert (Silent, "Has never warns");
   end Test_Has;

   --  A number as a whole count of Scale's units: an integer multiplied,
   --  a float scaled and rounded, a quoted decimal from its digits; a
   --  value that does not fit, a non-number and a special float each
   --  warn and fall back.
   procedure Test_Scaled (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("whole = -7"
         & ASCII.LF
         & "bare = 0.2621"
         & ASCII.LF
         & "tie = -0.125"
         & ASCII.LF
         & "quoted = ""0.2621"""
         & ASCII.LF
         & "flag = true",
         Root);

      Assert (Get_Scaled (Root, "whole", 1_000, 0) = -7_000, "an integer");
      Assert
        (Get_Scaled (Root, "bare", 1_000_000, 0) = 262_100, "a bare float");
      Assert
        (Get_Scaled (Root, "tie", 100, 0) = -13,
         "a float's tie rounds away from zero");
      Assert
        (Get_Scaled (Root, "quoted", 1_000_000, 0) = 262_100,
         "a quoted decimal");
      Assert (Get_Scaled (Root, "absent", 10, -4) = -4, "absent: fallback");
      Assert (Silent, "all of it silently");

      Assert (Get_Scaled (Root, "flag", 10, 3) = 3, "a boolean falls back");
      Assert
        (Warned ("test config: flag is not a number; using default"),
         "and warns as the real getter does");
   end Test_Scaled;

   --  Every way a present number fails to fit warns and falls back.
   procedure Test_Scaled_Range (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("big = 9223372036854775807"
         & ASCII.LF
         & "float = 1e300"
         & ASCII.LF
         & "quoted = ""922337203685477580.8"""
         & ASCII.LF
         & "nan = nan"
         & ASCII.LF
         & "inf = -inf"
         & ASCII.LF
         & "fancy = ""1e3""",
         Root);

      Assert (Get_Scaled (Root, "big", 2, 1) = 1, "an integer too large");
      Assert
        (Warned ("test config: big is out of range at a scale of 2"),
         "says so, with the scale");
      Assert (Get_Scaled (Root, "float", 1, 1) = 1, "a float too large");
      Assert (Warned ("float is out of range"), "says so");
      Assert (Get_Scaled (Root, "quoted", 10, 1) = 1, "a decimal too large");
      Assert (Warned ("quoted is out of range"), "says so");
      Assert (Get_Scaled (Root, "nan", 1, 1) = 1, "a NaN");
      Assert (Warned ("nan is not a number"), "is not a number");
      Assert (Get_Scaled (Root, "inf", 1, 1) = 1, "an infinity");
      Assert (Warned ("inf is not a number"), "is not a number either");
      Assert (Get_Scaled (Root, "fancy", 1, 1) = 1, "an exotic quoted shape");
      Assert (Warned ("fancy is not a number"), "is not a number");
   end Test_Scaled_Range;

   --  A sample of every shape a date or time knob may take.
   Dates_Sample : constant String :=
     "bare = 2020-01-01"
     & ASCII.LF
     & "quoted = ""2024-02-29"""
     & ASCII.LF
     & "unreal = 2021-02-29"
     & ASCII.LF
     & "unreal_text = ""2021-02-29"""
     & ASCII.LF
     & "stamp = 2020-01-01T09:30:00"
     & ASCII.LF
     & "clock = 09:30:00"
     & ASCII.LF
     & "clock_text = ""16:15:00"""
     & ASCII.LF
     & "fine = 09:30:00.250"
     & ASCII.LF
     & "count = 3";

   Some_Day  : constant Tabula.Date := (1999, 12, 31);
   Some_Time : constant Tabula.Time_Of_Day := (12, 0, 0);

   --  A bare or quoted date reads; one the calendar lacks, a datetime and
   --  a non-date warn and fall back; absence is silent.
   procedure Test_Dates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample (Dates_Sample, Root);
      Assert (Get (Root, "bare", Some_Day) = (2020, 1, 1), "a bare date");
      Assert (Get (Root, "quoted", Some_Day) = (2024, 2, 29), "a quoted one");
      Assert (Get (Root, "absent", Some_Day) = Some_Day, "absent: default");
      Assert (Silent, "silently");

      Assert (Get (Root, "unreal", Some_Day) = Some_Day, "no such day");
      Assert
        (Warned ("test config: unreal is not a date; using default"),
         "warns as not a date");
      Assert (Get (Root, "unreal_text", Some_Day) = Some_Day, "nor quoted");
      Assert (Warned ("unreal_text is not a date"), "warns");
      Assert (Get (Root, "stamp", Some_Day) = Some_Day, "a datetime");
      Assert (Warned ("stamp is not a date"), "is not a date");
      Assert (Get (Root, "count", Some_Day) = Some_Day, "an integer");
      Assert (Warned ("count is not a date"), "is not a date");
   end Test_Dates;

   --  A bare or quoted time reads; a fraction of a second, a date and a
   --  non-time warn and fall back; absence is silent.
   procedure Test_Times (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample (Dates_Sample, Root);
      Assert (Get (Root, "clock", Some_Time) = (9, 30, 0), "a bare time");
      Assert
        (Get (Root, "clock_text", Some_Time) = (16, 15, 0), "a quoted one");
      Assert (Get (Root, "absent", Some_Time) = Some_Time, "absent");
      Assert (Silent, "silently");

      Assert (Get (Root, "fine", Some_Time) = Some_Time, "a fraction");
      Assert
        (Warned
           ("test config: fine is not a time to the second;"
            & " using default"),
         "warns that it is finer than a second");
      Assert (Get (Root, "bare", Some_Time) = Some_Time, "a date");
      Assert (Warned ("bare is not a time;"), "is not a time");
      Assert (Get (Root, "unreal_text", Some_Time) = Some_Time, "a string");
      Assert (Warned ("unreal_text is not a time;"), "is not a time");
   end Test_Times;

   --  What Each_Key visited, comma-separated, for Test_Each_Key.
   Keys_Seen : Unbounded_String;

   procedure Collect_Key (Key : String) is
   begin
      Append (Keys_Seen, Key & ",");
   end Collect_Key;

   --  Each_Key over Root's sub-table Name, from nothing seen.
   function Keys_Of (Root : Table; Name : String := "") return String is
   begin
      Keys_Seen := Null_Unbounded_String;
      Each_Key
        ((if Name = "" then Root else Section (Root, Name)),
         Collect_Key'Access);
      return To_String (Keys_Seen);
   end Keys_Of;

   --  Keys come in the order the file wrote them -- not sorted -- with
   --  sub-tables and arrays of tables among them; a section lists its
   --  own; an empty or non-table value lists none, silently.
   procedure Test_Each_Key (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root  : Table;
      Empty : Table;
   begin
      Parse_Sample
        ("zeta = 1"
         & ASCII.LF
         & "alpha = ""a"""
         & ASCII.LF
         & "mid = [1, 2]"
         & ASCII.LF
         & "[[runs]]"
         & ASCII.LF
         & "[box]"
         & ASCII.LF
         & "inner = true"
         & ASCII.LF
         & "first = 0",
         Root);

      Assert
        (Keys_Of (Root) = "zeta,alpha,mid,runs,box,",
         "the root's keys in file order: " & Keys_Of (Root));
      Assert
        (Keys_Of (Root, "box") = "inner,first,",
         "a section lists its own keys: " & Keys_Of (Root, "box"));
      Assert (Keys_Of (Root, "zeta") = "", "a non-table lists nothing");
      Assert (Keys_Of (Root, "absent") = "", "an absent table, nothing");
      Assert (Keys_Of (Empty) = "", "an empty table, nothing");
      Assert (Silent, "and none of it says anything");
   end Test_Each_Key;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Policy'Access, "absent is silent, wrong-typed warns");
      Register_Routine
        (T, Test_Table_Arrays'Access, "array-of-tables walking");
      Register_Routine
        (T, Test_Bounds'Access, "Min and Require_Non_Empty guards");
      Register_Routine
        (T, Test_Reals'Access, "integer / float / quoted-decimal knobs");
      Register_Routine
        (T, Test_Sections'Access, "sections carry label and warner");
      Register_Routine (T, Test_Arrays'Access, "string-array walking");
      Register_Routine
        (T, Test_Malformed'Access, "malformed input is a result");
      Register_Routine
        (T, Test_Missing_File'Access, "missing file is a distinct status");
      Register_Routine (T, Test_Has'Access, "presence check, no fallback");
      Register_Routine (T, Test_Each_Key'Access, "keys in file order");
      Register_Routine (T, Test_Scaled'Access, "a number at a scale");
      Register_Routine (T, Test_Dates'Access, "a date, bare or quoted");
      Register_Routine (T, Test_Times'Access, "a time, bare or quoted");
      Register_Routine
        (T, Test_Scaled_Range'Access, "a scaled number that does not fit");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config (typed knobs with fallbacks)");
   end Name;

end Tabula_Config_Tests;
