with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Unchecked_Deallocation;

package body Tabula_World is

   --  What the warner records: every warning since the last Reset or
   --  Parse.  Package state because Tabula.Config.Warner is a
   --  library-level access type; a Recorder of the reader's own is the
   --  listener forms' way out of it.
   Shared : Recorder;

   procedure Record_Warning (Message : String) is
   begin
      Shared.Warn (Message);
   end Record_Warning;

   procedure Reset is
   begin
      Shared.Heard.Clear;
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

   --  What every warning a table makes starts with: its label.
   function Prefix (Label : String) return String
   is (Label & ": ");

   function Begins_With (Text, Head : String) return Boolean
   is (Text'Length >= Head'Length
       and then Text (Text'First .. Text'First + Head'Length - 1) = Head);

   --  Whether Text names Key as a whole word, blank-delimited.
   function Names (Text, Key : String) return Boolean
   is (Ada.Strings.Fixed.Index (" " & Text & " ", " " & Key & " ") > 0);

   --  Whether Message was made by the table labelled Label and names Key.
   function Complains (Message, Label, Key : String) return Boolean
   is (Begins_With (Message, Prefix (Label))
       and then Names
                  (Message
                     (Message'First + Prefix (Label)'Length .. Message'Last),
                   Key));

   overriding
   procedure Warn (R : in out Recorder; Message : String) is
   begin
      R.Heard.Append (Message);
   end Warn;

   function Silent (R : Recorder) return Boolean
   is (R.Heard.Is_Empty);

   --  Whether Text contains Fragment.
   function Contains (Text, Fragment : String) return Boolean
   is (Ada.Strings.Fixed.Index (Text, Fragment) > 0);

   function Warned (R : Recorder; Fragment : String) return Boolean
   is (for some Message of R.Heard => Contains (Message, Fragment));

   function Complained (R : Recorder; Label, Key : String) return Boolean
   is (for some Message of R.Heard => Complains (Message, Label, Key));

   function Warnings_Text (R : Recorder) return String is
      Text : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Message of R.Heard loop
         Ada.Strings.Unbounded.Append (Text, " [" & Message & "]");
      end loop;
      return Ada.Strings.Unbounded.To_String (Text);
   end Warnings_Text;

   function Silent return Boolean
   is (Silent (Shared));

   function Warned (Fragment : String) return Boolean
   is (Warned (Shared, Fragment));

   function Complained (Label, Key : String) return Boolean
   is (Complained (Shared, Label, Key));

   function Warnings_Text return String
   is (Warnings_Text (Shared));

   --  Item after G's items so far, comma-separated.
   procedure Add (G : in out Gatherer; Item : String) is
      use Ada.Strings.Unbounded;
   begin
      if Length (G.Items) > 0 then
         Append (G.Items, ",");
      end if;
      Append (G.Items, Item);
   end Add;

   overriding
   procedure Visit_String (G : in out Gatherer; Item : String) is
   begin
      Add (G, Item);
   end Visit_String;

   overriding
   procedure Visit_Scaled (G : in out Gatherer; Item : Long_Long_Integer) is
   begin
      Add (G, Ada.Strings.Fixed.Trim (Item'Image, Ada.Strings.Left));
   end Visit_Scaled;

   --  The knob each gathered table is known by, and what one without it
   --  is gathered as.
   Name_Key : constant String := "name";
   Nameless : constant String := "?";

   overriding
   procedure Visit_Section (G : in out Gatherer; Item : Tabula.Config.Table) is
   begin
      Add (G, Tabula.Config.Get (Item, Name_Key, Nameless));
   end Visit_Section;

   overriding
   procedure Visit_Key (G : in out Gatherer; Key : String) is
   begin
      Add (G, Key);
   end Visit_Key;

   function Items (G : Gatherer) return String
   is (Ada.Strings.Unbounded.To_String (G.Items));

   procedure Free_Recorder is new
     Ada.Unchecked_Deallocation (Recorder, Recorder_Access);

   procedure Free (R : in out Recorder_Access) is
   begin
      Free_Recorder (R);
   end Free;

   --  Where scratch files go, relative to the crate root both test
   --  runners run from.
   Scratch_Dir : constant String := "tests/obj/scratch";

   function Scratch (Name : String) return String is
   begin
      Ada.Directories.Create_Path (Scratch_Dir);
      return Ada.Directories.Compose (Scratch_Dir, Name);
   end Scratch;

   procedure Delete_If_There (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_If_There;

   --  What the staged writers name the file they write before renaming.
   Staging_Suffix : constant String := ".tmp";

   procedure Clear_Scratch (Name : String) is
   begin
      Delete_If_There (Scratch (Name));
      Delete_If_There (Scratch (Name) & Staging_Suffix);
   end Clear_Scratch;

   function Saved_Document return String
   is (Scratch (Saved_Name));

   procedure Write_File (Path, Text : String) is
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      Create (File, Out_File, Path);
      String'Write (Stream (File), Text);
      Close (File);
   end Write_File;

   function Contents (Path : String) return String is
      use Ada.Streams.Stream_IO;
      File : File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Open (File, In_File, Path);
      declare
         Text : String (1 .. Natural (Size (File)));
      begin
         String'Read (Stream (File), Text);
         Close (File);
         return Text;
      end;
   end Contents;

end Tabula_World;
