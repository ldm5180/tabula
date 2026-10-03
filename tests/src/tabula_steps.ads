with Ada.Strings.Unbounded;

with Tabula.Config;

with Fabula.Args;
with Fabula.Check;
with Fabula.Frames;
with Fabula.Registry;

--  The step registry the feature runner dispatches on: one Step_Kind
--  per pattern, one table that reads like the features, and one Execute
--  that offers each step to every region's state machine.

package Tabula_Steps is

   use Ada.Strings.Unbounded;

   --  The steps, grouped by the region that takes them.  Each is an
   --  event of that region's state machine, in its own child package.
   type Step_Kind is
     (E_Parse_Doc,
      E_Take_Section,
      E_Check_Silent,
      E_Check_Warned,
      E_Read_Bool,
      E_Read_Count,
      E_Read_Count_Min,
      E_Read_String,
      E_Read_Required,
      E_Read_Real,
      E_Ask_Has,
      E_Check_Reading,
      E_Check_Text,
      E_Check_Default,
      E_Check_Present,
      E_Check_Absent,
      E_Walk_Strings,
      E_Walk_Sections,
      E_Check_Items);

   --  A scenario starts from a fresh world; the world holds no resource
   --  that would need stopping after it.
   type Hook_Kind is (Fresh_World);

   --  What a getter returned, by the getter's type, or what Has said;
   --  None before a read.
   type Reading_Kind is (None, Bool, Count, Text, Real, Presence);

   type Reading (Kind : Reading_Kind := None) is record
      case Kind is
         when None =>
            null;

         when Bool =>
            Flag : Boolean := False;

         when Count =>
            Number : Natural := 0;

         when Text =>
            Words : Unbounded_String;

         when Real =>
            Value : Long_Float := 0.0;

         when Presence =>
            Present : Boolean := False;
      end case;
   end record;

   --  What one scenario reads back.  fabula copies it per step, so it
   --  holds values only: the table in hand (a reference to the parsed
   --  document) and its label, what was read from it, and the default
   --  the read was given, and what a walk visited.
   type World is record
      Root    : Tabula.Config.Table;
      Label   : Unbounded_String;
      Status  : Tabula.Config.Load_Status := Tabula.Config.Loaded;
      Error   : Unbounded_String;
      Got     : Reading;
      Default : Reading;
      Items   : Unbounded_String;
   end record;

   --  One step as a machine sees it: the scenario, the step's arguments,
   --  frame and outcome, and the event an action asks to be taken next
   --  (Then_Take), which the runner posts before the step returns.
   type Step_Context is record
      W        : World;
      A        : Fabula.Args.List;
      Info     : Fabula.Frames.Frame;
      R        : Fabula.Check.Outcome;
      Has_Next : Boolean := False;
      Next     : Step_Kind := Step_Kind'First;
   end record;

   procedure Then_Take (Ctx : in out Step_Context; Evt : Step_Kind);

   --  Whether capture N reads as a whole number of zero or more: the
   --  guard every counting step's rows share.
   function Count_Read (Ctx : Step_Context; N : Positive := 1) return Boolean;

   --  Capture N, which Count_Read said reads.
   function Count (Ctx : Step_Context; N : Positive := 1) return Natural
   with Pre => Count_Read (Ctx, N);

   --  Fail the step for capture N: why it does not read as a count.
   procedure Refuse_Count (Ctx : in out Step_Context; N : Positive := 1);

   package Steps is new
     Fabula.Registry
       (Step_Kind => Step_Kind,
        Hook_Kind => Hook_Kind,
        Context   => World);
   use Steps;

   --!format off
   Step_Defs : constant Steps.Step_Table :=
     [Step ("a config labelled {string}:")                      >= E_Parse_Doc,
      Step ("the section {word}")                               >= E_Take_Section,
      Step ("nothing was warned")                               >= E_Check_Silent,
      Step ("{word} was complained about")                      >= E_Check_Warned,
      Step ("the boolean {word} is read with default {word}")   >= E_Read_Bool,
      Step ("the count {word} is read with default {int} and at least {int}")
                                                                >= E_Read_Count_Min,
      Step ("the count {word} is read with default {int}")      >= E_Read_Count,
      Step ("the string {word} is read with default {string}")  >= E_Read_String,
      Step ("the non-empty string {word} is read with default {string}")
                                                                >= E_Read_Required,
      Step ("the real {word} is read with default {word}")      >= E_Read_Real,
      Step ("{word} is asked for")                              >= E_Ask_Has,
      Step ("the reading is the default")                       >= E_Check_Default,
      Step ("the reading is the text {string}")                 >= E_Check_Text,
      Step ("the reading is {word}")                            >= E_Check_Reading,
      Step ("it is present")                                    >= E_Check_Present,
      Step ("it is absent")                                     >= E_Check_Absent,
      Step ("the strings of {word} are walked")                 >= E_Walk_Strings,
      Step ("the sections of {word} are walked")                >= E_Walk_Sections,
      Step ("the items were {string}")                          >= E_Check_Items];
   --!format on

   Hook_Defs : constant Steps.Hook_Table := [Before >= Fresh_World];

   procedure Execute
     (S    : Step_Kind;
      Ctx  : in out World;
      A    : Fabula.Args.List;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

   procedure Run_Hook
     (H    : Hook_Kind;
      Ctx  : in out World;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

end Tabula_Steps;
