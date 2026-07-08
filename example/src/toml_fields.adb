with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;

with Tabula.Config;

--  The whole consumer story on one sample: parse, read a section's
--  typed knobs with fallbacks, and watch a wrong-typed knob warn and
--  degrade instead of crashing.  Pure -- CI runs it; exits non-zero if
--  any reading comes back wrong, so it doubles as a smoke test of the
--  installed library.

procedure Toml_Fields is

   Sample : constant String :=
     "[trading]"
     & ASCII.LF
     & "dry_run = false"
     & ASCII.LF
     & "retries = 12"
     & ASCII.LF
     & "bump = ""0.05"""
     & ASCII.LF
     & "daily_max = ""oops""";

   Failed : Boolean := False;

   procedure Check (Label : String; Passed : Boolean) is
   begin
      Put_Line (Label & (if Passed then "" else "  <-- WRONG"));
      Failed := Failed or else not Passed;
   end Check;

   Root   : Tabula.Config.Table;
   Status : Tabula.Config.Load_Status;
   Error  : Unbounded_String;

   use type Tabula.Config.Load_Status;

begin
   Put_Line ("document:");
   Put_Line (Sample);
   New_Line;

   Tabula.Config.Parse
     (Sample, "demo config", Put_Line'Access, Root, Status, Error);
   if Status /= Tabula.Config.Loaded then
      Put_Line ("parse failed: " & To_String (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Trading : constant Tabula.Config.Table :=
        Tabula.Config.Section (Root, "trading");

      Dry_Run : constant Boolean :=
        Tabula.Config.Get (Trading, "dry_run", Fallback => True);
      Retries : constant Natural :=
        Tabula.Config.Get (Trading, "retries", Fallback => 3);
      Bump    : constant Long_Float :=
        Tabula.Config.Get (Trading, "bump", Fallback => 0.0);
      Daily   : constant Natural :=
        Tabula.Config.Get (Trading, "daily_max", Fallback => 2);
      Absent  : constant Natural :=
        Tabula.Config.Get (Trading, "warn_at", Fallback => 1);
   begin
      New_Line;
      Check ("dry_run   =" & Dry_Run'Image, Dry_Run = False);
      Check ("retries   =" & Retries'Image, Retries = 12);
      Check
        ("bump      =" & Bump'Image & " (quoted decimal, exact)", Bump = 0.05);
      Check
        ("daily_max ="
         & Daily'Image
         & " (wrong-typed: warned above,"
         & " fallback kept)",
         Daily = 2);
      Check
        ("warn_at   =" & Absent'Image & " (absent: silent fallback)",
         Absent = 1);
   end;

   if Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Toml_Fields;
