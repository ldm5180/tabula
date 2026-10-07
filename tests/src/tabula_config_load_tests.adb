with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with GNAT.OS_Lib;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Config; use Tabula.Config;
with Tabula.Config.Values;

with Tabula_World; use Tabula_World;

--  What Load and Parse come to, in both forms: a document read from a
--  string and the same document read from a file.

package body Tabula_Config_Load_Tests is

   use AUnit.Test_Cases.Registration;

   LF : constant Character := ASCII.LF;
   CR : constant Character := ASCII.CR;

   --  The four ways a document is read: parsed or loaded from a file,
   --  complaining to a warner or to a listener.
   type Way is (Parse_Warned, Parse_Heard, Load_Warned, Load_Heard);

   --  The file a document is loaded from.
   Doc_File : constant String := "load-tests.toml";

   --  Doc read the way W, as Root and what came of it.
   procedure Read
     (Doc : String; W : Way; Root : out Table; Result : out Load_Outcome)
   is
      Heard : aliased Recorder;
      Path  : constant String := Scratch (Doc_File);
   begin
      Write_File (Path, Doc);
      case W is
         when Parse_Warned =>
            Parse (Doc, "load test", null, Root, Result.Status, Result.Error);

         when Parse_Heard  =>
            Parse (Doc, "load test", Heard'Access, Root, Result);

         when Load_Warned  =>
            Load (Path, "load test", null, Root, Result.Status, Result.Error);

         when Load_Heard   =>
            Load (Path, "load test", Heard'Access, Root, Result);
      end case;
   end Read;

   --  What came of reading Doc the way W: LOADED and its values as the
   --  value walk gathers them, or the status and the message.
   function Outcome (Doc : String; W : Way) return String is
      Root     : Table;
      Result   : Load_Outcome;
      Gathered : Value_Gatherer;
   begin
      Read (Doc, W, Root, Result);
      if Result.Status /= Loaded then
         return Result.Status'Image & " " & To_String (Result.Error);
      end if;
      Tabula.Config.Values.Each_Value (Root, Gathered);
      return "LOADED " & Items (Gathered);
   end Outcome;

   --  Whether reading Doc every way comes to Want, saying which way and
   --  what it came to when not.
   procedure Check (Doc, Want : String) is
   begin
      for W in Way loop
         Assert
           (Outcome (Doc, W) = Want,
            W'Image & ": want " & Want & ", got " & Outcome (Doc, W));
      end loop;
   end Check;

   --  Whether Doc, ended with nothing, a line feed, and CR LF, comes
   --  every way to its one value, Value.
   procedure Check_Endings (Doc, Value : String) is
   begin
      Check (Doc, "LOADED " & Value);
      Check (Doc & LF, "LOADED " & Value);
      Check (Doc & CR & LF, "LOADED " & Value);
   end Check_Endings;

   --  A document that ends with a date, a time or a date-time reads
   --  the same with a line end after it and without one.
   procedure Test_Calendar_Ends (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Check_Endings ("start = 2020-01-01", "start:A_DATE:2020-01-01");
      Check_Endings ("open = 09:30:00", "open:A_TIME:09:30:00");
      Check_Endings
        ("at = 2020-01-01T09:30:00",
         "at:A_LOCAL_DATETIME:2020-01-01T09:30:00");
      Check_Endings
        ("at = 2020-01-01T09:30:00+05:30",
         "at:AN_OFFSET_DATETIME:2020-01-01T09:30:00+05:30");
      Check_Endings
        ("a = 1" & LF & "start = 2020-01-01",
         "a:AN_INTEGER:1,start:A_DATE:2020-01-01");
   end Test_Calendar_Ends;

   --  A carriage return that ends a document, with no line feed after
   --  it, is refused as it always was, a date before it among them.
   procedure Test_Lone_Return (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Check ("a = 1" & CR, "MALFORMED 1:5: invalid stray carriage return");
      Check
        ("start = 2020-01-01" & CR,
         "MALFORMED 1:18: invalid stray carriage return");
   end Test_Lone_Return;

   --  A refusal names the line and the column the parser stopped at,
   --  before its message, every way a document is read.  A document
   --  that ends without a line end is refused as the same document with
   --  one is: where the parser meets the end, the line after its last.
   procedure Test_Refusal_Place (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Broken : constant String := "a = 1" & LF & "b = 2" & LF & "= 3";
   begin
      Check (Broken & LF, "MALFORMED 3:1: invalid syntax");
      Check (Broken, "MALFORMED 3:1: invalid syntax");
      Check ("[run" & LF, "MALFORMED 2:1: invalid syntax");
      Check ("[run", "MALFORMED 2:1: invalid syntax");
      Check ("n = ""x", "MALFORMED 2:1: invalid string");
      Check ("n = ""x" & LF, "MALFORMED 2:1: invalid string");
      Check
        ("not = = toml",
         "MALFORMED 1:6: invalid (or not supported yet) syntax");
   end Test_Refusal_Place;

   --  A file the parser cannot open has no place to name: its refusal
   --  is the parser's message alone, as it always was, both forms.
   procedure Test_Unread_File (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path   : constant String := Scratch ("unreadable.toml");
      Root   : Table;
      Result : Load_Outcome;
      Heard  : aliased Recorder;
   begin
      Write_File (Path, "a = 1" & LF);
      GNAT.OS_Lib.Set_Non_Readable (Path);
      Load (Path, "load test", null, Root, Result.Status, Result.Error);
      Assert
        (Begins_With (To_String (Result.Error), "cannot open " & Path & ": "),
         "the warner's form: " & To_String (Result.Error));
      Load (Path, "load test", Heard'Access, Root, Result);
      GNAT.OS_Lib.Set_Readable (Path);
      Assert
        (Result.Status = Malformed
         and then Begins_With
                    (To_String (Result.Error), "cannot open " & Path & ": "),
         "the listener's form: " & To_String (Result.Error));
   end Test_Unread_File;

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

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Malformed'Access, "malformed input is a result");
      Register_Routine
        (T, Test_Missing_File'Access, "missing file is a distinct status");
      Register_Routine
        (T, Test_Calendar_Ends'Access, "a date or time that ends the text");
      Register_Routine
        (T, Test_Lone_Return'Access, "a lone carriage return at the end");
      Register_Routine
        (T, Test_Refusal_Place'Access, "a refusal names its line and column");
      Register_Routine
        (T, Test_Unread_File'Access, "a file the parser cannot open");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config (loading and parsing)");
   end Name;

end Tabula_Config_Load_Tests;
