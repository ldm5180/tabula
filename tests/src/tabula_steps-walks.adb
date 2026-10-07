with Tabula_Steps.Configs;
with Tabula_Steps.Flows;
with Tabula_World;

package body Tabula_Steps.Walks is

   --  Unwalked until an array is walked; Walked once its items are in
   --  hand.  A walk in Walked starts again from Unwalked.
   type State is (Unwalked, Walked);

   type Guard_Kind is (Always, No_Table, Scale_Given);

   type Action_Kind is
     (A_Nothing,
      A_Walk_Strings,
      A_Walk_Scaled,
      A_Walk_Sections,
      A_Walk_Keys,
      A_Visit_Strings,
      A_Visit_Scaled,
      A_Visit_Sections,
      A_Visit_Keys,
      A_Again,
      A_Refuse_No_Table,
      A_Refuse_Scale,
      A_Check_Items);

   subtype Walk_Action is Action_Kind range A_Walk_Strings .. A_Walk_Keys;
   subtype Visit_Action is Action_Kind range A_Visit_Strings .. A_Visit_Keys;

   Key_Capture   : constant := 1;
   Scale_Capture : constant := 2;
   Want_Capture  : constant := 1;

   function Key (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, Key_Capture));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when No_Table    => not Configs.Holds_Table,
           when Scale_Given =>
             Count_Read (Ctx, Scale_Capture)
             and then Count (Ctx, Scale_Capture) > 0);
   end Evaluate;

   --  The walks to a procedure, each into a Gatherer as the walks to a
   --  visitor gather, so a scenario's items read the same either way.

   procedure Collect_Strings (Ctx : in out Step_Context) is
      G : Tabula_World.Gatherer;
      procedure Visit (Item : String) is
      begin
         G.Visit_String (Item);
      end Visit;
   begin
      Tabula.Config.Each_String (Ctx.W.Root, Key (Ctx), Visit'Access);
      Ctx.W.Items := To_Unbounded_String (Tabula_World.Items (G));
   end Collect_Strings;

   procedure Collect_Scaled (Ctx : in out Step_Context)
   with Pre => Count_Read (Ctx, Scale_Capture)
   is
      G : Tabula_World.Gatherer;
      procedure Visit (Item : Long_Long_Integer) is
      begin
         G.Visit_Scaled (Item);
      end Visit;
   begin
      Tabula.Config.Each_Scaled
        (Ctx.W.Root, Key (Ctx), Count (Ctx, Scale_Capture), Visit'Access);
      Ctx.W.Items := To_Unbounded_String (Tabula_World.Items (G));
   end Collect_Scaled;

   procedure Collect_Sections (Ctx : in out Step_Context) is
      G : Tabula_World.Gatherer;
      procedure Visit (Item : Tabula.Config.Table) is
      begin
         G.Visit_Section (Item);
      end Visit;
   begin
      Tabula.Config.Each_Section (Ctx.W.Root, Key (Ctx), Visit'Access);
      Ctx.W.Items := To_Unbounded_String (Tabula_World.Items (G));
   end Collect_Sections;

   procedure Collect_Keys (Ctx : in out Step_Context) is
      G : Tabula_World.Gatherer;
      procedure Visit (Key : String) is
      begin
         G.Visit_Key (Key);
      end Visit;
   begin
      Tabula.Config.Each_Key (Ctx.W.Root, Visit'Access);
      Ctx.W.Items := To_Unbounded_String (Tabula_World.Items (G));
   end Collect_Keys;

   procedure Execute_Walk (A : Walk_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Walk_Strings  =>
            Collect_Strings (Ctx);

         when A_Walk_Scaled   =>
            Collect_Scaled (Ctx);

         when A_Walk_Sections =>
            Collect_Sections (Ctx);

         when A_Walk_Keys     =>
            Collect_Keys (Ctx);
      end case;
   end Execute_Walk;

   --  The walk the action names, handing its items to a visitor of the
   --  scenario's own, whose items are then the world's.
   procedure Gather (A : Visit_Action; Ctx : in out Step_Context) is
      G : Tabula_World.Gatherer;
   begin
      case A is
         when A_Visit_Strings  =>
            Tabula.Config.Each_String (Ctx.W.Root, Key (Ctx), G);

         when A_Visit_Scaled   =>
            Tabula.Config.Each_Scaled
              (Ctx.W.Root, Key (Ctx), Count (Ctx, Scale_Capture), G);

         when A_Visit_Sections =>
            Tabula.Config.Each_Section (Ctx.W.Root, Key (Ctx), G);

         when A_Visit_Keys     =>
            Tabula.Config.Each_Key (Ctx.W.Root, G);
      end case;
      Ctx.W.Items := To_Unbounded_String (Tabula_World.Items (G));
   end Gather;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing         =>
            null;

         when Walk_Action       =>
            Execute_Walk (A, Ctx);

         when Visit_Action      =>
            Gather (A, Ctx);

         when A_Again           =>
            Then_Take (Ctx, Evt);

         when A_Refuse_No_Table =>
            Fabula.Check.Fail_Step (Ctx.R, "no config was given to walk");

         when A_Refuse_Scale    =>
            Fabula.Check.Fail_Step
              (Ctx.R, "a scale is a whole number of one or more");

         when A_Check_Items     =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               To_String (Ctx.W.Items),
               Fabula.Args.Text (Ctx.A, Want_Capture));
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

   Walk_Strings   : constant Ev := (Kind => E_Walk_Strings);
   Walk_Scaled    : constant Ev := (Kind => E_Walk_Scaled);
   Walk_Sections  : constant Ev := (Kind => E_Walk_Sections);
   Walk_Keys      : constant Ev := (Kind => E_Walk_Keys);
   Check_Items    : constant Ev := (Kind => E_Check_Items);
   Visit_Strings  : constant Ev := (Kind => E_Visit_Strings);
   Visit_Scaled   : constant Ev := (Kind => E_Visit_Scaled);
   Visit_Sections : constant Ev := (Kind => E_Visit_Sections);
   Visit_Keys     : constant Ev := (Kind => E_Visit_Keys);

   --!format off
   Table : constant Transition_Table :=
     [Unwalked + Walk_Strings   (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Strings                 / A_Walk_Strings    >= Walked,
      Unwalked + Walk_Scaled    (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Scaled    (Scale_Given) / A_Walk_Scaled     >= Walked,
      Unwalked + Walk_Scaled                  / A_Refuse_Scale    >= Unwalked,
      Unwalked + Walk_Sections  (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Sections                / A_Walk_Sections   >= Walked,
      Unwalked + Walk_Keys      (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Keys                    / A_Walk_Keys       >= Walked,
      Unwalked + Visit_Strings  (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Visit_Strings                / A_Visit_Strings   >= Walked,
      Unwalked + Visit_Scaled   (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Visit_Scaled   (Scale_Given) / A_Visit_Scaled    >= Walked,
      Unwalked + Visit_Scaled                 / A_Refuse_Scale    >= Unwalked,
      Unwalked + Visit_Sections (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Visit_Sections               / A_Visit_Sections  >= Walked,
      Unwalked + Visit_Keys     (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Visit_Keys                   / A_Visit_Keys      >= Walked,
      Walked   + Walk_Strings                 / A_Again           >= Unwalked,
      Walked   + Walk_Scaled                  / A_Again           >= Unwalked,
      Walked   + Walk_Sections                / A_Again           >= Unwalked,
      Walked   + Walk_Keys                    / A_Again           >= Unwalked,
      Walked   + Visit_Strings                / A_Again           >= Unwalked,
      Walked   + Visit_Scaled                 / A_Again           >= Unwalked,
      Walked   + Visit_Sections               / A_Again           >= Unwalked,
      Walked   + Visit_Keys                   / A_Again           >= Unwalked,
      Walked   + Check_Items                  / A_Check_Items     >= Walked];
   --!format on

   Current : State := Unwalked;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unwalked;
   end Reset;

   function Phase return String
   is (Current'Image);

end Tabula_Steps.Walks;
