with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Strings.Fixed;

package body Tabula_World is

   package Messages is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);

   --  Every warning since the last Reset or Parse, one message each.
   Warnings : Messages.Vector;

   procedure Record_Warning (Message : String) is
   begin
      Warnings.Append (Message);
   end Record_Warning;

   procedure Reset is
   begin
      Warnings.Clear;
   end Reset;

   procedure Parse
     (Content : String;
      Label   : String;
      Root    : out Tabula.Config.Table;
      Status  : out Tabula.Config.Load_Status;
      Error   : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Reset;
      Tabula.Config.Parse
        (Content, Label, Record_Warning'Access, Root, Status, Error);
   end Parse;

   procedure Load
     (Path   : String;
      Label  : String;
      Root   : out Tabula.Config.Table;
      Status : out Tabula.Config.Load_Status;
      Error  : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Reset;
      Tabula.Config.Load
        (Path, Label, Record_Warning'Access, Root, Status, Error);
   end Load;

   --  Where the named configs sit beside the features.
   Configs_Subdir : constant String := "configs";

   --  What a named config's file ends with.
   Toml_Extension : constant String := "toml";

   function Configs_Dir (Info : Fabula.Frames.Frame) return String
   is (Ada.Directories.Compose
         (Ada.Directories.Containing_Directory
            (Fabula.Frames.Value (Info.File)),
          Configs_Subdir));

   function Named (Dir, Name : String) return String
   is (Ada.Directories.Compose (Dir, Name, Toml_Extension));

   function Named_Exists (Dir, Name : String) return Boolean
   is (Ada.Directories.Exists (Named (Dir, Name)));

   function Silent return Boolean
   is (Warnings.Is_Empty);

   function Warned (Fragment : String) return Boolean
   is (for some Message of Warnings =>
         Ada.Strings.Fixed.Index (Message, Fragment) > 0);

   --  What every warning a table makes starts with: its label.
   function Prefix (Label : String) return String
   is (Label & ": ");

   function Starts (Message, Head : String) return Boolean
   is (Message'Length >= Head'Length
       and then Message (Message'First .. Message'First + Head'Length - 1)
                = Head);

   --  Whether Text names Key as a whole word, blank-delimited.
   function Names (Text, Key : String) return Boolean
   is (Ada.Strings.Fixed.Index (" " & Text & " ", " " & Key & " ") > 0);

   function Complained (Label, Key : String) return Boolean
   is (for some Message of Warnings =>
         Starts (Message, Prefix (Label))
         and then Names
                    (Message
                       (Message'First + Prefix (Label)'Length .. Message'Last),
                     Key));

   function Warnings_Text return String is
      Text : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Message of Warnings loop
         Ada.Strings.Unbounded.Append (Text, " [" & Message & "]");
      end loop;
      return Ada.Strings.Unbounded.To_String (Text);
   end Warnings_Text;

end Tabula_World;
