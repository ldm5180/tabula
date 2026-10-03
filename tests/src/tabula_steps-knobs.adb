with Fabula.Check.Ints;

with Tabula_Steps.Configs;
with Tabula_Steps.Flows;

package body Tabula_Steps.Knobs is

   --  Unread until a knob is read; Read once a reading is in hand.
   type State is (Unread, Read);

   type Guard_Kind is (Always, No_Table, Count_Default, Count_Kept);

   type Action_Kind is
     (A_Nothing,
      A_Read_Count,
      A_Refuse_No_Table,
      A_Refuse_Default,
      A_Check_Count,
      A_Refuse_Reading);

   Key_Capture     : constant := 1;
   Default_Capture : constant := 2;
   Want_Capture    : constant := 1;

   function Key (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, Key_Capture));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always        => True,
           when No_Table      => not Configs.Holds_Table,
           when Count_Default => Count_Read (Ctx, Default_Capture),
           when Count_Kept    => Ctx.W.Got.Kind = Count);
   end Evaluate;

   procedure Get_Count (Ctx : in out Step_Context)
   with Pre => Count_Read (Ctx, Default_Capture)
   is
   begin
      Ctx.W.Got :=
        (Kind   => Count,
         Number =>
           Tabula.Config.Get
             (Ctx.W.Root,
              Key (Ctx),
              Fallback => Count (Ctx, Default_Capture)));
   end Get_Count;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing         =>
            null;

         when A_Read_Count      =>
            Get_Count (Ctx);

         when A_Refuse_No_Table =>
            Fabula.Check.Fail_Step (Ctx.R, "no config was given to read from");

         when A_Refuse_Default  =>
            Refuse_Count (Ctx, Default_Capture);

         when A_Check_Count     =>
            Fabula.Check.Ints.Equal
              (Ctx.R, Ctx.W.Got.Number, Fabula.Args.Int (Ctx.A, Want_Capture));

         when A_Refuse_Reading  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the reading is a " & Ctx.W.Got.Kind'Image);
      end case;
   end Execute;

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

   Read_Count    : constant Ev := (Kind => E_Read_Count);
   Check_Reading : constant Ev := (Kind => E_Check_Reading);

   --!format off
   Table : constant Transition_Table :=
     [Unread + Read_Count (No_Table)      / A_Refuse_No_Table >= Unread,
      Unread + Read_Count (Count_Default) / A_Read_Count      >= Read,
      Unread + Read_Count                 / A_Refuse_Default  >= Unread,
      Read   + Read_Count (Count_Default) / A_Read_Count      >= Read,
      Read   + Read_Count                 / A_Refuse_Default  >= Read,
      Read   + Check_Reading   (Count_Kept)    / A_Check_Count     >= Read,
      Read   + Check_Reading                   / A_Refuse_Reading  >= Read];
   --!format on

   Current : State := Unread;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unread;
   end Reset;

   function Phase return String
   is (Current'Image);

end Tabula_Steps.Knobs;
