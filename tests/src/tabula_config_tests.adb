with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Config; use Tabula.Config;

package body Tabula_Config_Tests is

   use AUnit.Test_Cases.Registration;

   --  A recording warner: the Warner type is a library-level access, so
   --  the recorder must be library-level too (package state, reset per
   --  routine).
   Warnings : Unbounded_String;

   procedure Record_Warning (Message : String) is
   begin
      Append (Warnings, Message & ";");
   end Record_Warning;

   procedure Parse_Sample (Content : String; Root : out Table) is
      Status : Load_Status;
      Error  : Unbounded_String;
   begin
      Warnings := Null_Unbounded_String;
      Parse
        (Content, "test config", Record_Warning'Access, Root, Status, Error);
      Assert (Status = Loaded, "the sample parses");
   end Parse_Sample;

   function Warned (Fragment : String) return Boolean
   is (Index (Warnings, Fragment) > 0);

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
      Assert (Warnings = Null_Unbounded_String, "and does so silently");

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
        (Warnings = Null_Unbounded_String,
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
      Assert (Warnings = Null_Unbounded_String, "and does so silently");

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
      Assert (Warnings = Null_Unbounded_String, "Has never warns");
   end Test_Has;

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
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config (typed knobs with fallbacks)");
   end Name;

end Tabula_Config_Tests;
