with Ada.Directories;

with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Staged_Files; use Tabula.Staged_Files;

with Tabula_World; use Tabula_World;

--  A staged file is written beside its path and renamed into place on
--  Commit, so the path holds the old file or the whole new one; every
--  other end leaves the old file and no staging file behind.

package body Tabula_Staged_Files_Tests is

   use AUnit.Test_Cases.Registration;

   File_Name : constant String := "staged.txt";

   --  More than one buffer's worth, so a Put must flush on the way.
   Long : constant String (1 .. 100_000) := [others => 'x'];

   function Path return String
   is (Scratch (File_Name));

   function Staging_Left return Boolean
   is (Ada.Directories.Exists (Path & ".tmp"));

   --  The scratch file holding Text, written the plain way.
   procedure Make_Old (Text : String) is
      F  : Staged_File;
      Ok : Boolean;
   begin
      Clear_Scratch (File_Name);
      Open (F, Path, Ok);
      Put (F, Text);
      Commit (F, Ok);
      Assert (Ok and then Contents (Path) = Text, "the old file is made");
   end Make_Old;

   procedure Test_Commit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      F  : Staged_File;
      Ok : Boolean;
   begin
      Clear_Scratch (File_Name);
      Open (F, Path, Ok);
      Assert (Ok, "a staged file opens");
      Put (F, "head" & ASCII.LF);
      Put (F, Long);
      Assert (not Ada.Directories.Exists (Path), "nothing is at the path yet");
      Commit (F, Ok);
      Assert (Ok, "it commits");
      Assert
        (Contents (Path) = "head" & ASCII.LF & Long, "with every byte put");
      Assert (not Staging_Left, "and no staging file left");
   end Test_Commit;

   procedure Test_Replace (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      F  : Staged_File;
      Ok : Boolean;
   begin
      Make_Old ("old");
      Open (F, Path, Ok);
      Put (F, "new");
      Assert (Contents (Path) = "old", "the old file stands until Commit");
      Commit (F, Ok);
      Assert (Ok and then Contents (Path) = "new", "then the new replaces it");
   end Test_Replace;

   procedure Test_Abandon (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      F  : Staged_File;
      Ok : Boolean;
   begin
      Make_Old ("old");
      Open (F, Path, Ok);
      Put (F, "new");
      Abandon (F);
      Assert (Contents (Path) = "old", "an abandoned file leaves the old");
      Assert (not Staging_Left, "and no staging file");
      Commit (F, Ok);
      Assert (not Ok, "nor can it be committed after");
   end Test_Abandon;

   --  A staged file let go of while open: Finalize abandons it.
   procedure Drop_Open is
      F  : Staged_File;
      Ok : Boolean;
   begin
      Open (F, Path, Ok);
      Put (F, "new");
   end Drop_Open;

   procedure Test_Dropped (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Make_Old ("old");
      Drop_Open;
      Assert (Contents (Path) = "old", "a dropped file leaves the old");
      Assert (not Staging_Left, "and no staging file");
   end Test_Dropped;

   procedure Test_Unopenable (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      F  : Staged_File;
      Ok : Boolean;
   begin
      Open (F, Scratch ("no-such-dir") & "/file.txt", Ok);
      Assert (not Ok, "a path in no directory does not open");
      Put (F, "lost");
      Commit (F, Ok);
      Assert (not Ok, "and nothing put to it commits");
   end Test_Unopenable;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Commit'Access, "commit puts every byte");
      Register_Routine (T, Test_Replace'Access, "commit replaces the old");
      Register_Routine (T, Test_Abandon'Access, "abandon keeps the old");
      Register_Routine (T, Test_Dropped'Access, "dropped is abandoned");
      Register_Routine (T, Test_Unopenable'Access, "an unopenable path");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Staged_Files (whole or not at all)");
   end Name;

end Tabula_Staged_Files_Tests;
