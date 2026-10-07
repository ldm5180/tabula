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

   --  The numbers Each_Scaled visits in Root's list Key at Scale, each
   --  followed by a comma.
   function Scaled_Items
     (Root : Table; Key : String; Scale : Positive) return String
   is
      Seen : Unbounded_String;

      procedure Collect (Item : Long_Long_Integer);

      procedure Collect (Item : Long_Long_Integer) is
         Image : constant String := Item'Image;
      begin
         Append
           (Seen,
            (if Item < 0 then Image else Image (Image'First + 1 .. Image'Last))
            & ",");
      end Collect;
   begin
      Each_Scaled (Root, Key, Scale, Collect'Access);
      return To_String (Seen);
   end Scaled_Items;

   --  A list of numbers at a scale: each kind of number as Get_Scaled
   --  takes it, in order, silently.
   procedure Test_Scaled_List (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("targets = [15, ""0.0210"", 0.2621, -7]"
         & ASCII.LF
         & "ties = [0.125, ""-0.125"", -0.125]",
         Root);

      Assert
        (Scaled_Items (Root, "targets", 1_000_000)
         = "15000000,21000,262100,-7000000,",
         "an integer, a quoted decimal and a float, in order: "
         & Scaled_Items (Root, "targets", 1_000_000));
      Assert
        (Scaled_Items (Root, "ties", 100) = "13,-13,-13,",
         "each tie rounds away from zero: "
         & Scaled_Items (Root, "ties", 100));
      Assert (Scaled_Items (Root, "absent", 10) = "", "absent: nothing");
      Assert (Silent, "all of it silently");
   end Test_Scaled_List;

   --  A list's entry that is not a number, or does not fit, warns and is
   --  skipped, and the walk goes on; a non-list warns and walks nothing.
   procedure Test_Scaled_List_Skips
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : Table;
   begin
      Parse_Sample
        ("levels = [1, ""x"", 9223372036854775807, true, nan, ""1e3"", 2]"
         & ASCII.LF
         & "scalar = 1",
         Root);

      Assert
        (Scaled_Items (Root, "levels", 10) = "10,20,",
         "the numbers that fit, in order: "
         & Scaled_Items (Root, "levels", 10));
      Assert
        (Warned ("test config: non-number levels entry skipped"),
         "a non-number entry warns: " & Warnings_Text);
      Assert
        (Warned
           ("test config: levels entry out of range at a scale of 10;"
            & " skipped"),
         "an entry too large warns, with the scale: " & Warnings_Text);

      Assert (Scaled_Items (Root, "scalar", 10) = "", "a non-list: nothing");
      Assert
        (Warned ("test config: scalar is not an array; ignoring it"),
         "and warns as the other walkers do");
   end Test_Scaled_List_Skips;

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

   --  A sample whose root and section each hold a knob that warns.
   Listened_Sample : constant String :=
     "count = ""x""" & ASCII.LF & "[box]" & ASCII.LF & "flag = 1";

   --  A table parsed to a listener the test owns warns to it alone, with
   --  the label, and a section taken from it warns to it too; the
   --  recorder the warner feeds hears nothing.
   procedure Test_Listener (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard  : aliased Recorder;
      Root   : Table;
      Result : Load_Outcome;
   begin
      Reset;
      Parse (Listened_Sample, "own config", Heard'Access, Root, Result);
      Assert (Result.Status = Loaded, "the sample parses");
      Assert (Silent (Heard), "parsing says nothing");
      Assert (Get (Root, "count", Fallback => 4) = 4, "a wrong knob");
      Assert
        (Warned
           (Heard, "own config: count is not a number in 0 .. Natural'Last"),
         "warns to the listener, with the label: " & Warnings_Text (Heard));
      Assert (Get (Section (Root, "box"), "flag", True), "a section's");
      Assert
        (Complained (Heard, "own config", "flag"),
         "warns to the same listener: " & Warnings_Text (Heard));
      Assert (Silent, "and the warner's recorder heard none of it");
   end Test_Listener;

   --  Load and Parse to a listener come to the outcomes Load and Parse
   --  to a warner do: Missing, Malformed with the parser's message, and
   --  Loaded with the file's knobs.
   procedure Test_Listener_Outcomes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Heard  : aliased Recorder;
      Root   : Table;
      Result : Load_Outcome;
      Path   : constant String := Scratch ("listened.toml");
   begin
      Load ("no-such-file.toml", "own config", Heard'Access, Root, Result);
      Assert (Result.Status = Missing, "a missing file is Missing");
      Assert (Length (Result.Error) = 0, "with nothing to say");
      Parse ("not = = toml", "own config", Heard'Access, Root, Result);
      Assert (Result.Status = Malformed, "a broken document is Malformed");
      Assert (Length (Result.Error) > 0, "with the parser's message");
      Write_File (Path, Listened_Sample);
      Load (Path, "own config", Heard'Access, Root, Result);
      Assert (Result.Status = Loaded, "a file loads");
      Assert (Get (Root, "count", Fallback => 4) = 4, "its wrong knob");
      Assert (Warned (Heard, "count is not a number"), "warns to it");
   end Test_Listener_Outcomes;

   --  A sample with something for every walker, and entries each walker
   --  skips.
   Walked_Sample : constant String :=
     "names = [""a"", 3, ""b""]"
     & ASCII.LF
     & "levels = [15, ""0.0210"", ""x""]"
     & ASCII.LF
     & "scalar = 1"
     & ASCII.LF
     & "[box]"
     & ASCII.LF
     & "inner = true"
     & ASCII.LF
     & "first = 0"
     & ASCII.LF
     & "[[runs]]"
     & ASCII.LF
     & "name = ""alpha"""
     & ASCII.LF
     & "[[runs]]"
     & ASCII.LF
     & "name = ""beta"""
     & ASCII.LF
     & "flag = ""no""";

   --  The array walks hand their items to a visitor the test owns, in
   --  order, and complain of what they skip to the table's listener.
   procedure Test_Array_Visitors (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Heard            : aliased Recorder;
      Root             : Table;
      Result           : Load_Outcome;
      Strings, Numbers : Gatherer;
      Tables, Nothing  : Gatherer;
   begin
      Parse (Walked_Sample, "own config", Heard'Access, Root, Result);
      Each_String (Root, "names", Strings);
      Assert (Items (Strings) = "a,b", "strings: " & Items (Strings));
      Assert
        (Warned (Heard, "own config: non-string names entry skipped"),
         "the non-string warns to the listener");
      Each_Scaled (Root, "levels", 1_000_000, Numbers);
      Assert
        (Items (Numbers) = "15000000,21000", "numbers: " & Items (Numbers));
      Assert
        (Warned (Heard, "own config: non-number levels entry skipped"),
         "the non-number warns to the listener");
      Each_Section (Root, "runs", Tables);
      Assert (Items (Tables) = "alpha,beta", "tables: " & Items (Tables));
      Each_String (Root, "absent", Nothing);
      Each_Section (Root, "scalar", Nothing);
      Assert (Items (Nothing) = "", "absent and non-array walk nothing");
      Assert
        (Warned (Heard, "own config: scalar is not an array"),
         "the non-array warns: " & Warnings_Text (Heard));
   end Test_Array_Visitors;

   --  A visitor that keeps the last table a walk handed it.
   type Last_Section is limited new Section_Visitor with record
      Last : Table;
   end record;

   overriding
   procedure Visit_Section (V : in out Last_Section; Item : Table);

   overriding
   procedure Visit_Section (V : in out Last_Section; Item : Table) is
   begin
      V.Last := Item;
   end Visit_Section;

   --  A table a walk hands over warns to the listener of the table it
   --  came from; the keys of a table, a section's too, come in the
   --  file's order.
   procedure Test_Key_Visitor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard       : aliased Recorder;
      Root        : Table;
      Result      : Load_Outcome;
      Kept        : Last_Section;
      Keys, Inner : Gatherer;
   begin
      Parse (Walked_Sample, "own config", Heard'Access, Root, Result);
      Each_Section (Root, "runs", Kept);
      Assert (Get (Kept.Last, "flag", True), "a wrong knob in a walked table");
      Assert
        (Complained (Heard, "own config", "flag"),
         "warns to the root's listener: " & Warnings_Text (Heard));
      Each_Key (Root, Keys);
      Assert
        (Items (Keys) = "names,levels,scalar,box,runs",
         "the root's keys in file order: " & Items (Keys));
      Each_Key (Section (Root, "box"), Inner);
      Assert (Items (Inner) = "inner,first", "a section's: " & Items (Inner));
   end Test_Key_Visitor;

   --  A grid: lists of lists, as PRO writes its grid options, beside
   --  knobs a grid walk does not take.
   Grid_Sample : constant String :=
     "targets = [[15, 25, 35], [20, 30]]"
     & ASCII.LF
     & "filters = [[""skip EOM""], [""skip EOM"", ""skip FOMC""]]"
     & ASCII.LF
     & "scalar = 1";

   --  A visitor that counts the lists a walk handed it.
   type List_Counter is limited new List_Visitor with record
      Count : Natural := 0;
   end record;

   overriding
   procedure Visit_List (V : in out List_Counter; Item : Table);

   overriding
   procedure Visit_List (V : in out List_Counter; Item : Table) is
      pragma Unreferenced (Item);
   begin
      V.Count := V.Count + 1;
   end Visit_List;

   --  A grid walk hands over one list per option, in order; an absent
   --  knob walks nothing, silently, and a knob that is not an array walks
   --  nothing and is complained of.
   procedure Test_List_Walk (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Heard            : aliased Recorder;
      Root             : Table;
      Result           : Load_Outcome;
      Targets, Nothing : List_Counter;
   begin
      Parse (Grid_Sample, "grid config", Heard'Access, Root, Result);
      Each_List (Root, "targets", Targets);
      Assert (Targets.Count = 2, "one list per option:" & Targets.Count'Image);
      Each_List (Root, "absent", Nothing);
      Assert (Silent (Heard), "an absent knob is silent");
      Each_List (Root, "scalar", Nothing);
      Assert (Nothing.Count = 0, "absent and non-array walk nothing");
      Assert
        (Warned (Heard, "grid config: scalar is not an array; ignoring it"),
         "the non-array warns: " & Warnings_Text (Heard));
   end Test_List_Walk;

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
      Register_Routine (T, Test_Scaled_List'Access, "a list at a scale");
      Register_Routine
        (T, Test_Scaled_List_Skips'Access, "a scaled list's bad entries");
      Register_Routine
        (T, Test_Listener'Access, "warnings to the caller's listener");
      Register_Routine
        (T, Test_Listener_Outcomes'Access, "load and parse to a listener");
      Register_Routine
        (T, Test_Array_Visitors'Access, "array walks to a visitor");
      Register_Routine
        (T, Test_Key_Visitor'Access, "keys and walked tables, visited");
      Register_Routine (T, Test_List_Walk'Access, "a grid's lists, walked");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config (typed knobs with fallbacks)");
   end Name;

end Tabula_Config_Tests;
