with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Csv_Scan; use Tabula.Csv_Scan;

--  The scanner one character at a time: the records it hands over, field
--  by field, and every way a text is refused, with the line its record
--  began on.  The absence-of-runtime-error story is the proof's.

package body Tabula_Csv_Scan_Tests is

   use AUnit.Test_Cases.Registration;

   LF : constant Character := ASCII.LF;
   CR : constant Character := ASCII.CR;

   --  What scanning a text came to: its records, each field in brackets
   --  and each record ended by a bar, then the fault and its line.
   type Scan_Result is record
      Records : Unbounded_String;
      Fault   : Fault_Kind := None;
      Line    : Positive := 1;
   end record;

   procedure Take (S : in out Scanner; Into : in out Unbounded_String) is
   begin
      for I in 1 .. Field_Count (S) loop
         Append (Into, "[" & Field (S, I) & "]");
      end loop;
      Append (Into, "|");
      Next (S);
   end Take;

   function Scan (Text : String) return Scan_Result is
      S      : Scanner;
      Result : Scan_Result;
   begin
      for C of Text loop
         Feed (S, C);
         if Ready (S) then
            Take (S, Result.Records);
         end if;
      end loop;
      Finish (S);
      if Ready (S) then
         Take (S, Result.Records);
      end if;
      Result.Fault := Fault (S);
      Result.Line := Line (S);
      return Result;
   end Scan;

   function Records (Text : String) return String
   is (To_String (Scan (Text).Records));

   procedure Test_Doubled_Quote (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (Records ("""a """"b"""" c"",d") = "[a ""b"" c][d]|",
         "a doubled quote is one quote: " & Records ("""a """"b"""" c"",d"));
   end Test_Doubled_Quote;

   procedure Test_Records (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Records ("") = "", "nothing is no record");
      Assert (Records ("a,b" & LF & "c,d") = "[a][b]|[c][d]|", "two records");
      Assert
        (Records ("a,b" & LF & "c,d" & LF) = "[a][b]|[c][d]|",
         "a final line feed ends a record and starts none");
      Assert
        (Records ("a,b" & CR & LF & "c" & CR & LF) = "[a][b]|[c]|",
         "a carriage return before a line feed ends one as well");
      Assert (Records ("a,,b") = "[a][][b]|", "an empty field");
      Assert (Records ("a,") = "[a][]|", "an empty last field");
      Assert (Records (",") = "[][]|", "two empty fields");
      Assert (Records (LF & "a") = "[]|[a]|", "a blank line, one empty field");
      Assert (Records ("""""") = "[]|", "an empty quoted field");
      Assert
        (Records ("""a,b"",""c" & LF & "d""" & LF & "e")
         = "[a,b][c" & LF & "d]|[e]|",
         "a quoted comma and line break are the field's");
      Assert
        (Records ("""a" & CR & LF & "b""") = "[a" & CR & LF & "b]|",
         "a quoted carriage return too");
      Assert (Records ("a b ,c") = "[a b ][c]|", "blanks are the field's");
      Assert
        (Records ("caf" & Character'Val (16#C3#) & Character'Val (16#A9#))
         = "[caf" & Character'Val (16#C3#) & Character'Val (16#A9#) & "]|",
         "bytes pass as they came");
   end Test_Records;

   --  Text is refused for Fault, at the line its record began on.
   procedure Expect_Refused
     (Text : String; Want : Fault_Kind; At_Line : Positive; Why : String)
   is
      R : constant Scan_Result := Scan (Text);
   begin
      Assert
        (R.Fault = Want and then R.Line = At_Line,
         Why
         & ": "
         & R.Fault'Image
         & " at line"
         & R.Line'Image
         & " after "
         & To_String (R.Records));
   end Expect_Refused;

   procedure Test_Refusals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Expect_Refused
        ("a" & LF & "b""c", Stray_Quote, 2, "a quote inside a bare field");
      Expect_Refused ("""a""b", Stray_Quote, 1, "text after a closing quote");
      Expect_Refused
        ("a" & LF & """b" & LF & "c", Unclosed_Quote, 2, "an unclosed quote");
      Expect_Refused
        ("a" & CR & "b", Bare_Carriage_Return, 1, "a carriage return alone");
      Expect_Refused ("a" & CR, Bare_Carriage_Return, 1, "even at the end");
      Expect_Refused
        ("""a""" & CR & "b", Bare_Carriage_Return, 1, "after a quoted one");
      Assert (Scan ("a" & LF & "b").Fault = None, "a clean text has none");
   end Test_Refusals;

   procedure Test_Lines (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Expect_Refused
        ("""x" & LF & "y""" & LF & "z""",
         Stray_Quote,
         3,
         "a quoted line break counts as a line");
   end Test_Lines;

   procedure Test_Bounds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Wide : constant String (1 .. Max_Fields) := [others => ','];
      Long : constant String (1 .. Max_Record_Length) := [others => 'x'];
   begin
      Expect_Refused (Wide, Too_Many_Fields, 1, "one field too many");
      Assert
        (Scan (Wide (2 .. Wide'Last)).Fault = None, "as many as there may be");
      Expect_Refused (Long & "y", Too_Long, 1, "one character too many");
      Expect_Refused ("""" & Long & "y""", Too_Long, 1, "quoted or not");
      Assert (Scan (Long).Fault = None, "as long as a record may be");
   end Test_Bounds;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Doubled_Quote'Access, "a doubled quote is one quote");
      Register_Routine (T, Test_Records'Access, "records and their fields");
      Register_Routine (T, Test_Refusals'Access, "what a text is refused for");
      Register_Routine (T, Test_Lines'Access, "the line a refusal names");
      Register_Routine (T, Test_Bounds'Access, "a record's bounds");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Csv_Scan (one record at a time)");
   end Name;

end Tabula_Csv_Scan_Tests;
