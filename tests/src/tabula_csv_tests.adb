with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Csv; use Tabula.Csv;

with Tabula_World; use Tabula_World;

--  A file read by rows: each row's fields by name, by position, and the
--  header's names; the outcomes, each refusal with its line; and a file
--  longer than one block read through.

package body Tabula_Csv_Tests is

   use AUnit.Test_Cases.Registration;

   LF : constant Character := ASCII.LF;
   CR : constant Character := ASCII.CR;

   File_Name : constant String := "read.csv";

   function Trimmed (Image : String) return String
   is (Ada.Strings.Fixed.Trim (Image, Ada.Strings.Left));

   --  Every row seen, each "line:" and then name=value pairs read by
   --  name, ending in a semicolon.
   Seen : Unbounded_String;

   procedure Note (Row : Tabula.Csv.Row) is
   begin
      Append (Seen, Trimmed (Line (Row)'Image) & ":");
      for I in 1 .. Field_Count (Row) loop
         Append (Seen, Column (Row, I) & "=" & Field (Row, Column (Row, I)));
         Append (Seen, (if I < Field_Count (Row) then "," else ";"));
      end loop;
   end Note;

   --  Read Text as a file; what was seen is in Seen.
   function Read (Text : String) return Outcome is
      Result : Outcome;
   begin
      Clear_Scratch (File_Name);
      Write_File (Scratch (File_Name), Text);
      Seen := Null_Unbounded_String;
      Each_Row (Scratch (File_Name), Note'Access, Result);
      return Result;
   end Read;

   function Seen_Text return String
   is (To_String (Seen));

   procedure Test_By_Name (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R : constant Outcome := Read ("a,b" & LF & "1,2" & LF & "3,4" & LF);
   begin
      Assert (R = (Read, 0), "a file reads: " & R.Status'Image);
      Assert
        (Seen_Text = "2:a=1,b=2;3:a=3,b=4;",
         "each row by its header's names, with its line: " & Seen_Text);
   end Test_By_Name;

   --  The first row's fields checked every way a row offers them.
   procedure Check_Row (Row : Tabula.Csv.Row) is
   begin
      Assert (Field_Count (Row) = 3, "three fields");
      Assert (Field (Row, 2) = "y z", "by position");
      Assert (Column (Row, 3) = "a", "the header's name, repeated or not");
      Assert (Has_Column (Row, "a"), "a column the header names");
      Assert (not Has_Column (Row, "d"), "and one it does not");
      Assert (Field (Row, "a") = "x", "the first column so named wins");
      Assert (Line (Row) = 2, "the line the row began on");
   end Check_Row;

   procedure Test_Row (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R : Outcome;
   begin
      Clear_Scratch (File_Name);
      Write_File (Scratch (File_Name), "a,b,a" & CR & LF & "x,y z,w");
      Each_Row (Scratch (File_Name), Check_Row'Access, R);
      Assert (R.Status = Read, "CRLF and no final line end read");
   end Test_Row;

   procedure Test_Outcomes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R : Outcome;
   begin
      Assert (Read ("") = (Read, 0) and then Seen_Text = "", "empty: no rows");
      Assert (Read ("a,b" & LF) = (Read, 0), "a header alone: no rows");
      R := Read ("a,b" & LF & "1,2" & LF & "3" & LF & "4,5");
      Assert (R = (Ragged, 3), "ragged at its line:" & R.Line'Image);
      Assert (Seen_Text = "2:a=1,b=2;", "the rows before it were handed over");
      R := Read ("a" & LF & "1" & LF & """2" & LF & "3");
      Assert (R = (Malformed, 3), "an unclosed quote at its record's line");
      R := Read ("a,b" & LF & "1,x""y");
      Assert (R = (Malformed, 2), "a stray quote at its line");
      R := Read ("a,""b" & LF);
      Assert (R = (Malformed, 1), "a header can be refused too");

      Clear_Scratch (File_Name);
      Each_Row (Scratch (File_Name), Note'Access, R);
      Assert (R = (Missing, 0), "no file is missing");
      Each_Row
        (Ada.Directories.Containing_Directory (Scratch (File_Name)),
         Note'Access,
         R);
      Assert (R = (Malformed, 0), "a directory cannot be read: line 0");
   end Test_Outcomes;

   --  Rows enough to cross many blocks, one quoted field in each.
   function Many_Rows (Count : Positive) return String is
      Text : Unbounded_String := To_Unbounded_String ("n,text" & LF);
   begin
      for I in 1 .. Count loop
         Append (Text, Trimmed (I'Image) & ",""a,""""b""""" & LF & "c""" & LF);
      end loop;
      return To_String (Text);
   end Many_Rows;

   Rows_Counted : Natural := 0;

   procedure Count_Row (Row : Tabula.Csv.Row) is
   begin
      if Field (Row, "text") = "a,""b""" & LF & "c" then
         Rows_Counted := Rows_Counted + 1;
      end if;
   end Count_Row;

   procedure Test_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Rows : constant := 20_000;
      R    : Outcome;
   begin
      Clear_Scratch (File_Name);
      Write_File (Scratch (File_Name), Many_Rows (Rows));
      Rows_Counted := 0;
      Each_Row (Scratch (File_Name), Count_Row'Access, R);
      Assert (R.Status = Read, "a long file reads");
      Assert
        (Rows_Counted = Rows,
         "every row whole across the blocks:" & Rows_Counted'Image);
   end Test_Blocks;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_By_Name'Access, "rows by the header's names");
      Register_Routine (T, Test_Row'Access, "a row's fields every way");
      Register_Routine (T, Test_Outcomes'Access, "outcomes, with lines");
      Register_Routine (T, Test_Blocks'Access, "a file of many blocks");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Csv (a file read by rows)");
   end Name;

end Tabula_Csv_Tests;
