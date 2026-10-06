with GNAT.OS_Lib;

package body Tabula.Staged_Files is

   use Ada.Streams.Stream_IO;
   use Ada.Strings.Unbounded;

   --  What the staging file's name adds to the path's.
   Staging_Suffix : constant String := ".tmp";

   function Staging (F : Staged_File) return String
   is (To_String (F.Path) & Staging_Suffix);

   procedure Abandon (F : in out Staged_File) is
   begin
      F.Used := 0;
      if Is_Open (F.File) then
         Delete (F.File);
      end if;
   exception
      when others =>
         --  The staging file could not be removed; nothing else is left
         --  to do, and abandoning must never raise.
         null;
   end Abandon;

   procedure Open (F : in out Staged_File; Path : String; Ok : out Boolean) is
   begin
      Abandon (F);
      F.Path := To_Unbounded_String (Path);
      F.Failed := False;
      Create (F.File, Out_File, Staging (F));
      Ok := True;
   exception
      when others =>
         F.Failed := True;
         Ok := False;
   end Open;

   --  Text straight to the file; a failure is remembered.
   procedure Write (F : in out Staged_File; Text : String) is
   begin
      String'Write (Stream (F.File), Text);
   exception
      when others =>
         F.Failed := True;
   end Write;

   procedure Flush (F : in out Staged_File) is
   begin
      Write (F, F.Buffer (1 .. F.Used));
      F.Used := 0;
   end Flush;

   procedure Put (F : in out Staged_File; Text : String) is
   begin
      if F.Failed or else not Is_Open (F.File) then
         return;
      elsif Text'Length > Buffer_Size - F.Used then
         Flush (F);
      end if;
      if Text'Length > Buffer_Size then
         Write (F, Text);
      else
         F.Buffer (F.Used + 1 .. F.Used + Text'Length) := Text;
         F.Used := F.Used + Text'Length;
      end if;
   end Put;

   --  Remove the closed staging file, if it is there; never raises.
   procedure Drop_Staging (F : Staged_File) is
      Gone : Boolean;
   begin
      GNAT.OS_Lib.Delete_File (Staging (F), Gone);
   end Drop_Staging;

   --  Close F and move the staging file onto the path; Ok when both did.
   procedure Land (F : in out Staged_File; Ok : out Boolean) is
   begin
      Close (F.File);
      GNAT.OS_Lib.Rename_File (Staging (F), To_String (F.Path), Ok);
      if not Ok then
         Drop_Staging (F);
      end if;
   exception
      when others =>
         Drop_Staging (F);
         Ok := False;
   end Land;

   procedure Commit (F : in out Staged_File; Ok : out Boolean) is
   begin
      Ok := False;
      if not Is_Open (F.File) then
         return;
      end if;
      Flush (F);
      if F.Failed then
         Abandon (F);
      else
         Land (F, Ok);
      end if;
   end Commit;

   overriding
   procedure Finalize (F : in out Staged_File) is
   begin
      Abandon (F);
   end Finalize;

end Tabula.Staged_Files;
