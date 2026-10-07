with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Tabula.Config;
with Tabula.Csv;
with Tabula.Emit;
with Tabula.Text_Lists;

with Tabula_World;

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
      E_Parse_Heard,
      E_Load_File,
      E_Load_Missing,
      E_Load_Saved,
      E_Check_Loaded,
      E_Check_Malformed,
      E_Check_Missing,
      E_Take_Section,
      E_Check_Silent,
      E_Check_Warned,
      E_Check_Heard,
      E_Check_Heard_Nothing,
      E_Read_Bool,
      E_Read_Count,
      E_Read_Count_Min,
      E_Read_String,
      E_Read_Required,
      E_Read_Real,
      E_Read_Scaled,
      E_Read_Date,
      E_Read_Time,
      E_Ask_Has,
      E_Check_Reading,
      E_Check_Date,
      E_Check_Time,
      E_Check_Text,
      E_Check_Default,
      E_Check_Present,
      E_Check_Absent,
      E_Walk_Strings,
      E_Walk_Scaled,
      E_Walk_Sections,
      E_Walk_Keys,
      E_Visit_Strings,
      E_Visit_Scaled,
      E_Visit_Sections,
      E_Visit_Keys,
      E_Visit_String_Lists,
      E_Visit_Scaled_Lists,
      E_Check_Items,
      E_New_Document,
      E_Write_Comment,
      E_Begin_Table,
      E_Begin_Array_Table,
      E_Write_Text,
      E_Write_Count,
      E_Write_Number,
      E_Write_Flag,
      E_Write_Strings,
      E_Write_Date,
      E_Write_Time,
      E_Save_Document,
      E_Check_Saved,
      E_Check_Unsaved,
      E_Check_Refused,
      E_Give_Csv,
      E_Give_Missing_Csv,
      E_Read_Rows,
      E_Visit_Rows,
      E_Check_Rows_Read,
      E_Check_Row_Count,
      E_Check_By_Name,
      E_Check_Row_Fields,
      E_Check_Ragged,
      E_Check_Malformed_At,
      E_Check_Csv_Missing,
      E_Write_Csv,
      E_Check_Written,
      E_Check_Read_Back,
      --  Events no pattern names: a machine posts them to itself after
      --  an action whose result the next row's guard reads.
      E_Given);

   --  A scenario starts from a fresh world; the world holds no resource
   --  that would need stopping after it.
   type Hook_Kind is (Fresh_World);

   --  What a getter returned, by the getter's type, or what Has said;
   --  None before a read.
   type Reading_Kind is
     (None, Bool, Count, Text, Real, Scaled, Day, Clock, Presence);

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

         when Scaled =>
            Units : Long_Long_Integer := 0;

         when Day =>
            On : Tabula.Date;

         when Clock =>
            At_Time : Tabula.Time_Of_Day;

         when Presence =>
            Present : Boolean := False;
      end case;
   end record;

   --  Rows of a CSV file as read: each row's fields in order.
   package Row_Lists is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Tabula.Text_Lists.Vector,
        "="          => Tabula.Text_Lists."=");

   --  What one scenario reads back.  fabula copies it per step, so it
   --  holds values only: the table in hand (a reference to the parsed
   --  document) and its label, what was read from it, and the default
   --  the read was given, what a walk visited, the document being
   --  written and whether it saved, and a CSV file's path and what
   --  reading it came to: the header's names, and each row's fields by
   --  position and, in the header's order, by name; and the records a
   --  scenario wrote to one, header first, and whether it landed.  A
   --  scenario whose table has its own listener holds it on the heap,
   --  since the world is copied.
   type World is record
      Root    : Tabula.Config.Table;
      Heard   : Tabula_World.Recorder_Access;
      Label   : Unbounded_String;
      Status  : Tabula.Config.Load_Status := Tabula.Config.Loaded;
      Error   : Unbounded_String;
      Got     : Reading;
      Default : Reading;
      Items   : Unbounded_String;
      Doc     : Tabula.Emit.Document;
      Saved   : Boolean := False;
      Csv     : Unbounded_String;
      Outcome : Tabula.Csv.Outcome;
      Columns : Tabula.Text_Lists.Vector;
      Fields  : Row_Lists.Vector;
      Named   : Row_Lists.Vector;
      Wrote   : Row_Lists.Vector;
      Written : Boolean := False;
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
     [Step ("a config labelled {string} heard by its own listener:")
                                                                >= E_Parse_Heard,
      Step ("a config labelled {string}:")                      >= E_Parse_Doc,
      Step ("a config labelled {string} from the file {word}")  >= E_Load_File,
      Step ("a config labelled {string} from a file that does not exist")
                                                                >= E_Load_Missing,
      Step ("a config labelled {string} from the saved document")
                                                                >= E_Load_Saved,
      Step ("the config loaded")                                >= E_Check_Loaded,
      Step ("the config is malformed")                          >= E_Check_Malformed,
      Step ("the config is missing")                            >= E_Check_Missing,
      Step ("the section {word}")                               >= E_Take_Section,
      Step ("nothing was warned")                               >= E_Check_Silent,
      Step ("{word} was complained about")                      >= E_Check_Warned,
      Step ("its listener heard {word} complained about")       >= E_Check_Heard,
      Step ("its listener heard nothing")                       >= E_Check_Heard_Nothing,
      Step ("the boolean {word} is read with default {word}")   >= E_Read_Bool,
      Step ("the count {word} is read with default {int} and at least {int}")
                                                                >= E_Read_Count_Min,
      Step ("the count {word} is read with default {int}")      >= E_Read_Count,
      Step ("the string {word} is read with default {string}")  >= E_Read_String,
      Step ("the non-empty string {word} is read with default {string}")
                                                                >= E_Read_Required,
      Step ("the real {word} is read with default {word}")      >= E_Read_Real,
      Step ("the number {word} is read at a scale of {int} with default {int}")
                                                                >= E_Read_Scaled,
      Step ("the date {word} is read with default {word}")      >= E_Read_Date,
      Step ("the time {word} is read with default {word}")      >= E_Read_Time,
      Step ("{word} is asked for")                              >= E_Ask_Has,
      Step ("the reading is the default")                       >= E_Check_Default,
      Step ("the reading is the text {string}")                 >= E_Check_Text,
      Step ("the reading is year {int}, month {int}, day {int}")
                                                                >= E_Check_Date,
      Step ("the reading is hour {int}, minute {int}, second {int}")
                                                                >= E_Check_Time,
      Step ("the reading is {word}")                            >= E_Check_Reading,
      Step ("it is present")                                    >= E_Check_Present,
      Step ("it is absent")                                     >= E_Check_Absent,
      Step ("the strings of {word} are walked")                 >= E_Walk_Strings,
      Step ("the numbers of {word} are walked at a scale of {int}")
                                                                >= E_Walk_Scaled,
      Step ("the sections of {word} are walked")                >= E_Walk_Sections,
      Step ("the keys are walked")                              >= E_Walk_Keys,
      Step ("the strings of {word} are visited")                >= E_Visit_Strings,
      Step ("the numbers of {word} are visited at a scale of {int}")
                                                                >= E_Visit_Scaled,
      Step ("the sections of {word} are visited")               >= E_Visit_Sections,
      Step ("the keys are visited")                             >= E_Visit_Keys,
      Step ("the lists of {word} are visited as strings")       >= E_Visit_String_Lists,
      Step ("the lists of {word} are visited as numbers at a scale of {int}")
                                                                >= E_Visit_Scaled_Lists,
      Step ("the items were {string}")                          >= E_Check_Items,
      Step ("a new document")                                   >= E_New_Document,
      Step ("the comment {string} is written")                  >= E_Write_Comment,
      Step ("the table {word} is begun")                        >= E_Begin_Table,
      Step ("the array table {word} is begun")                  >= E_Begin_Array_Table,
      Step ("the text {word} is written as {string}")           >= E_Write_Text,
      Step ("the count {word} is written as {int}")             >= E_Write_Count,
      Step ("the number {word} is written as {word}")           >= E_Write_Number,
      Step ("the flag {word} is written as {word}")             >= E_Write_Flag,
      Step ("the strings {word} are written as {string}")       >= E_Write_Strings,
      Step ("the date {word} is written as {word}")             >= E_Write_Date,
      Step ("the time {word} is written as {word}")             >= E_Write_Time,
      Step ("the document is saved")                            >= E_Save_Document,
      Step ("it was saved")                                     >= E_Check_Saved,
      Step ("it was not saved")                                 >= E_Check_Unsaved,
      Step ("the document refused {word}")                      >= E_Check_Refused,
      Step ("a CSV file:")                                      >= E_Give_Csv,
      Step ("a CSV file that does not exist")                   >= E_Give_Missing_Csv,
      Step ("its rows are read")                                >= E_Read_Rows,
      Step ("its rows are visited")                             >= E_Visit_Rows,
      Step ("the rows read")                                    >= E_Check_Rows_Read,
      Step ("{int} rows were read")                             >= E_Check_Row_Count,
      Step ("the rows by column name are:")                     >= E_Check_By_Name,
      Step ("the fields of row {int} are:")                     >= E_Check_Row_Fields,
      Step ("the file is refused as ragged at line {int}")      >= E_Check_Ragged,
      Step ("the file is refused as malformed at line {int}")   >= E_Check_Malformed_At,
      Step ("the CSV file is missing")                          >= E_Check_Csv_Missing,
      Step ("a CSV file is written with the rows:")             >= E_Write_Csv,
      Step ("the CSV file was written")                         >= E_Check_Written,
      Step ("the rows read back are the rows written")          >= E_Check_Read_Back];
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
