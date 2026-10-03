with Fabula.Check.Ints;

with Tabula_Steps.Configs;
with Tabula_Steps.Flows;

package body Tabula_Steps.Knobs is

   --  Unread until a knob is read; Read once a reading is in hand.  A
   --  read in Read starts again from Unread, so its rows live once.
   type State is (Unread, Read);

   type Guard_Kind is
     (Always,
      No_Table,
      Bool_Default,
      Count_Default,
      Bounds_Given,
      Bool_Said,
      Count_Kept,
      Text_Kept,
      Presence_Kept);

   type Action_Kind is
     (A_Nothing,
      --  Reading.
      A_Read_Bool,
      A_Read_Count,
      A_Read_Count_Min,
      A_Read_String,
      A_Read_Required,
      A_Ask_Has,
      A_Again,
      --  Refusing a step written wrong.
      A_Refuse_No_Table,
      A_Refuse_Bool_Default,
      A_Refuse_Default,
      A_Refuse_Floor,
      A_Refuse_Reading,
      A_Refuse_Unasked,
      --  Checking.
      A_Check_Bool,
      A_Check_Count,
      A_Check_Word_Text,
      A_Check_Text,
      A_Check_Default,
      A_Check_Present,
      A_Check_Absent);

   subtype Read_Action is Action_Kind range A_Read_Bool .. A_Again;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_No_Table .. A_Refuse_Unasked;
   subtype Check_Action is Action_Kind range A_Check_Bool .. A_Check_Absent;

   --  Where each value sits among a step's captures.
   Key_Capture     : constant := 1;
   Default_Capture : constant := 2;
   Floor_Capture   : constant := 3;
   Want_Capture    : constant := 1;

   function Key (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, Key_Capture));

   function Want (Ctx : Step_Context) return String
   is (Fabula.Args.Text (Ctx.A, Want_Capture));

   --  A boolean as the features write it.
   function Image (Flag : Boolean) return String
   is (if Flag then "true" else "false");

   function Is_Bool_Word (Text : String) return Boolean
   is (Text = Image (True) or else Text = Image (False));

   --  A reading as a failure states it.
   function Image (R : Reading) return String
   is (case R.Kind is
         when None     => "nothing",
         when Bool     => Image (R.Flag),
         when Count    => Fabula.Check.Integer_Image (R.Number),
         when Text     => '"' & To_String (R.Words) & '"',
         when Presence => (if R.Present then "present" else "absent"));

   function Kept (Ctx : Step_Context; Kind : Reading_Kind) return Boolean
   is (Ctx.W.Got.Kind = Kind);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always        => True,
           when No_Table      => not Configs.Holds_Table,
           when Bool_Default  =>
             Is_Bool_Word (Fabula.Args.Word (Ctx.A, Default_Capture)),
           when Count_Default => Count_Read (Ctx, Default_Capture),
           when Bounds_Given  =>
             Count_Read (Ctx, Default_Capture)
             and then Count_Read (Ctx, Floor_Capture),
           when Bool_Said     =>
             Kept (Ctx, Bool) and then Is_Bool_Word (Want (Ctx)),
           when Count_Kept    => Kept (Ctx, Count),
           when Text_Kept     => Kept (Ctx, Text),
           when Presence_Kept => Kept (Ctx, Presence));
   end Evaluate;

   ---------------------------------------------------------------------
   --  Reading: each getter's reading kept beside the default it was
   --  given.
   ---------------------------------------------------------------------

   procedure Keep (Ctx : in out Step_Context; Got, Default : Reading) is
   begin
      Ctx.W.Got := Got;
      Ctx.W.Default := Default;
   end Keep;

   procedure Get_Bool (Ctx : in out Step_Context) is
      Default : constant Boolean :=
        Fabula.Args.Word (Ctx.A, Default_Capture) = Image (True);
   begin
      Keep
        (Ctx,
         (Bool, Tabula.Config.Get (Ctx.W.Root, Key (Ctx), Default)),
         (Bool, Default));
   end Get_Bool;

   procedure Get_Count (Ctx : in out Step_Context; Floor : Natural := 0)
   with Pre => Count_Read (Ctx, Default_Capture)
   is
      Default : constant Natural := Count (Ctx, Default_Capture);
   begin
      Keep
        (Ctx,
         (Count, Tabula.Config.Get (Ctx.W.Root, Key (Ctx), Default, Floor)),
         (Count, Default));
   end Get_Count;

   procedure Get_String (Ctx : in out Step_Context; Required : Boolean) is
      Default : constant String := Fabula.Args.Text (Ctx.A, Default_Capture);
   begin
      Keep
        (Ctx,
         (Text,
          To_Unbounded_String
            (Tabula.Config.Get (Ctx.W.Root, Key (Ctx), Default, Required))),
         (Text, To_Unbounded_String (Default)));
   end Get_String;

   procedure Ask (Ctx : in out Step_Context) is
   begin
      Keep
        (Ctx,
         (Presence, Tabula.Config.Has (Ctx.W.Root, Key (Ctx))),
         (Kind => None));
   end Ask;

   procedure Execute_Read
     (A : Read_Action; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Read_Bool      =>
            Get_Bool (Ctx);

         when A_Read_Count     =>
            Get_Count (Ctx);

         when A_Read_Count_Min =>
            Get_Count (Ctx, Floor => Count (Ctx, Floor_Capture));

         when A_Read_String    =>
            Get_String (Ctx, Required => False);

         when A_Read_Required  =>
            Get_String (Ctx, Required => True);

         when A_Ask_Has        =>
            Ask (Ctx);

         when A_Again          =>
            Then_Take (Ctx, Evt);
      end case;
   end Execute_Read;

   procedure Execute_Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_No_Table     =>
            Fabula.Check.Fail_Step (Ctx.R, "no config was given to read from");

         when A_Refuse_Bool_Default =>
            Fabula.Check.Fail_Step
              (Ctx.R, "a boolean's default is true or false");

         when A_Refuse_Default      =>
            Refuse_Count (Ctx, Default_Capture);

         when A_Refuse_Floor        =>
            Refuse_Count (Ctx, Floor_Capture);

         when A_Refuse_Reading      =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "the reading is a "
               & Ctx.W.Got.Kind'Image
               & ", which "
               & Want (Ctx)
               & " cannot be");

         when A_Refuse_Unasked      =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "nothing was asked for: the reading is a "
               & Ctx.W.Got.Kind'Image);
      end case;
   end Execute_Refuse;

   ---------------------------------------------------------------------
   --  Checking the reading against what the step says.
   ---------------------------------------------------------------------

   procedure Execute_Check (A : Check_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Check_Bool                     =>
            Fabula.Check.Text_Equal
              (Ctx.R, Image (Ctx.W.Got.Flag), Want (Ctx));

         when A_Check_Count                    =>
            Fabula.Check.Ints.Equal
              (Ctx.R, Ctx.W.Got.Number, Fabula.Args.Int (Ctx.A, Want_Capture));

         when A_Check_Word_Text | A_Check_Text =>
            Fabula.Check.Text_Equal
              (Ctx.R, To_String (Ctx.W.Got.Words), Want (Ctx));

         when A_Check_Default                  =>
            Fabula.Check.Is_True
              (Ctx.R,
               Ctx.W.Got = Ctx.W.Default,
               "the reading is "
               & Image (Ctx.W.Got)
               & ", not the default "
               & Image (Ctx.W.Default));

         when A_Check_Present                  =>
            Fabula.Check.Is_True (Ctx.R, Ctx.W.Got.Present, "it is absent");

         when A_Check_Absent                   =>
            Fabula.Check.Is_False (Ctx.R, Ctx.W.Got.Present, "it is present");
      end case;
   end Execute_Check;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      case A is
         when A_Nothing     =>
            null;

         when Read_Action   =>
            Execute_Read (A, Ctx, Evt);

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

   Read_Bool      : constant Ev := (Kind => E_Read_Bool);
   Read_Count     : constant Ev := (Kind => E_Read_Count);
   Read_Count_Min : constant Ev := (Kind => E_Read_Count_Min);
   Read_String    : constant Ev := (Kind => E_Read_String);
   Read_Required  : constant Ev := (Kind => E_Read_Required);
   Ask_Has        : constant Ev := (Kind => E_Ask_Has);
   Check_Reading  : constant Ev := (Kind => E_Check_Reading);
   Check_Text     : constant Ev := (Kind => E_Check_Text);
   Check_Default  : constant Ev := (Kind => E_Check_Default);
   Check_Present  : constant Ev := (Kind => E_Check_Present);
   Check_Absent   : constant Ev := (Kind => E_Check_Absent);

   --!format off
   Table : constant Transition_Table :=
     [Unread + Read_Bool      (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Read_Bool      (Bool_Default)  / A_Read_Bool           >= Read,
      Unread + Read_Bool                      / A_Refuse_Bool_Default >= Unread,
      Unread + Read_Count     (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Read_Count     (Count_Default) / A_Read_Count          >= Read,
      Unread + Read_Count                     / A_Refuse_Default      >= Unread,
      Unread + Read_Count_Min (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Read_Count_Min (Bounds_Given)  / A_Read_Count_Min      >= Read,
      Unread + Read_Count_Min (Count_Default) / A_Refuse_Floor        >= Unread,
      Unread + Read_Count_Min                 / A_Refuse_Default      >= Unread,
      Unread + Read_String    (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Read_String                    / A_Read_String         >= Read,
      Unread + Read_Required  (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Read_Required                  / A_Read_Required       >= Read,
      Unread + Ask_Has        (No_Table)      / A_Refuse_No_Table     >= Unread,
      Unread + Ask_Has                        / A_Ask_Has             >= Read,

      Read   + Read_Bool                      / A_Again               >= Unread,
      Read   + Read_Count                     / A_Again               >= Unread,
      Read   + Read_Count_Min                 / A_Again               >= Unread,
      Read   + Read_String                    / A_Again               >= Unread,
      Read   + Read_Required                  / A_Again               >= Unread,
      Read   + Ask_Has                        / A_Again               >= Unread,

      Read   + Check_Reading  (Bool_Said)     / A_Check_Bool          >= Read,
      Read   + Check_Reading  (Count_Kept)    / A_Check_Count         >= Read,
      Read   + Check_Reading  (Text_Kept)     / A_Check_Word_Text     >= Read,
      Read   + Check_Reading                  / A_Refuse_Reading      >= Read,
      Read   + Check_Text     (Text_Kept)     / A_Check_Text          >= Read,
      Read   + Check_Text                     / A_Refuse_Reading      >= Read,
      Read   + Check_Default                  / A_Check_Default       >= Read,
      Read   + Check_Present  (Presence_Kept) / A_Check_Present       >= Read,
      Read   + Check_Present                  / A_Refuse_Unasked      >= Read,
      Read   + Check_Absent   (Presence_Kept) / A_Check_Absent        >= Read,
      Read   + Check_Absent                   / A_Refuse_Unasked      >= Read];
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
