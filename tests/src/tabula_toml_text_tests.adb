with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Toml_Text; use Tabula.Toml_Text;

--  The absence-of-runtime-error story is carried by the proof; what
--  lives here is which texts are which TOML scalars, and what each
--  reads as.

package body Tabula_Toml_Text_Tests is

   use AUnit.Test_Cases.Registration;
   use type Tabula.Date;
   use type Tabula.Time_Of_Day;

   --  Whether Text reads as the date Year-Month-Day.
   function Reads_As (Text : String; Want : Tabula.Date) return Boolean
   is (Date_Of (Text).Ok and then Date_Of (Text).Value = Want);

   function Reads_As_Time
     (Text : String; Want : Tabula.Time_Of_Day) return Boolean
   is (Time_Of (Text).Ok and then Time_Of (Text).Value = Want);

   procedure Test_Calendar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Is_Calendar_Date ((2024, 2, 29)), "a leap day");
      Assert (not Is_Calendar_Date ((2023, 2, 29)), "not in a common year");
      Assert (Is_Calendar_Date ((2000, 2, 29)), "a fourth century leaps");
      Assert (not Is_Calendar_Date ((1900, 2, 29)), "another century not");
      Assert (Is_Calendar_Date ((2023, 2, 28)), "February's last");
      Assert (Is_Calendar_Date ((2023, 4, 30)), "April has 30 days");
      Assert (not Is_Calendar_Date ((2023, 4, 31)), "and not 31");
      Assert (Is_Calendar_Date ((2023, 12, 31)), "December has 31");
   end Test_Calendar;

   procedure Test_Date_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Reads_As ("2020-01-01", (2020, 1, 1)), "a date");
      Assert (Reads_As ("0001-12-31", (1, 12, 31)), "the first year");
      Assert (Reads_As ("9999-02-28", (9999, 2, 28)), "the last year");
      Assert (not Date_Of ("0000-01-01").Ok, "no year zero");
      Assert (not Date_Of ("2021-02-29").Ok, "a day not on the calendar");
      Assert (not Date_Of ("2021-13-01").Ok, "a thirteenth month");
      Assert (not Date_Of ("2021-00-01").Ok, "a month zero");
      Assert (not Date_Of ("2021-01-00").Ok, "a day zero");
      Assert (not Date_Of ("2021-1-01").Ok, "a short month");
      Assert (not Date_Of ("2021/01/01").Ok, "other separators");
      Assert (not Date_Of ("2021-01-01T").Ok, "anything after it");
      Assert (not Date_Of ("21-01-01").Ok, "a short year");
      Assert (not Date_Of ("+021-01-01").Ok, "a sign");
      Assert (not Date_Of ("").Ok, "nothing");
   end Test_Date_Text;

   procedure Test_Time_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Reads_As_Time ("09:30:00", (9, 30, 0)), "a time");
      Assert (Reads_As_Time ("00:00:00", (0, 0, 0)), "midnight");
      Assert (Reads_As_Time ("23:59:60", (23, 59, 60)), "a leap second");
      Assert (not Time_Of ("24:00:00").Ok, "no hour 24");
      Assert (not Time_Of ("12:60:00").Ok, "no minute 60");
      Assert (not Time_Of ("12:00:61").Ok, "no second 61");
      Assert (not Time_Of ("9:30:00").Ok, "a short hour");
      Assert (not Time_Of ("09:30").Ok, "no seconds");
      Assert (not Time_Of ("09:30:00.5").Ok, "a fraction of a second");
      Assert (not Time_Of ("09-30-00").Ok, "other separators");
      Assert (not Time_Of ("").Ok, "nothing");
   end Test_Time_Text;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Calendar'Access, "which dates are real");
      Register_Routine (T, Test_Date_Text'Access, "a date's text");
      Register_Routine (T, Test_Time_Text'Access, "a time's text");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Toml_Text (the text of TOML scalars)");
   end Name;

end Tabula_Toml_Text_Tests;
