with Tabula_Steps.Flows;
with Tabula_World;

package body Tabula_Steps.Configs is

   --  Unparsed until a config is given; Parsed once its table is in hand.
   type State is (Unparsed, Parsed);

   type Guard_Kind is (Always, Doc_Given);

   type Action_Kind is
     (A_Nothing, A_Parse, A_Refuse_Doc, A_Check_Silent, A_Check_Warned);

   Label_Capture : constant := 1;
   Key_Capture   : constant := 1;

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always    => True,
           when Doc_Given => Fabula.Args.Has_Doc (Ctx.A));
   end Evaluate;

   procedure Parse (Ctx : in out Step_Context)
   with Pre => Fabula.Args.Has_Doc (Ctx.A)
   is
   begin
      Ctx.W.Label :=
        To_Unbounded_String (Fabula.Args.Text (Ctx.A, Label_Capture));
      Tabula_World.Parse
        (Content => Fabula.Args.Doc_String (Ctx.A),
         Label   => Fabula.Args.Text (Ctx.A, Label_Capture),
         Root    => Ctx.W.Root,
         Status  => Ctx.W.Status,
         Error   => Ctx.W.Error);
   end Parse;

   procedure Find_Complaint (Ctx : in out Step_Context) is
      Key : constant String := Fabula.Args.Word (Ctx.A, Key_Capture);
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Tabula_World.Complained (To_String (Ctx.W.Label), Key),
         "no complaint from "
         & To_String (Ctx.W.Label)
         & " names "
         & Key
         & "; warned:"
         & Tabula_World.Warnings_Text);
   end Find_Complaint;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing      =>
            null;

         when A_Parse        =>
            Parse (Ctx);

         when A_Refuse_Doc   =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the config is the step's doc string, and it has none");

         when A_Check_Silent =>
            Fabula.Check.Is_True
              (Ctx.R,
               Tabula_World.Silent,
               "warned:" & Tabula_World.Warnings_Text);

         when A_Check_Warned =>
            Find_Complaint (Ctx);
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

   Parse_Doc    : constant Ev := (Kind => E_Parse_Doc);
   Check_Silent : constant Ev := (Kind => E_Check_Silent);
   Check_Warned : constant Ev := (Kind => E_Check_Warned);

   --!format off
   Table : constant Transition_Table :=
     [Unparsed + Parse_Doc (Doc_Given) / A_Parse        >= Parsed,
      Unparsed + Parse_Doc             / A_Refuse_Doc   >= Unparsed,
      Parsed   + Check_Silent          / A_Check_Silent >= Parsed,
      Parsed   + Check_Warned          / A_Check_Warned >= Parsed];
   --!format on

   Current : State := Unparsed;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unparsed;
   end Reset;

   function Phase return String
   is (Current'Image);

   function Holds_Table return Boolean
   is (Current /= Unparsed);

end Tabula_Steps.Configs;
