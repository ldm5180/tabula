--  The text of TOML scalars: which texts are which scalar, and what each
--  reads as.  Pure, proved free of runtime errors.

package Tabula.Toml_Text
  with SPARK_Mode
is

   --  Whether D is a day the Gregorian calendar has: its day is within
   --  its month, February the 29th only in a leap year.
   function Is_Calendar_Date (D : Date) return Boolean;

   --  A date read from text: Value is meaningful only when Ok.
   type Date_Read is record
      Ok    : Boolean := False;
      Value : Date;
   end record;

   --  A time read from text: Value is meaningful only when Ok.
   type Time_Read is record
      Ok    : Boolean := False;
      Value : Time_Of_Day;
   end record;

   --  Text as a TOML local date, YYYY-MM-DD and nothing else, of a day
   --  the calendar has.
   function Date_Of (Text : String) return Date_Read
   with
     Post =>
       (if Date_Of'Result.Ok then Is_Calendar_Date (Date_Of'Result.Value));

   --  Text as a TOML local time to the second, HH:MM:SS and nothing
   --  else: a fraction of a second is not one.
   function Time_Of (Text : String) return Time_Read;

end Tabula.Toml_Text;
