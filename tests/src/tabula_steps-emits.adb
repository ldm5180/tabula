with Ada.Directories;

with Tabula.Text_Lists;
with Tabula.Toml_Text;

with Tabula_Steps.Flows;
with Tabula_World;

package body Tabula_Steps.Emits is

   use Tabula.Emit;

   --  Unbegun until a document is begun; Writing while keys go into it;
   --  Saving while what came of the save is settled; Saved or Unsaved
   --  after.
   type State is (Unbegun, Writing, Saving, Saved, Unsaved);

   type Guard_Kind is
     (Always, Count_Given, Flag_Given, Date_Given, Time_Given, Was_Saved);

   type Action_Kind is
     (A_Nothing,
      --  Writing.
      A_Begin,
      A_Comment,
      A_Table,
      A_Array_Table,
      A_Text,
      A_Count,
      A_Number,
      A_Flag,
      A_Strings,
      A_Date,
      A_Time,
      A_Save,
      --  Refusing a step written wrong.
      A_Refuse_Count,
      A_Refuse_Flag,
      A_Refuse_Date,
      A_Refuse_Time,
      --  Checking.
      A_Check_Saved,
      A_Check_Unsaved,
      A_Fail_Unsaved,
      A_Fail_Saved,
      A_Check_Refused);

   subtype Write_Action is Action_Kind range A_Begin .. A_Save;
   subtype Refuse_Action is Action_Kind range A_Refuse_Count .. A_Refuse_Time;
   subtype Check_Action is Action_Kind range A_Check_Saved .. A_Check_Refused;

   --  Where each value sits among a step's captures.
   Key_Capture   : constant := 1;
   Value_Capture : constant := 2;
   Only_Capture  : constant := 1;

   --  What separates the strings of a list a step writes.
   List_Separator : constant Character := ',';

   function Key (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, Key_Capture));

   function Value (Ctx : Step_Context) return String
   is (Fabula.Args.Text (Ctx.A, Value_Capture));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when Count_Given => Count_Read (Ctx, Value_Capture),
           when Flag_Given  => Value (Ctx) in "true" | "false",
           when Date_Given  => Tabula.Toml_Text.Date_Of (Value (Ctx)).Ok,
           when Time_Given  => Tabula.Toml_Text.Time_Of (Value (Ctx)).Ok,
           when Was_Saved   => Ctx.W.Saved);
   end Evaluate;

   ---------------------------------------------------------------------
   --  Writing.
   ---------------------------------------------------------------------

   --  The strings of Text between separators; none for "".
   function Split (Text : String) return Tabula.Text_Lists.Vector is
      Items : Tabula.Text_Lists.Vector;
      First : Positive := Text'First;
   begin
      if Text = "" then
         return Items;
      end if;
      for I in Text'Range loop
         if Text (I) = List_Separator then
            Items.Append (Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;
      Items.Append (Text (First .. Text'Last));
      return Items;
   end Split;

   --  Save the document, then settle where that left it.
   procedure Save_And_Settle (Ctx : in out Step_Context) is
   begin
      Save (Ctx.W.Doc, Tabula_World.Saved_Document, Ctx.W.Saved);
      Then_Take (Ctx, E_Given);
   end Save_And_Settle;

   --  A document with nothing written, as a scenario begins one.
   Blank : Document;

   procedure Write_Value (A : Write_Action; Ctx : in out Step_Context)
   with Pre => A in A_Text .. A_Time
   is
      Doc : Document renames Ctx.W.Doc;
   begin
      case A is
         when A_Text    =>
            Text (Doc, Key (Ctx), Value (Ctx));

         when A_Count   =>
            Count (Doc, Key (Ctx), Count (Ctx, Value_Capture));

         when A_Number  =>
            Number (Doc, Key (Ctx), Value (Ctx));

         when A_Flag    =>
            Flag (Doc, Key (Ctx), Value (Ctx) = "true");

         when A_Strings =>
            Strings (Doc, Key (Ctx), Split (Value (Ctx)));

         when A_Date    =>
            Date
              (Doc, Key (Ctx), Tabula.Toml_Text.Date_Of (Value (Ctx)).Value);

         when others    =>
            Time
              (Doc, Key (Ctx), Tabula.Toml_Text.Time_Of (Value (Ctx)).Value);
      end case;
   end Write_Value;

   procedure Execute_Write (A : Write_Action; Ctx : in out Step_Context) is
      Name : constant String := Fabula.Args.Text (Ctx.A, Only_Capture);
   begin
      case A is
         when A_Begin          =>
            Ctx.W.Doc := Blank;

         when A_Comment        =>
            Comment (Ctx.W.Doc, Name);

         when A_Table          =>
            Begin_Table (Ctx.W.Doc, Name);

         when A_Array_Table    =>
            Begin_Array_Table (Ctx.W.Doc, Name);

         when A_Save           =>
            Save_And_Settle (Ctx);

         when A_Text .. A_Time =>
            Write_Value (A, Ctx);
      end case;
   end Execute_Write;

   procedure Execute_Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Count =>
            Refuse_Count (Ctx, Value_Capture);

         when A_Refuse_Flag  =>
            Fabula.Check.Fail_Step (Ctx.R, "a flag is true or false");

         when A_Refuse_Date  =>
            Fabula.Check.Fail_Step
              (Ctx.R, Value (Ctx) & " is not a date, YYYY-MM-DD");

         when A_Refuse_Time  =>
            Fabula.Check.Fail_Step
              (Ctx.R, Value (Ctx) & " is not a time, HH:MM:SS");
      end case;
   end Execute_Refuse;

   ---------------------------------------------------------------------
   --  Checking.
   ---------------------------------------------------------------------

   --  Whether Doc's refusal begins with Key, as a refusal names it.
   function Refused (Doc : Document; Key : String) return Boolean
   is (Tabula_World.Begins_With (Refusal (Doc), Key & ":"));

   procedure Execute_Check (A : Check_Action; Ctx : in out Step_Context) is
      Why : constant String := Refusal (Ctx.W.Doc);
   begin
      case A is
         when A_Check_Saved   =>
            Fabula.Check.Is_True
              (Ctx.R,
               Ada.Directories.Exists (Tabula_World.Saved_Document),
               "the document saved, but there is no file");

         when A_Check_Unsaved =>
            Fabula.Check.Is_False
              (Ctx.R,
               Ada.Directories.Exists (Tabula_World.Saved_Document),
               "the document did not save, but a file is there");

         when A_Fail_Unsaved  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the document was not saved; it refused: " & Why);

         when A_Fail_Saved    =>
            Fabula.Check.Fail_Step (Ctx.R, "the document was saved");

         when A_Check_Refused =>
            Fabula.Check.Is_True
              (Ctx.R,
               Refused (Ctx.W.Doc, Fabula.Args.Word (Ctx.A, Only_Capture)),
               "the document refused: """ & Why & """");
      end case;
   end Execute_Check;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing     =>
            null;

         when Write_Action  =>
            Execute_Write (A, Ctx);

         when Refuse_Action =>
            Execute_Refuse (A, Ctx);

         when Check_Action  =>
            Execute_Check (A, Ctx);
      end case;
   end Execute;

   ---------------------------------------------------------------------
   --  The table.
   ---------------------------------------------------------------------

   package Flow is new
     Tabula_Steps.Flows
       (State       => State,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   New_Document      : constant Ev := (Kind => E_New_Document);
   Write_Comment     : constant Ev := (Kind => E_Write_Comment);
   Begin_Table       : constant Ev := (Kind => E_Begin_Table);
   Begin_Array_Table : constant Ev := (Kind => E_Begin_Array_Table);
   Write_Text        : constant Ev := (Kind => E_Write_Text);
   Write_Count       : constant Ev := (Kind => E_Write_Count);
   Write_Number      : constant Ev := (Kind => E_Write_Number);
   Write_Flag        : constant Ev := (Kind => E_Write_Flag);
   Write_Strings     : constant Ev := (Kind => E_Write_Strings);
   Write_Date        : constant Ev := (Kind => E_Write_Date);
   Write_Time        : constant Ev := (Kind => E_Write_Time);
   Save_Document     : constant Ev := (Kind => E_Save_Document);
   Given             : constant Ev := (Kind => E_Given);
   Check_Saved       : constant Ev := (Kind => E_Check_Saved);
   Check_Unsaved     : constant Ev := (Kind => E_Check_Unsaved);
   Check_Refused     : constant Ev := (Kind => E_Check_Refused);

   --!format off
   Table : constant Transition_Table :=
     [Unbegun + New_Document                    / A_Begin         >= Writing,

      Writing + Write_Comment                   / A_Comment       >= Writing,
      Writing + Begin_Table                     / A_Table         >= Writing,
      Writing + Begin_Array_Table               / A_Array_Table   >= Writing,
      Writing + Write_Text                      / A_Text          >= Writing,
      Writing + Write_Count       (Count_Given) / A_Count         >= Writing,
      Writing + Write_Count                     / A_Refuse_Count  >= Writing,
      Writing + Write_Number                    / A_Number        >= Writing,
      Writing + Write_Flag        (Flag_Given)  / A_Flag          >= Writing,
      Writing + Write_Flag                      / A_Refuse_Flag   >= Writing,
      Writing + Write_Strings                   / A_Strings       >= Writing,
      Writing + Write_Date        (Date_Given)  / A_Date          >= Writing,
      Writing + Write_Date                      / A_Refuse_Date   >= Writing,
      Writing + Write_Time        (Time_Given)  / A_Time          >= Writing,
      Writing + Write_Time                      / A_Refuse_Time   >= Writing,
      Writing + Check_Refused                   / A_Check_Refused >= Writing,
      Writing + Save_Document                   / A_Save          >= Saving,

      Saving  + Given             (Was_Saved)   / A_Nothing       >= Saved,
      Saving  + Given                           / A_Nothing       >= Unsaved,

      Saved   + Check_Saved                     / A_Check_Saved   >= Saved,
      Saved   + Check_Unsaved                   / A_Fail_Saved    >= Saved,
      Saved   + Check_Refused                   / A_Check_Refused >= Saved,
      Unsaved + Check_Unsaved                   / A_Check_Unsaved >= Unsaved,
      Unsaved + Check_Saved                     / A_Fail_Unsaved  >= Unsaved,
      Unsaved + Check_Refused                   / A_Check_Refused >= Unsaved];
   --!format on

   Current : State := Unbegun;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unbegun;
   end Reset;

   function Phase return String
   is (Current'Image);

end Tabula_Steps.Emits;
