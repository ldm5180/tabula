private with Ada.Finalization;
private with Ada.Streams.Stream_IO;
private with Ada.Strings.Unbounded;

--  A file written beside its path and renamed into place on Commit, so a
--  reader of the path sees the old file or the whole new one, never a
--  part.  Output is buffered.  Every failure is an outcome: a Put that
--  fails is remembered, and Commit then reports it and leaves the old
--  file.  A staged file let go of while open is abandoned.

package Tabula.Staged_Files is

   type Staged_File is limited private;

   --  Start writing the file that will be Path, abandoning any F had
   --  open.  Ok is False when the staging file cannot be made beside
   --  Path; F then takes Puts and commits nothing.
   procedure Open (F : in out Staged_File; Path : String; Ok : out Boolean);

   procedure Put (F : in out Staged_File; Text : String);

   --  Put the rest, close, and rename the staging file onto the path.
   --  Ok is False when anything since Open failed, or F is not open; the
   --  old file then stands and no staging file is left.
   procedure Commit (F : in out Staged_File; Ok : out Boolean);

   --  Drop what was put: the old file stands, no staging file is left.
   procedure Abandon (F : in out Staged_File);

private

   --  How much is put before it is written out.
   Buffer_Size : constant := 65_536;

   type Staged_File is new Ada.Finalization.Limited_Controlled with record
      File   : Ada.Streams.Stream_IO.File_Type;
      Path   : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : String (1 .. Buffer_Size);
      Used   : Natural := 0;
      Failed : Boolean := False;
   end record;

   overriding
   procedure Finalize (F : in out Staged_File);

end Tabula.Staged_Files;
