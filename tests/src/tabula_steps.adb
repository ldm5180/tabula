with Fabula.Check.Ints;
with Fabula.Numbers;

with Tabula_Steps.Configs;
with Tabula_Steps.Csv_Files;
with Tabula_Steps.Emits;
with Tabula_Steps.Knobs;
with Tabula_Steps.Walks;
with Tabula_World;

package body Tabula_Steps is

   procedure Then_Take (Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      Ctx.Has_Next := True;
      Ctx.Next := Evt;
   end Then_Take;

   function Count_Read (Ctx : Step_Context; N : Positive := 1) return Boolean
   is (N <= Fabula.Args.Count (Ctx.A)
       and then Fabula.Args.Int (Ctx.A, N).Ok
       and then Fabula.Args.Int (Ctx.A, N).Value >= 0);

   function Count (Ctx : Step_Context; N : Positive := 1) return Natural
   is (Fabula.Args.Int (Ctx.A, N).Value);

   procedure Refuse_Count (Ctx : in out Step_Context; N : Positive := 1) is
      Read : constant Fabula.Numbers.Integer_Reads.Read :=
        Fabula.Args.Int (Ctx.A, N);
   begin
      if Read.Ok then
         Fabula.Check.Fail_Step (Ctx.R, "a count cannot be negative");
      else
         Fabula.Check.Ints.Fail_Read (Ctx.R, Read.Error);
      end if;
   end Refuse_Count;

   ---------------------------------------------------------------------
   --  The regions: every step is offered to each, and each takes only
   --  its own.
   ---------------------------------------------------------------------

   type Offer_Access is
     access procedure
       (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);
   type Reset_Access is access procedure;
   type Phase_Access is access function return String;
   type Name_Access is access constant String;

   type Region is record
      Name  : Name_Access;
      Offer : Offer_Access;
      Reset : Reset_Access;
      Phase : Phase_Access;
   end record;

   Config_Name : aliased constant String := "config";
   Knobs_Name  : aliased constant String := "knobs";
   Walks_Name  : aliased constant String := "walks";
   Emits_Name  : aliased constant String := "emits";
   Csv_Name    : aliased constant String := "csv";

   --!format off
   Regions : constant array (Positive range <>) of Region :=
     [(Config_Name'Access,  Configs.Offer'Access,    Configs.Reset'Access,    Configs.Phase'Access),
      (Knobs_Name'Access,   Knobs.Offer'Access,      Knobs.Reset'Access,      Knobs.Phase'Access),
      (Walks_Name'Access,   Walks.Offer'Access,      Walks.Reset'Access,      Walks.Phase'Access),
      (Emits_Name'Access,   Emits.Offer'Access,      Emits.Reset'Access,      Emits.Phase'Access),
      (Csv_Name'Access,     Csv_Files.Offer'Access,  Csv_Files.Reset'Access,  Csv_Files.Phase'Access)];
   --!format on

   --  Every region's state, for the step no region would take.
   function Phases return String is
      Text : Unbounded_String;
   begin
      for G of Regions loop
         Append (Text, " " & G.Name.all & "=" & G.Phase.all);
      end loop;
      return To_String (Text);
   end Phases;

   procedure Execute
     (S    : Step_Kind;
      Ctx  : in out World;
      A    : Fabula.Args.List;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome)
   is
      Step    : Step_Context :=
        (W => Ctx, A => A, Info => Info, R => R, others => <>);
      Taken   : Boolean := False;
      Handled : Boolean;
   begin
      for G of Regions loop
         G.Offer (Step, S, Handled);
         Taken := Taken or else Handled;
      end loop;
      Ctx := Step.W;
      R := Step.R;
      if not Taken then
         Fabula.Check.Fail_Step
           (R,
            S'Image & " is not a step this scenario can take now:" & Phases);
      end if;
   end Execute;

   procedure Run_Hook
     (H    : Hook_Kind;
      Ctx  : in out World;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome)
   is
      pragma Unreferenced (H, Info, R);
   begin
      Ctx := (others => <>);
      for G of Regions loop
         G.Reset.all;
      end loop;
      Tabula_World.Reset;
      Tabula_World.Clear_Scratch (Tabula_World.Saved_Name);
   end Run_Hook;

end Tabula_Steps;
