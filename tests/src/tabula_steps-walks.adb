with Tabula_Steps.Configs;
with Tabula_Steps.Flows;

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
      A_Again,
      A_Refuse_No_Table,
      A_Refuse_Scale,
      A_Check_Items);

   Key_Capture   : constant := 1;
   Scale_Capture : constant := 2;
   Want_Capture  : constant := 1;

   --  The knob each walked table is known by.
   Name_Key : constant String := "name";

   --  What a walked table says when it has no name.
   Nameless : constant String := "?";

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

   --  Item after the items so far, comma-separated.
   procedure Add (Items : in out Unbounded_String; Item : String) is
   begin
      if Length (Items) > 0 then
         Append (Items, ",");
      end if;
      Append (Items, Item);
   end Add;

   procedure Visit_Strings (Ctx : in out Step_Context) is
      procedure Visit (Item : String) is
      begin
         Add (Ctx.W.Items, Item);
      end Visit;
   begin
      Ctx.W.Items := Null_Unbounded_String;
      Tabula.Config.Each_String (Ctx.W.Root, Key (Ctx), Visit'Access);
   end Visit_Strings;

   --  A number as a feature writes it: no leading blank.
   function Image (Value : Long_Long_Integer) return String
   is (Fabula.Check.Long_Image (Value));

   procedure Visit_Scaled (Ctx : in out Step_Context)
   with Pre => Count_Read (Ctx, Scale_Capture)
   is
      procedure Visit (Item : Long_Long_Integer) is
      begin
         Add (Ctx.W.Items, Image (Item));
      end Visit;
   begin
      Ctx.W.Items := Null_Unbounded_String;
      Tabula.Config.Each_Scaled
        (Ctx.W.Root, Key (Ctx), Count (Ctx, Scale_Capture), Visit'Access);
   end Visit_Scaled;

   procedure Visit_Sections (Ctx : in out Step_Context) is
      procedure Visit (Item : Tabula.Config.Table) is
      begin
         Add (Ctx.W.Items, Tabula.Config.Get (Item, Name_Key, Nameless));
      end Visit;
   begin
      Ctx.W.Items := Null_Unbounded_String;
      Tabula.Config.Each_Section (Ctx.W.Root, Key (Ctx), Visit'Access);
   end Visit_Sections;

   procedure Visit_Keys (Ctx : in out Step_Context) is
      procedure Visit (Key : String) is
      begin
         Add (Ctx.W.Items, Key);
      end Visit;
   begin
      Ctx.W.Items := Null_Unbounded_String;
      Tabula.Config.Each_Key (Ctx.W.Root, Visit'Access);
   end Visit_Keys;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing         =>
            null;

         when A_Walk_Strings    =>
            Visit_Strings (Ctx);

         when A_Walk_Scaled     =>
            Visit_Scaled (Ctx);

         when A_Walk_Sections   =>
            Visit_Sections (Ctx);

         when A_Walk_Keys       =>
            Visit_Keys (Ctx);

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

   Walk_Strings  : constant Ev := (Kind => E_Walk_Strings);
   Walk_Scaled   : constant Ev := (Kind => E_Walk_Scaled);
   Walk_Sections : constant Ev := (Kind => E_Walk_Sections);
   Walk_Keys     : constant Ev := (Kind => E_Walk_Keys);
   Check_Items   : constant Ev := (Kind => E_Check_Items);

   --!format off
   Table : constant Transition_Table :=
     [Unwalked + Walk_Strings  (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Strings                / A_Walk_Strings    >= Walked,
      Unwalked + Walk_Scaled   (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Scaled   (Scale_Given) / A_Walk_Scaled     >= Walked,
      Unwalked + Walk_Scaled                 / A_Refuse_Scale    >= Unwalked,
      Unwalked + Walk_Sections (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Sections               / A_Walk_Sections   >= Walked,
      Unwalked + Walk_Keys     (No_Table)    / A_Refuse_No_Table >= Unwalked,
      Unwalked + Walk_Keys                   / A_Walk_Keys       >= Walked,
      Walked   + Walk_Strings                / A_Again           >= Unwalked,
      Walked   + Walk_Scaled                 / A_Again           >= Unwalked,
      Walked   + Walk_Sections               / A_Again           >= Unwalked,
      Walked   + Walk_Keys                   / A_Again           >= Unwalked,
      Walked   + Check_Items                 / A_Check_Items     >= Walked];
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
