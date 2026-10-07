with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Csv; use Tabula.Csv;
with Tabula.Csv_Scan;
with Tabula.Text_Lists;

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

   --  Row as it is noted: "line:" and then name=value pairs read by
   --  name, ending in a semicolon.
   function Noted (Row : Tabula.Csv.Row) return String is
      Text : Unbounded_String :=
        To_Unbounded_String (Trimmed (Line (Row)'Image) & ":");
   begin
      for I in 1 .. Field_Count (Row) loop
         Append (Text, Column (Row, I) & "=" & Field (Row, Column (Row, I)));
         Append (Text, (if I < Field_Count (Row) then "," else ";"));
      end loop;
      return To_String (Text);
   end Noted;

   --  Every row seen, each noted.
   Seen : Unbounded_String;

   procedure Note (Row : Tabula.Csv.Row) is
   begin
      Append (Seen, Noted (Row));
   end Note;

   --  A row visitor a test owns: every row it was handed, each noted.
   type Noter is limited new Row_Visitor with record
      Seen : Unbounded_String;
   end record;

   overriding
   procedure Visit_Row (V : in out Noter; Row : Tabula.Csv.Row);

   overriding
   procedure Visit_Row (V : in out Noter; Row : Tabula.Csv.Row) is
   begin
      Append (V.Seen, Noted (Row));
   end Visit_Row;

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

   Written_Name : constant String := "written.csv";

   --  Write a header and one row to Path; Ok as Close says.
   procedure Write_Two
     (Path   : String;
      Header : Tabula.Text_Lists.Vector;
      Fields : Tabula.Text_Lists.Vector;
      Ok     : out Boolean)
   is
      W : Writer;
   begin
      Open (W, Path, Header);
      Put (W, Fields);
      Close (W, Ok);
   end Write_Two;

   --  A writer opened on Path and let go of without Close.
   procedure Leave_Open (Path : String) is
      W : Writer;
   begin
      Open (W, Path, ["x"]);
      Put (W, ["one"]);
   end Leave_Open;

   --  A file written with every kind of field reads back the same, and
   --  holds exactly the text the dialect gives it.
   procedure Test_Write (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Scratch (Written_Name);
      W    : Writer;
      Ok   : Boolean;
      R    : Outcome;
   begin
      Clear_Scratch (Written_Name);
      Open (W, Path, ["name", "note"]);
      Put (W, ["plain", "x"]);
      Put (W, ["comma", "a, b"]);
      Put (W, ["quote", "say ""hi"""]);
      Put (W, ["break", "one" & LF & "two"]);
      Put (W, ["empty", ""]);
      Assert (not Failed (W), "nothing refused");
      Assert (Contents (Path) = "", "nothing lands before Close");
      Close (W, Ok);
      Assert (Ok, "the file is written");
      Assert
        (Contents (Path)
         = "name,note"
           & LF
           & "plain,x"
           & LF
           & "comma,""a, b"""
           & LF
           & "quote,""say """"hi"""""""
           & LF
           & "break,""one"
           & LF
           & "two"""
           & LF
           & "empty,"
           & LF,
         "as the dialect writes it:" & LF & Contents (Path));

      Seen := Null_Unbounded_String;
      Each_Row (Path, Note'Access, R);
      Assert (R = (Read, 0), "and it reads back");
      Assert
        (Seen_Text
         = "2:name=plain,note=x;3:name=comma,note=a, b;"
           & "4:name=quote,note=say ""hi"";"
           & "5:name=break,note=one"
           & LF
           & "two;7:name=empty,note=;",
         "the same: " & Seen_Text);
   end Test_Write;

   --  Every refusal leaves the old file and no new one: a row unlike the
   --  header, a header of no columns, a record the reader could not
   --  read back, a path in no directory, and a writer never closed.
   procedure Test_Write_Refusals (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := Scratch (Written_Name);
      Long : constant String (1 .. Tabula.Csv_Scan.Max_Record_Length) :=
        [others => 'x'];
      Ok   : Boolean;
   begin
      Clear_Scratch (Written_Name);
      Write_File (Path, "old");
      Write_Two (Path, ["x", "y"], ["one"], Ok);
      Assert (not Ok and then Contents (Path) = "old", "a ragged row");
      Write_Two (Path, [], [], Ok);
      Assert (not Ok and then Contents (Path) = "old", "no columns");
      Write_Two (Path, ["x"], [Long & "y"], Ok);
      Assert (not Ok and then Contents (Path) = "old", "a record too long");
      Write_Two (Path, ["x"], [Long], Ok);
      Assert (Ok, "one as long as may be read is written");
      Write_File (Path, "old");
      Write_Two
        (Ada.Directories.Containing_Directory (Path) & "/no-such-dir/x.csv",
         ["x"],
         ["one"],
         Ok);
      Assert (not Ok, "a path in no directory");
      Leave_Open (Path);
      Assert (Contents (Path) = "old", "a writer never closed writes nothing");
   end Test_Write_Refusals;

   --  Text as the scratch file, its rows handed to a fresh visitor;
   --  what came of it, and what the visitor noted.
   procedure Visit
     (Text : String; Result : out Outcome; Seen : out Unbounded_String)
   is
      Rows : Noter;
   begin
      Clear_Scratch (File_Name);
      Write_File (Scratch (File_Name), Text);
      Each_Row (Scratch (File_Name), Rows, Result);
      Seen := Rows.Seen;
   end Visit;

   --  The rows of a file handed to a visitor the test owns, as they are
   --  to a procedure: in order with their lines, up to a refusal, which
   --  is the outcome; a missing file hands over nothing.
   procedure Test_Row_Visitor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R    : Outcome;
      Seen : Unbounded_String;
      None : Noter;
   begin
      Visit ("a,b" & LF & "1,2" & LF & "3,4" & LF, R, Seen);
      Assert (R = (Read, 0), "a file reads: " & R.Status'Image);
      Assert
        (To_String (Seen) = "2:a=1,b=2;3:a=3,b=4;",
         "each row to the visitor: " & To_String (Seen));
      Visit ("a,b" & LF & "1,2" & LF & "3" & LF & "4,5", R, Seen);
      Assert (R = (Ragged, 3), "ragged at its line:" & R.Line'Image);
      Assert (To_String (Seen) = "2:a=1,b=2;", "the rows before it");
      Clear_Scratch (File_Name);
      Each_Row (Scratch (File_Name), None, R);
      Assert (R = (Missing, 0), "no file is missing");
      Assert (Length (None.Seen) = 0, "and hands over nothing");
   end Test_Row_Visitor;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_By_Name'Access, "rows by the header's names");
      Register_Routine (T, Test_Row'Access, "a row's fields every way");
      Register_Routine (T, Test_Outcomes'Access, "outcomes, with lines");
      Register_Routine (T, Test_Blocks'Access, "a file of many blocks");
      Register_Routine (T, Test_Write'Access, "a file written reads back");
      Register_Routine
        (T, Test_Write_Refusals'Access, "what a writer refuses");
      Register_Routine (T, Test_Row_Visitor'Access, "rows to a visitor");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Csv (a file read by rows)");
   end Name;

end Tabula_Csv_Tests;
