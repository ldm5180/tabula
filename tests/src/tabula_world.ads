with Ada.Strings.Unbounded;

with Tabula.Config;
with Tabula.Config.Values;

with Fabula.Frames;

private with Ada.Containers.Indefinite_Vectors;

--  What the AUnit suite and the features share: a recording warner, a
--  parse and a load through it, a recording listener a reader owns, and
--  the named configs on disk.  Tabula.Config.Warner is a library-level
--  access type, so what the warner records is package state here,
--  cleared by Reset and by every Parse; what a Recorder hears is its own.

package Tabula_World is

   --  Forget every recorded warning.
   procedure Reset;

   --  Parse Content under Label, warning through the recorder, which
   --  starts empty: the warnings recorded are this table's.
   procedure Parse
     (Content : String;
      Label   : String;
      Root    : out Tabula.Config.Table;
      Status  : out Tabula.Config.Load_Status;
      Error   : out Ada.Strings.Unbounded.Unbounded_String);

   --  Load Path under Label, warning through the recorder, which starts
   --  empty, as Parse does.
   procedure Load
     (Path   : String;
      Label  : String;
      Root   : out Tabula.Config.Table;
      Status : out Tabula.Config.Load_Status;
      Error  : out Ada.Strings.Unbounded.Unbounded_String);

   --  The directory of named configs beside the feature file that
   --  Info's step belongs to.
   function Configs_Dir (Info : Fabula.Frames.Frame) return String;

   --  The file the config Name is in Dir: Dir/Name.toml.
   function Named (Dir, Name : String) return String;

   --  Whether Dir holds the config Name.
   function Named_Exists (Dir, Name : String) return Boolean;

   --  Whether no warning was recorded.
   function Silent return Boolean;

   --  Whether a recorded warning contains Fragment.
   function Warned (Fragment : String) return Boolean;

   --  Whether a recorded warning was made by the table labelled Label
   --  and names Key as a word of its own -- whatever else it says.
   function Complained (Label, Key : String) return Boolean;

   --  Every recorded warning, for a failure to show.
   function Warnings_Text return String;

   --  A listener a reader owns: every warning its tables made, in order.
   type Recorder is limited new Tabula.Config.Listener with private;

   overriding
   procedure Warn (R : in out Recorder; Message : String);

   --  Whether R heard no warning.
   function Silent (R : Recorder) return Boolean;

   --  Whether a warning R heard contains Fragment.
   function Warned (R : Recorder; Fragment : String) return Boolean;

   --  Whether R heard a warning from the table labelled Label that names
   --  Key as a word of its own, as Complained asks of the recorder.
   function Complained (R : Recorder; Label, Key : String) return Boolean;

   --  Every warning R heard, for a failure to show.
   function Warnings_Text (R : Recorder) return String;

   --  A visitor a reader owns, of every walk a table offers: what each
   --  walk handed it, comma-separated -- a string or a key as it is, a
   --  number as its digits, a table as its name knob ("?" with none).
   type Gatherer is limited
     new Tabula.Config.String_Visitor
     and Tabula.Config.Scaled_Visitor
     and Tabula.Config.Section_Visitor
     and Tabula.Config.Key_Visitor with private;

   overriding
   procedure Visit_String (G : in out Gatherer; Item : String);

   overriding
   procedure Visit_Scaled (G : in out Gatherer; Item : Long_Long_Integer);

   overriding
   procedure Visit_Section (G : in out Gatherer; Item : Tabula.Config.Table);

   overriding
   procedure Visit_Key (G : in out Gatherer; Key : String);

   function Items (G : Gatherer) return String;

   --  What a List_Gatherer reads of each list: its strings, or its
   --  numbers at a scale.
   type Entry_Kind is (Strings, Numbers);

   --  A list visitor a reader owns: each list it was handed, its entries
   --  of Kind (numbers at Scale) gathered as a Gatherer gathers them and
   --  bracketed, the lists comma-separated ("[a,b],[c]").
   type List_Gatherer
     (Kind  : Entry_Kind := Strings;
      Scale : Positive := 1)
   is limited new Tabula.Config.List_Visitor with private;

   overriding
   procedure Visit_List (G : in out List_Gatherer; Item : Tabula.Config.Table);

   function Items (G : List_Gatherer) return String;

   --  A value visitor a reader owns: each value it was handed as
   --  key:KIND:text, comma-separated, a table's values walked in turn
   --  in braces and a list's in brackets.
   type Value_Gatherer is limited
     new Tabula.Config.Values.Value_Visitor with private;

   overriding
   procedure Visit_Value
     (G    : in out Value_Gatherer;
      Key  : String;
      Kind : Tabula.Config.Values.Value_Kind;
      Text : String;
      Item : Tabula.Config.Table);

   function Items (G : Value_Gatherer) return String;

   --  A recorder a scenario holds across its steps, which copy the world.
   type Recorder_Access is access Recorder;

   --  Let R go, leaving it null.
   procedure Free (R : in out Recorder_Access);

   --  The scratch file Name: where a test writes, under the tests'
   --  object directory, which this creates when it is not there.  No
   --  file is made.
   function Scratch (Name : String) return String;

   --  Delete the scratch file Name, and its staging file, if there.
   procedure Clear_Scratch (Name : String);

   --  The scratch file a scenario saves the document it writes to,
   --  cleared before each scenario.
   Saved_Name : constant String := "feature-document.toml";

   --  Where Saved_Name is.
   function Saved_Document return String;

   --  Whether Text begins with Head.
   function Begins_With (Text, Head : String) return Boolean;

   --  Make the file at Path hold exactly Text.
   procedure Write_File (Path, Text : String);

   --  The whole of the file at Path, or "" when there is none.
   function Contents (Path : String) return String;

private

   package Messages is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);

   type Recorder is limited new Tabula.Config.Listener with record
      Heard : Messages.Vector;
   end record;

   type Gatherer is limited
     new Tabula.Config.String_Visitor
     and Tabula.Config.Scaled_Visitor
     and Tabula.Config.Section_Visitor
     and Tabula.Config.Key_Visitor
   with record
      Items : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type List_Gatherer
     (Kind  : Entry_Kind := Strings;
      Scale : Positive := 1)
   is limited new Tabula.Config.List_Visitor with record
      Lists : Gatherer;
   end record;

   type Value_Gatherer is limited new Tabula.Config.Values.Value_Visitor
   with record
      Items : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Tabula_World;
