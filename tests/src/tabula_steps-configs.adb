with Ada.Directories;

with Tabula_Steps.Flows;
with Tabula_World;

package body Tabula_Steps.Configs is

   use type Tabula.Config.Load_Status;

   --  Unparsed until a config is given; Given while what came of it is
   --  settled; Parsed with a loaded table in hand, Refused with the
   --  empty one a missing or malformed config leaves.
   type State is (Unparsed, Given, Parsed, Refused);

   type Guard_Kind is (Always, Doc_Given, File_Named, Document_Saved, Loaded);

   type Action_Kind is
     (A_Nothing,
      --  Giving a config.
      A_Parse,
      A_Load,
      A_Load_Missing,
      A_Load_Saved,
      A_Refuse_Doc,
      A_Refuse_File,
      A_Refuse_Unsaved,
      A_Take_Section,
      --  Checking it.
      A_Check_Loaded,
      A_Check_Malformed,
      A_Check_Missing,
      A_Check_Silent,
      A_Check_Warned);

   subtype Give_Action is Action_Kind range A_Parse .. A_Take_Section;
   subtype Check_Action is Action_Kind range A_Check_Loaded .. A_Check_Warned;

   --  Where each value sits among a step's captures.
   Label_Capture : constant := 1;
   File_Capture  : constant := 2;
   Key_Capture   : constant := 1;
   Name_Capture  : constant := 1;

   --  The config no configs directory holds.
   Absent_Name : constant String := "does-not-exist";

   function Label (Ctx : Step_Context) return String
   is (Fabula.Args.Text (Ctx.A, Label_Capture));

   function File (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, File_Capture));

   function Dir (Ctx : Step_Context) return String
   is (Tabula_World.Configs_Dir (Ctx.Info));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always         => True,
           when Doc_Given      => Fabula.Args.Has_Doc (Ctx.A),
           when File_Named     =>
             Tabula_World.Named_Exists (Dir (Ctx), File (Ctx)),
           when Document_Saved =>
             Ada.Directories.Exists (Tabula_World.Saved_Document),
           when Loaded         => Ctx.W.Status = Tabula.Config.Loaded);
   end Evaluate;

   ---------------------------------------------------------------------
   --  Giving a config: a doc string, a named file, or a file that is
   --  not there.  Each then settles what came of it.
   ---------------------------------------------------------------------

   procedure Parse (Ctx : in out Step_Context)
   with Pre => Fabula.Args.Has_Doc (Ctx.A)
   is
   begin
      Ctx.W.Label := To_Unbounded_String (Label (Ctx));
      Tabula_World.Parse
        (Content => Fabula.Args.Doc_String (Ctx.A),
         Label   => Label (Ctx),
         Root    => Ctx.W.Root,
         Status  => Ctx.W.Status,
         Error   => Ctx.W.Error);
      Then_Take (Ctx, E_Given);
   end Parse;

   procedure Load (Ctx : in out Step_Context; Path : String) is
   begin
      Ctx.W.Label := To_Unbounded_String (Label (Ctx));
      Tabula_World.Load
        (Path   => Path,
         Label  => Label (Ctx),
         Root   => Ctx.W.Root,
         Status => Ctx.W.Status,
         Error  => Ctx.W.Error);
      Then_Take (Ctx, E_Given);
   end Load;

   procedure Execute_Give (A : Give_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Parse          =>
            Parse (Ctx);

         when A_Load           =>
            Load (Ctx, Tabula_World.Named (Dir (Ctx), File (Ctx)));

         when A_Load_Missing   =>
            Load (Ctx, Tabula_World.Named (Dir (Ctx), Absent_Name));

         when A_Load_Saved     =>
            Load (Ctx, Tabula_World.Saved_Document);

         when A_Refuse_Doc     =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the config is the step's doc string, and it has none");

         when A_Refuse_File    =>
            Fabula.Check.Fail_Step
              (Ctx.R, "no config named " & File (Ctx) & " in " & Dir (Ctx));

         when A_Refuse_Unsaved =>
            Fabula.Check.Fail_Step (Ctx.R, "no document was saved to read");

         when A_Take_Section   =>
            Ctx.W.Root :=
              Tabula.Config.Section
                (Ctx.W.Root, Fabula.Args.Word (Ctx.A, Name_Capture));
      end case;
   end Execute_Give;

   ---------------------------------------------------------------------
   --  Checking what came of it, and what the table complained about.
   ---------------------------------------------------------------------

   procedure Expect_Status
     (Ctx : in out Step_Context; Want : Tabula.Config.Load_Status) is
   begin
      Fabula.Check.Text_Equal (Ctx.R, Ctx.W.Status'Image, Want'Image);
   end Expect_Status;

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

   procedure Execute_Check (A : Check_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Check_Loaded    =>
            Expect_Status (Ctx, Tabula.Config.Loaded);

         when A_Check_Malformed =>
            Expect_Status (Ctx, Tabula.Config.Malformed);
            Fabula.Check.Is_True
              (Ctx.R, Length (Ctx.W.Error) > 0, "the parser said nothing");

         when A_Check_Missing   =>
            Expect_Status (Ctx, Tabula.Config.Missing);

         when A_Check_Silent    =>
            Fabula.Check.Is_True
              (Ctx.R,
               Tabula_World.Silent,
               "warned:" & Tabula_World.Warnings_Text);

         when A_Check_Warned    =>
            Find_Complaint (Ctx);
      end case;
   end Execute_Check;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing    =>
            null;

         when Give_Action  =>
            Execute_Give (A, Ctx);

         when Check_Action =>
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

   Parse_Doc       : constant Ev := (Kind => E_Parse_Doc);
   Load_File       : constant Ev := (Kind => E_Load_File);
   Load_Missing    : constant Ev := (Kind => E_Load_Missing);
   Load_Saved      : constant Ev := (Kind => E_Load_Saved);
   Given_Config    : constant Ev := (Kind => E_Given);
   Take_Section    : constant Ev := (Kind => E_Take_Section);
   Check_Loaded    : constant Ev := (Kind => E_Check_Loaded);
   Check_Malformed : constant Ev := (Kind => E_Check_Malformed);
   Check_Missing   : constant Ev := (Kind => E_Check_Missing);
   Check_Silent    : constant Ev := (Kind => E_Check_Silent);
   Check_Warned    : constant Ev := (Kind => E_Check_Warned);

   --!format off
   Table : constant Transition_Table :=
     [Unparsed + Parse_Doc       (Doc_Given)  / A_Parse           >= Given,
      Unparsed + Parse_Doc                    / A_Refuse_Doc      >= Unparsed,
      Unparsed + Load_File       (File_Named) / A_Load            >= Given,
      Unparsed + Load_File                    / A_Refuse_File     >= Unparsed,
      Unparsed + Load_Missing                 / A_Load_Missing    >= Given,
      Unparsed + Load_Saved  (Document_Saved) / A_Load_Saved      >= Given,
      Unparsed + Load_Saved                   / A_Refuse_Unsaved  >= Unparsed,

      Given    + Given_Config    (Loaded)     / A_Nothing         >= Parsed,
      Given    + Given_Config                 / A_Nothing         >= Refused,

      Parsed   + Take_Section                 / A_Take_Section    >= Parsed,

      Parsed   + Check_Loaded                 / A_Check_Loaded    >= Parsed,
      Parsed   + Check_Malformed              / A_Check_Malformed >= Parsed,
      Parsed   + Check_Missing                / A_Check_Missing   >= Parsed,
      Parsed   + Check_Silent                 / A_Check_Silent    >= Parsed,
      Parsed   + Check_Warned                 / A_Check_Warned    >= Parsed,
      Refused  + Check_Loaded                 / A_Check_Loaded    >= Refused,
      Refused  + Check_Malformed              / A_Check_Malformed >= Refused,
      Refused  + Check_Missing                / A_Check_Missing   >= Refused,
      Refused  + Check_Silent                 / A_Check_Silent    >= Refused,
      Refused  + Check_Warned                 / A_Check_Warned    >= Refused];
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
   is (Current in Parsed | Refused);

end Tabula_Steps.Configs;
