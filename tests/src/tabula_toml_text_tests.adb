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

   Quote : constant Character := '"';

   procedure Test_Quote_In_String (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert
        (String_Text ("a""b") = "" & Quote & "a\" & Quote & "b" & Quote,
         "a quote is escaped: " & String_Text ("a""b"));
   end Test_Quote_In_String;

   --  Every escape TOML requires in a basic string, and nothing else
   --  touched: UTF-8 passes as it came.
   procedure Test_Escapes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  S written as a basic string.
      function Quoted (S : String) return String
      is (Quote & S & Quote);
   begin
      Assert (String_Text ("") = Quoted (""), "the empty string");
      Assert (String_Text ("plain") = Quoted ("plain"), "plain text");
      Assert (String_Text ("a\b") = Quoted ("a\\b"), "a backslash");
      Assert
        (String_Text ("a" & ASCII.LF & "b") = Quoted ("a\nb"), "a line feed");
      Assert
        (String_Text (ASCII.CR & ASCII.HT & ASCII.BS & ASCII.FF)
         = Quoted ("\r\t\b\f"),
         "the named escapes");
      Assert
        (String_Text (ASCII.NUL & ASCII.ESC & ASCII.DEL)
         = Quoted ("\u0000\u001B\u007F"),
         "other controls by number: " & String_Text (ASCII.ESC & ""));
      Assert
        (String_Text ("caf" & Character'Val (16#C3#) & Character'Val (16#A9#))
         = Quoted ("caf" & Character'Val (16#C3#) & Character'Val (16#A9#)),
         "UTF-8 passes through");
   end Test_Escapes;

   procedure Test_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Key_Text ("entry_time") = "entry_time", "a bare key");
      Assert (Key_Text ("A-z_09") = "A-z_09", "every bare character");
      Assert (Key_Text ("a.b") = Quote & "a.b" & Quote, "a dot is quoted");
      Assert
        (Key_Text ("two words") = Quote & "two words" & Quote,
         "a blank is quoted");
      Assert (Key_Text ("") = Quote & Quote, "the empty key is quoted");
      Assert
        (Key_Text ("say""hi") = Quote & "say\" & Quote & "hi" & Quote,
         "and escaped as a string is");
   end Test_Keys;

   procedure Test_Number_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Is_Number_Text ("0.0314"), "a decimal");
      Assert (Is_Number_Text ("-12"), "a signed integer");
      Assert (Is_Number_Text ("+1.5"), "a plus sign");
      Assert (Is_Number_Text ("0"), "zero");
      Assert (Is_Number_Text ("-0.5"), "a leading zero alone");
      Assert (Is_Number_Text ("9223372036854775807"), "the largest integer");
      Assert
        (Is_Number_Text ("123456789.012345"), "fifteen significant digits");
      Assert
        (Is_Number_Text ("0.000123456789012345"),
         "leading zeros are not significant");

      Assert (not Is_Number_Text ("007"), "TOML forbids leading zeros");
      Assert (not Is_Number_Text ("00.5"), "in a decimal too");
      Assert
        (not Is_Number_Text ("9223372036854775808"),
         "an integer past 64 bits");
      Assert
        (not Is_Number_Text ("1234567890.123456"),
         "sixteen significant digits, more than a double holds");
      Assert (not Is_Number_Text ("1e3"), "an exponent");
      Assert (not Is_Number_Text ("1_000"), "an underscore");
      Assert (not Is_Number_Text ("nan"), "a special float");
      Assert (not Is_Number_Text (""), "nothing");
   end Test_Number_Text;

   procedure Test_Date_Time_Text (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Date_Text ((2020, 1, 2)) = "2020-01-02", "a date, padded");
      Assert (Date_Text ((1, 12, 31)) = "0001-12-31", "a year, padded");
      Assert (Time_Text ((9, 5, 0)) = "09:05:00", "a time, padded");
      Assert (Time_Text ((23, 59, 60)) = "23:59:60", "a leap second");
      Assert
        (Reads_As (Date_Text ((2024, 2, 29)), (2024, 2, 29)),
         "a date's text reads back as the date");
      Assert
        (Reads_As_Time (Time_Text ((16, 15, 7)), (16, 15, 7)),
         "and a time's as the time");
   end Test_Date_Time_Text;

   --  A TOML float as a plain decimal, exactly: the digits as written, the
   --  point moved by the exponent, no underscore, no plus sign.
   procedure Test_Decimal_Of (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Whether Literal reads as Want, saying what it read when not.
      procedure Check (Literal, Want : String) is
      begin
         Assert
           (Decimal_Of (Literal) = Want,
            Literal & " reads as " & Want & ", not " & Decimal_Of (Literal));
      end Check;
   begin
      Check ("1.5", "1.5");
      Check ("0.2621", "0.2621");
      Check ("0.02", "0.02");
      Check ("-0.02", "-0.02");
      Check ("+1.5", "1.5");
      Check ("1.50", "1.50");
      Check ("-0.0", "-0.0");
      Check ("1_000.000_25", "1000.00025");
      Check ("0.12345678901234567890", "0.12345678901234567890");
      Check ("1e2", "100");
      Check ("1E+2", "100");
      Check ("1.5e3", "1500");
      Check ("1.25e1", "12.5");
      Check ("12.5e-1", "1.25");
      Check ("1e-2", "0.01");
      Check ("-1.5e-3", "-0.0015");
      Check ("100e-2", "1.00");
      Check ("0.5e1", "5");
      Check ("0.05e2", "5");
      Check ("0e0", "0");
      Check ("0.0e5", "0");
      Check ("1e0_1", "10");
      Check ("6.626e-34", "0.0000000000000000000000000000000006626");
      Check ("1", "");
      Check ("-7", "");
      Check ("1.", "");
      Check (".5", "");
      Check ("01.5", "");
      Check ("1__0.5", "");
      Check ("_1.5", "");
      Check ("1.5_", "");
      Check ("1._5", "");
      Check ("1.5e", "");
      Check ("1.5e+", "");
      Check ("1e99999", "");
      Check ("+-1.5", "");
      Check ("inf", "");
      Check ("nan", "");
      Check ("1.5x", "");
      Check ("", "");
   end Test_Decimal_Of;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine (T, Test_Calendar'Access, "which dates are real");
      Register_Routine (T, Test_Date_Text'Access, "a date's text");
      Register_Routine (T, Test_Time_Text'Access, "a time's text");
      Register_Routine
        (T, Test_Quote_In_String'Access, "a quote in a string is escaped");
      Register_Routine (T, Test_Escapes'Access, "a basic string's escapes");
      Register_Routine (T, Test_Keys'Access, "a key, bare or quoted");
      Register_Routine
        (T, Test_Number_Text'Access, "what the writer passes as a number");
      Register_Routine
        (T, Test_Date_Time_Text'Access, "a date's and a time's text");
      Register_Routine
        (T, Test_Decimal_Of'Access, "a float as a plain decimal, exactly");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Toml_Text (the text of TOML scalars)");
   end Name;

end Tabula_Toml_Text_Tests;
