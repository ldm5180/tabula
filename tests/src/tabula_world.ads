with Ada.Strings.Unbounded;

with Tabula.Config;

with Fabula.Frames;

--  What the AUnit suite and the features share: a recording warner, a
--  parse and a load through it, and the named configs on disk.  Tabula.Config.Warner is a library-level access
--  type, so the recorder and what it records are package state here,
--  cleared by Reset and by every Parse.

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

end Tabula_World;
