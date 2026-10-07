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
      Assert (Result.Status = Loaded, "the sample parses");
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

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Scalars'Access, "values in file order");
      Register_Routine (T, Test_Nesting'Access, "tables and lists in turn");
      Register_Routine (T, Test_Nothing'Access, "nothing to walk");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Config.Values (every value, walked)");
   end Name;

end Tabula_Config_Values_Tests;
