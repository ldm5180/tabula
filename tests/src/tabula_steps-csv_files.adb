with Fabula.Check.Ints;
with Fabula.Numbers;

with Tabula_Steps.Flows;
with Tabula_World;

package body Tabula_Steps.Csv_Files is

   use type Tabula.Csv.Status_Kind;

   --  No_File until a file is given; Given with a path in hand; Read
   --  once its rows were read.
   type State is (No_File, Given, Read);

   type Guard_Kind is (Always, Doc_Given, Table_Given, Row_Read);

   type Action_Kind is
     (A_Nothing,
      --  Giving and reading a file.
      A_Give,
      A_Give_Missing,
      A_Read,
      --  Refusing a step written wrong.
      A_Refuse_Doc,
      A_Refuse_Table,
      A_Refuse_Row,
      --  Checking.
      A_Check_Read,
      A_Check_Count,
      A_Check_By_Name,
      A_Check_Fields,
      A_Check_Ragged,
      A_Check_Malformed,
      A_Check_Missing);

   subtype Give_Action is Action_Kind range A_Give .. A_Read;
   subtype Refuse_Action is Action_Kind range A_Refuse_Doc .. A_Refuse_Row;
   subtype Check_Action is Action_Kind range A_Check_Read .. A_Check_Missing;

   --  The files a scenario gives, as scratch files.
   Given_Name  : constant String := "feature.csv";
   Absent_Name : constant String := "absent.csv";

   --  Where a step's count or line sits among its captures, and where a
   --  table's column names are.
   Number_Capture : constant := 1;
   Name_Row       : constant := 1;

   --  How a table's cell writes a line break.
   Line_Break_Mark : constant String := "\n";

   function Number
     (Ctx : Step_Context) return Fabula.Numbers.Integer_Reads.Read
   is (Fabula.Args.Int (Ctx.A, Number_Capture));

   function Rows_Read (Ctx : Step_Context) return Natural
   is (Natural (Ctx.W.Fields.Length));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when Doc_Given   => Fabula.Args.Has_Doc (Ctx.A),
           when Table_Given => Fabula.Args.Has_Table (Ctx.A),
           when Row_Read    =>
             Fabula.Args.Has_Table (Ctx.A)
             and then Count_Read (Ctx, Number_Capture)
             and then Count (Ctx, Number_Capture) in 1 .. Rows_Read (Ctx));
   end Evaluate;

   ---------------------------------------------------------------------
   --  Giving and reading a file.  A read hands its rows to Keep, which
   --  gathers them here; Gather_Rows then moves them into the world.
   ---------------------------------------------------------------------

   Columns : Tabula.Text_Lists.Vector;
   Fields  : Row_Lists.Vector;
   Named   : Row_Lists.Vector;

   procedure Keep_Columns (Row : Tabula.Csv.Row) is
   begin
      for I in 1 .. Tabula.Csv.Field_Count (Row) loop
         Columns.Append (Tabula.Csv.Column (Row, I));
      end loop;
   end Keep_Columns;

   procedure Keep (Row : Tabula.Csv.Row) is
      By_Position, By_Name : Tabula.Text_Lists.Vector;
   begin
      if Columns.Is_Empty then
         Keep_Columns (Row);
      end if;
      for I in 1 .. Tabula.Csv.Field_Count (Row) loop
         By_Position.Append (Tabula.Csv.Field (Row, I));
         By_Name.Append (Tabula.Csv.Field (Row, Tabula.Csv.Column (Row, I)));
      end loop;
      Fields.Append (By_Position);
      Named.Append (By_Name);
   end Keep;

   procedure Gather_Rows (Ctx : in out Step_Context) is
   begin
      Columns.Clear;
      Fields.Clear;
      Named.Clear;
      Tabula.Csv.Each_Row (To_String (Ctx.W.Csv), Keep'Access, Ctx.W.Outcome);
      Ctx.W.Columns := Columns;
      Ctx.W.Fields := Fields;
      Ctx.W.Named := Named;
   end Gather_Rows;

   procedure Execute_Give (A : Give_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Give         =>
            Ctx.W.Csv :=
              To_Unbounded_String (Tabula_World.Scratch (Given_Name));
            Tabula_World.Write_File
              (To_String (Ctx.W.Csv), Fabula.Args.Doc_String (Ctx.A));

         when A_Give_Missing =>
            Tabula_World.Clear_Scratch (Absent_Name);
            Ctx.W.Csv :=
              To_Unbounded_String (Tabula_World.Scratch (Absent_Name));

         when A_Read         =>
            Gather_Rows (Ctx);
      end case;
   end Execute_Give;

   procedure Execute_Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Doc   =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the file is the step's doc string, and it has none");

         when A_Refuse_Table =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the rows are the step's table, and it has none");

         when A_Refuse_Row   =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no such row was read; rows read:"
               & Natural'Image (Rows_Read (Ctx)));
      end case;
   end Execute_Refuse;

   ---------------------------------------------------------------------
   --  Checking.
   ---------------------------------------------------------------------

   --  Cell with each Line_Break_Mark a line break.
   function Unmarked (Cell : String) return String is
      Text : Unbounded_String := To_Unbounded_String (Cell);
      At_I : Natural := Index (Text, Line_Break_Mark);
   begin
      while At_I > 0 loop
         Replace_Slice
           (Text, At_I, At_I + Line_Break_Mark'Length - 1, [ASCII.LF]);
         At_I := Index (Text, Line_Break_Mark, At_I + 1);
      end loop;
      return To_String (Text);
   end Unmarked;

   --  The table's cell for the read row R, column C.
   function Want (Ctx : Step_Context; R, C : Positive) return String
   is (Unmarked (Fabula.Args.Cell (Ctx.A, R + Name_Row, C)));

   --  The field read row R holds under the table's column C, by name.
   procedure Check_Named_Cell (Ctx : in out Step_Context; R, C : Positive) is
      Name : constant String := Fabula.Args.Cell (Ctx.A, Name_Row, C);
      Pos  : constant Natural := Ctx.W.Columns.Find_Index (Name);
   begin
      if Pos = 0 then
         Fabula.Check.Fail_Step (Ctx.R, "no column " & Name & " was read");
      else
         Fabula.Check.Text_Equal
           (Ctx.R, Ctx.W.Named (R) (Pos), Want (Ctx, R, C));
      end if;
   end Check_Named_Cell;

   procedure Check_Named_Rows (Ctx : in out Step_Context) is
      Rows : constant Natural := Fabula.Args.Row_Count (Ctx.A) - Name_Row;
   begin
      Fabula.Check.Ints.Equal (Ctx.R, Rows_Read (Ctx), Rows, "rows read");
      for R in 1 .. Natural'Min (Rows, Rows_Read (Ctx)) loop
         for C in 1 .. Fabula.Args.Col_Count (Ctx.A) loop
            Check_Named_Cell (Ctx, R, C);
         end loop;
      end loop;
   end Check_Named_Rows;

   procedure Check_Fields (Ctx : in out Step_Context)
   with Pre => Count_Read (Ctx, Number_Capture)
   is
      Got : constant Tabula.Text_Lists.Vector :=
        Ctx.W.Fields (Count (Ctx, Number_Capture));
   begin
      Fabula.Check.Ints.Equal
        (Ctx.R, Natural (Got.Length), Fabula.Args.Col_Count (Ctx.A), "fields");
      for C in
        1 .. Natural'Min (Natural (Got.Length), Fabula.Args.Col_Count (Ctx.A))
      loop
         Fabula.Check.Text_Equal
           (Ctx.R, Got (C), Unmarked (Fabula.Args.Cell (Ctx.A, 1, C)));
      end loop;
   end Check_Fields;

   --  The read came to Status, at the step's line.
   procedure Expect_Refused
     (Ctx : in out Step_Context; Status : Tabula.Csv.Status_Kind) is
   begin
      Fabula.Check.Text_Equal
        (Ctx.R, Ctx.W.Outcome.Status'Image, Status'Image);
      Fabula.Check.Ints.Equal
        (Ctx.R, Ctx.W.Outcome.Line, Number (Ctx), "line");
   end Expect_Refused;

   procedure Execute_Check (A : Check_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Check_Read      =>
            Fabula.Check.Text_Equal
              (Ctx.R, Ctx.W.Outcome.Status'Image, Tabula.Csv.Read'Image);

         when A_Check_Count     =>
            Fabula.Check.Ints.Equal (Ctx.R, Rows_Read (Ctx), Number (Ctx));

         when A_Check_By_Name   =>
            Check_Named_Rows (Ctx);

         when A_Check_Fields    =>
            Check_Fields (Ctx);

         when A_Check_Ragged    =>
            Expect_Refused (Ctx, Tabula.Csv.Ragged);

         when A_Check_Malformed =>
            Expect_Refused (Ctx, Tabula.Csv.Malformed);

         when A_Check_Missing   =>
            Fabula.Check.Is_True
              (Ctx.R,
               Ctx.W.Outcome.Status = Tabula.Csv.Missing,
               "the read came to " & Ctx.W.Outcome.Status'Image);
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

         when Give_Action   =>
            Execute_Give (A, Ctx);

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

   Give_Csv           : constant Ev := (Kind => E_Give_Csv);
   Give_Missing_Csv   : constant Ev := (Kind => E_Give_Missing_Csv);
   Read_Rows          : constant Ev := (Kind => E_Read_Rows);
   Check_Rows_Read    : constant Ev := (Kind => E_Check_Rows_Read);
   Check_Row_Count    : constant Ev := (Kind => E_Check_Row_Count);
   Check_By_Name      : constant Ev := (Kind => E_Check_By_Name);
   Check_Row_Fields   : constant Ev := (Kind => E_Check_Row_Fields);
   Check_Ragged       : constant Ev := (Kind => E_Check_Ragged);
   Check_Malformed_At : constant Ev := (Kind => E_Check_Malformed_At);
   Check_Csv_Missing  : constant Ev := (Kind => E_Check_Csv_Missing);

   --!format off
   Table : constant Transition_Table :=
     [No_File + Give_Csv         (Doc_Given)   / A_Give            >= Given,
      No_File + Give_Csv                       / A_Refuse_Doc      >= No_File,
      No_File + Give_Missing_Csv               / A_Give_Missing    >= Given,

      Given   + Read_Rows                      / A_Read            >= Read,

      Read    + Check_Rows_Read                / A_Check_Read      >= Read,
      Read    + Check_Row_Count                / A_Check_Count     >= Read,
      Read    + Check_By_Name    (Table_Given) / A_Check_By_Name   >= Read,
      Read    + Check_By_Name                  / A_Refuse_Table    >= Read,
      Read    + Check_Row_Fields (Row_Read)    / A_Check_Fields    >= Read,
      Read    + Check_Row_Fields (Table_Given) / A_Refuse_Row      >= Read,
      Read    + Check_Row_Fields               / A_Refuse_Table    >= Read,
      Read    + Check_Ragged                   / A_Check_Ragged    >= Read,
      Read    + Check_Malformed_At             / A_Check_Malformed >= Read,
      Read    + Check_Csv_Missing              / A_Check_Missing   >= Read];
   --!format on

   Current : State := No_File;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := No_File;
   end Reset;

   function Phase return String
   is (Current'Image);

end Tabula_Steps.Csv_Files;
