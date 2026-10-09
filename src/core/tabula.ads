--  Tabula: tables in and out -- TOML read with typed getters that fall
--  back and warn (Tabula.Config) and written in order (Tabula.Emit), and
--  CSV read by rows and written (Tabula.Csv), over a SPARK-proven core.
--  Text in, text out, and nothing raises: a config file can degrade a
--  run, never crash it.  The calendar values a TOML document holds are
--  declared here, so the reader and the writer share them, and so is
--  what a UTF-8 continuation is, which both count codepoints by.

package Tabula
  with Pure, SPARK_Mode
is

   --  The last year a TOML local date may name.
   Last_Year : constant := 9999;

   subtype Year_Number is Positive range 1 .. Last_Year;
   subtype Month_Number is Positive range 1 .. 12;
   subtype Day_Number is Positive range 1 .. 31;

   --  A calendar date, as a TOML local date writes it (2020-01-01).  Its
   --  day may be one its month lacks; Tabula.Toml_Text.Is_Calendar_Date
   --  says whether it is real.
   type Date is record
      Year  : Year_Number := Year_Number'First;
      Month : Month_Number := Month_Number'First;
      Day   : Day_Number := Day_Number'First;
   end record;

   subtype Hour_Number is Natural range 0 .. 23;
   subtype Minute_Number is Natural range 0 .. 59;

   --  A second of a minute; 60 is a leap second, which TOML allows.
   subtype Second_Number is Natural range 0 .. 60;

   --  A time of day to the second, as a TOML local time writes it
   --  (09:30:00).
   type Time_Of_Day is record
      Hour   : Hour_Number := 0;
      Minute : Minute_Number := 0;
      Second : Second_Number := 0;
   end record;

   --  Whether the byte C continues a UTF-8 codepoint rather than begins
   --  one: 2#10xx_xxxx#.
   function Continues_Codepoint (C : Character) return Boolean
   is (Character'Pos (C) in 16#80# .. 16#BF#);

end Tabula;
