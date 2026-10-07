with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Toml_Source; use Tabula.Toml_Source;

--  Where the parser places a number, mapped back to the document's
--  text.  The places below are the ones the parser recorded for these
--  very documents; the proof carries the absence of runtime errors.

package body Tabula_Toml_Source_Tests is

   use AUnit.Test_Cases.Registration;

   LF    : constant Character := ASCII.LF;
   CR    : constant Character := ASCII.CR;
   Tab   : constant Character := ASCII.HT;
   Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);

   --  The text of the number Number_At finds at Line and Column of
   --  Source, or "(none)".
   function Found (Source : String; Line, Column : Positive) return String is
      S : constant Span := Number_At (Source, Line, Column);
   begin
      return (if S.Found then Source (S.First .. S.Last) else "(none)");
   end Found;

   --  Whether the number at Line and Column of Source is Want, saying
   --  what was found when not.
   procedure Check (Source : String; Line, Column : Positive; Want : String) is
   begin
      Assert
        (Found (Source, Line, Column) = Want,
         "at"
         & Line'Image
         & ":"
         & Column'Image
         & " want "
         & Want
         & ", found "
         & Found (Source, Line, Column));
   end Check;

   --  A number is placed by the codepoint before it, or by its own first
   --  codepoint after an opening bracket; the first line counts its first
   --  codepoint as column one, a later line its line end.
   procedure Test_Places (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : constant String :=
        "a=1.5"
        & LF
        & "b = [1.5,2.5, 3.5 ,[4.5]]"
        & LF
        & "g = ["
        & LF
        & "1.5,"
        & LF
        & "  -2.5e-3"
        & LF
        & "]"
        & LF;
   begin
      Check (Doc, 1, 2, "1.5");
      Check (Doc, 2, 7, "1.5");
      Check (Doc, 2, 10, "2.5");
      Check (Doc, 2, 15, "3.5");
      Check (Doc, 2, 22, "4.5");
      Check (Doc, 4, 1, "1.5");
      Check (Doc, 5, 3, "-2.5e-3");
   end Test_Places;

   --  A tab moves the column to the parser's tab stops, a UTF-8 character
   --  is one column whatever its bytes, a CR LF is one line end, and a
   --  line end that opens the document is its first column.
   procedure Test_Columns (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : constant String :=
        LF
        & "a = ["""
        & Acute
        & Acute
        & """, 2.5]"
        & CR
        & LF
        & "b = ["
        & CR
        & LF
        & "1.5]"
        & LF
        & "c = [1,"
        & Tab
        & "2.5,"
        & Tab
        & Tab
        & "3.5]"
        & LF
        & "d = { x = [-1e3,+2.5] }"
        & LF;
   begin
      Check (Doc, 1, 12, "2.5");
      Check (Doc, 3, 1, "1.5");
      Check (Doc, 4, 16, "2.5");
      Check (Doc, 4, 32, "3.5");
      Check (Doc, 5, 13, "-1e3");
      Check (Doc, 5, 17, "+2.5");
   end Test_Columns;

   --  A place with no number at it or after it, or no place at all,
   --  finds nothing.
   procedure Test_Nothing (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : constant String := "a = ""x""" & LF & "b = 1.5";
   begin
      Check (Doc, 1, 4, "(none)");
      Check (Doc, 1, 40, "(none)");
      Check (Doc, 3, 1, "(none)");
      Check (Doc, 2, 4, "(none)");
      Check (Doc, 2, 5, "1.5");
      Check (Doc, 2, 9, "(none)");
      Check ("", 1, 1, "(none)");
   end Test_Nothing;

   --  A text is handed to the parser with a line feed after it when it
   --  ends with neither a line feed nor a carriage return, and as it is
   --  otherwise.
   procedure Test_Line_Ended (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Line_Ended ("d = 2020-01-01") = "d = 2020-01-01" & LF, "date");
      Assert (Line_Ended ("a = 1" & LF) = "a = 1" & LF, "a line feed ends");
      Assert
        (Line_Ended ("a = 1" & CR & LF) = "a = 1" & CR & LF, "CR LF ends");
      Assert (Line_Ended ("a = 1" & CR) = "a = 1" & CR, "a lone CR stays");
      Assert (Line_Ended ("# x" & Tab) = "# x" & Tab & LF, "a tab is no end");
      Assert (Line_Ended ("") = "", "the empty text stays empty");
   end Test_Line_Ended;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Places'Access, "a number by its place");
      Register_Routine
        (T, Test_Columns'Access, "tabs, UTF-8 and line ends in columns");
      Register_Routine (T, Test_Nothing'Access, "no number at a place");
      Register_Routine
        (T, Test_Line_Ended'Access, "a line end after the text");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Toml_Source (where a number was written)");
   end Name;

end Tabula_Toml_Source_Tests;
