--  The text of TOML scalars, both ways: which texts are which scalar
--  and what each reads as, and the text a key or a value is written as.
--  Pure, proved free of runtime errors.

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

   --  The longest text one character is written as in a basic string:
   --  \uXXXX.
   Max_Escape : constant := 6;

   --  The longest text String_Text takes: Max_Escape characters for each
   --  it takes, and two quotes, still fit a String.
   Max_Text_Length : constant := (Natural'Last - 2) / Max_Escape;

   --  Text as a TOML basic string: in double quotes, a quote and a
   --  backslash escaped, a control written by its named escape (\b \t
   --  \n \f \r) or else as \uXXXX.  Every other byte passes as it
   --  came, UTF-8 among them.
   function String_Text (Text : String) return String
   with
     Pre  => Text'Length <= Max_Text_Length,
     Post =>
       String_Text'Result'Length
       in Text'Length + 2 .. Max_Escape * Text'Length + 2;

   --  Key as a TOML key: bare when it is letters, digits, underscores
   --  and dashes, and a basic string otherwise -- so a.b stays one key
   --  and never becomes a dotted path.
   function Key_Text (Key : String) return String
   with Pre => Key'Length <= Max_Text_Length;

   --  The most significant digits a decimal written as a TOML float may
   --  have: as many as a double holds exactly, so it reads back as
   --  written.
   Max_Float_Digits : constant := 15;

   --  Whether Text is a decimal the writer passes through unquoted, as
   --  a TOML integer or float that reads back to the value written: a
   --  plain decimal (Tabula.Decimals.Is_Plain_Decimal) with no leading
   --  zero, an integer within 64 bits, a decimal with a point of at most
   --  Max_Float_Digits significant digits.
   function Is_Number_Text (Text : String) return Boolean;

   --  D as a TOML local date, YYYY-MM-DD.
   function Date_Text (D : Date) return String;

   --  T as a TOML local time, HH:MM:SS.
   function Time_Text (T : Time_Of_Day) return String;

end Tabula.Toml_Text;
