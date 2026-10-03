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
   type Step_Kind is (E_Parse_Doc, E_Read_Count, E_Check_Reading);

   --  A scenario starts from a fresh world; the world holds no resource
   --  that would need stopping after it.
   type Hook_Kind is (Fresh_World);

   --  What a getter returned, by the getter's type; None before a read.
   type Reading_Kind is (None, Count);

   type Reading (Kind : Reading_Kind := None) is record
      case Kind is
         when None =>
            null;

         when Count =>
            Number : Natural := 0;
      end case;
   end record;

   --  What one scenario reads back.  fabula copies it per step, so it
   --  holds values only: the table in hand (a reference to the parsed
   --  document) and what was read from it.
   type World is record
      Root   : Tabula.Config.Table;
      Status : Tabula.Config.Load_Status := Tabula.Config.Loaded;
      Error  : Unbounded_String;
      Got    : Reading;
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
     [Step ("a config labelled {string}:")                  >= E_Parse_Doc,
      Step ("the count {word} is read with default {int}")  >= E_Read_Count,
      Step ("the reading is {word}")                        >= E_Check_Reading];
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
