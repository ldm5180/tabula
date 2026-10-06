with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Config;
with Tabula.Emit; use Tabula.Emit;

with Tabula_World; use Tabula_World;

--  The text a document comes to, line by line; what it refuses and
--  that the first refusal is the one it names; and that Save writes it
--  whole, or nothing when it refused.

package body Tabula_Emit_Tests is

   use AUnit.Test_Cases.Registration;
   use type Tabula.Config.Load_Status;

   LF : constant Character := ASCII.LF;

   function Line (Text : String) return String
   is (Text & LF);

   procedure Test_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc : Document;
   begin
      Comment (Doc, "written by a test" & LF & "" & LF & "twice");
      Text (Doc, "name", "ada");
      Begin_Table (Doc, "trading");
      Count (Doc, "retries", 12);
      Number (Doc, "bump", "0.0314");
      Flag (Doc, "dry_run", False);
      Flag (Doc, "live", True);
      Strings (Doc, "templates", ["CS_COMMON", "IN_ROTH"]);
      Numbers (Doc, "levels", ["1", "-2.5"]);
      Strings (Doc, "none", []);
      Date (Doc, "start", (2020, 1, 2));
      Time (Doc, "open", (9, 30, 0));
      Begin_Array_Table (Doc, "trades");
      Text (Doc, "a.b", "x""y");
      Begin_Array_Table (Doc, "trades");
      Text (Doc, "a.b", "z");

      Assert
        (Text_Of (Doc)
         = Line ("# written by a test")
           & Line ("#")
           & Line ("# twice")
           & Line ("name = ""ada""")
           & Line ("")
           & Line ("[trading]")
           & Line ("retries = 12")
           & Line ("bump = 0.0314")
           & Line ("dry_run = false")
           & Line ("live = true")
           & Line ("templates = [""CS_COMMON"", ""IN_ROTH""]")
           & Line ("levels = [1, -2.5]")
           & Line ("none = []")
           & Line ("start = 2020-01-02")
           & Line ("open = 09:30:00")
           & Line ("")
           & Line ("[[trades]]")
           & Line ("""a.b"" = ""x\""y""")
           & Line ("")
           & Line ("[[trades]]")
           & Line ("""a.b"" = ""z"""),
         "the document's text:" & LF & Text_Of (Doc));
      Assert (Refusal (Doc) = "", "and nothing refused");
   end Test_Text;

   procedure Test_First_Header (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Doc   : Document;
      Empty : Document;
   begin
      Begin_Table (Doc, "only");
      Assert
        (Text_Of (Doc) = Line ("[only]"),
         "a header that opens the document has no blank line before it");
      Assert (Text_Of (Empty) = "", "an empty document");
   end Test_First_Header;

   --  Doc's first refusal, after Write wrote to a new one.
   function Refusal_After
     (Write : not null access procedure (Doc : in out Document)) return String
   is
      Doc : Document;
   begin
      Write (Doc);
      return Refusal (Doc);
   end Refusal_After;

   procedure Bad_Number (Doc : in out Document) is
   begin
      Number (Doc, "qty", "1e3");
      Number (Doc, "later", "007");
   end Bad_Number;

   procedure Bad_Numbers (Doc : in out Document) is
   begin
      Numbers (Doc, "levels", ["1", "nan"]);
   end Bad_Numbers;

   procedure Root_Key_Twice (Doc : in out Document) is
   begin
      Count (Doc, "n", 1);
      Flag (Doc, "n", True);
   end Root_Key_Twice;

   procedure Table_Key_Twice (Doc : in out Document) is
   begin
      Begin_Table (Doc, "t");
      Count (Doc, "n", 1);
      Begin_Table (Doc, "u");
      Count (Doc, "n", 1);
      Begin_Array_Table (Doc, "v");
      Count (Doc, "n", 1);
      Begin_Array_Table (Doc, "v");
      Count (Doc, "n", 1);
      Count (Doc, "n", 2);
   end Table_Key_Twice;

   procedure Table_Twice (Doc : in out Document) is
   begin
      Begin_Table (Doc, "t");
      Begin_Table (Doc, "t");
   end Table_Twice;

   procedure Table_Over_Key (Doc : in out Document) is
   begin
      Count (Doc, "t", 1);
      Begin_Array_Table (Doc, "t");
   end Table_Over_Key;

   procedure Array_Over_Table (Doc : in out Document) is
   begin
      Begin_Table (Doc, "t");
      Begin_Array_Table (Doc, "t");
   end Array_Over_Table;

   procedure Control_In_Comment (Doc : in out Document) is
   begin
      Comment (Doc, "bell" & ASCII.BEL);
   end Control_In_Comment;

   procedure Test_Refusals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert
        (Refusal_After (Bad_Number'Access) = "qty: 1e3 is not a number",
         "a number's text that is not one, the first refusal kept: "
         & Refusal_After (Bad_Number'Access));
      Assert
        (Refusal_After (Bad_Numbers'Access) = "levels: nan is not a number",
         "an entry of a list of numbers");
      Assert
        (Refusal_After (Root_Key_Twice'Access) = "n: written twice",
         "a key written twice at the root");
      Assert
        (Refusal_After (Table_Key_Twice'Access) = "n: written twice in v",
         "or in one table; the same key in two tables, or in two of an"
         & " array's, is not: "
         & Refusal_After (Table_Key_Twice'Access));
      Assert
        (Refusal_After (Table_Twice'Access) = "t: written twice",
         "a table begun twice");
      Assert
        (Refusal_After (Table_Over_Key'Access) = "t: written twice",
         "a table named as a key at the root is");
      Assert
        (Refusal_After (Array_Over_Table'Access) = "t: written twice",
         "an array of tables named as a table");
      Assert
        (Refusal_After (Control_In_Comment'Access)
         = "a comment holds a control character",
         "a control in a comment");
   end Test_Refusals;

   Saved_Name : constant String := "emitted.toml";

   procedure Test_Save (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path   : constant String := Scratch (Saved_Name);
      Doc    : Document;
      Ok     : Boolean;
      Root   : Tabula.Config.Table;
      Status : Tabula.Config.Load_Status;
      Error  : Unbounded_String;
   begin
      Clear_Scratch (Saved_Name);
      Begin_Table (Doc, "trading");
      Number (Doc, "bump", "0.0314");
      Text (Doc, "name", "a ""quoted"" \ name");
      Save (Doc, Path, Ok);
      Assert (Ok, "a document saves");
      Assert (Contents (Path) = Text_Of (Doc), "as its text");

      Load (Path, "saved", Root, Status, Error);
      Assert
        (Status = Tabula.Config.Loaded, "and loads: " & To_String (Error));
      Root := Tabula.Config.Section (Root, "trading");
      Assert
        (Tabula.Config.Get_Scaled (Root, "bump", 10_000, 0) = 314,
         "a number reads back");
      Assert
        (Tabula.Config.Get (Root, "name", "") = "a ""quoted"" \ name",
         "and a string with what it escaped");
   end Test_Save;

   procedure Test_Save_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path : constant String := Scratch (Saved_Name);
      Good : Document;
      Bad  : Document;
      Ok   : Boolean;
   begin
      Clear_Scratch (Saved_Name);
      Count (Good, "n", 1);
      Save (Good, Path, Ok);
      Assert (Ok, "the old file is saved");
      Number (Bad, "n", "x");
      Save (Bad, Path, Ok);
      Assert (not Ok, "a document that refused does not save");
      Assert (Contents (Path) = "n = 1" & LF, "and the old file stands");

      Save (Good, Scratch ("no-such-dir") & "/x.toml", Ok);
      Assert (not Ok, "nor does one to a path in no directory");
      Assert
        (not Ada.Directories.Exists (Scratch ("no-such-dir")),
         "which it does not make");
   end Test_Save_Refused;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Text'Access, "a document's text");
      Register_Routine (T, Test_First_Header'Access, "a document's start");
      Register_Routine (T, Test_Refusals'Access, "what a document refuses");
      Register_Routine (T, Test_Save'Access, "a document saved reads back");
      Register_Routine
        (T, Test_Save_Refused'Access, "a refused document is not saved");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Emit (a TOML document, written)");
   end Name;

end Tabula_Emit_Tests;
