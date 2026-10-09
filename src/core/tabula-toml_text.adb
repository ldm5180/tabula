with Tabula.Decimals;

package body Tabula.Toml_Text
  with SPARK_Mode
is

   ---------------------------------------------------------------------
   --  The calendar.
   ---------------------------------------------------------------------

   --  A year that is a multiple of Century is a leap year only when it
   --  is also a multiple of Leap_Century.
   Leap_Every   : constant := 4;
   Century      : constant := 100;
   Leap_Century : constant := 400;

   February : constant Month_Number := 2;

   function Is_Leap (Year : Year_Number) return Boolean
   is (Year mod Leap_Every = 0
       and then (Year mod Century /= 0 or else Year mod Leap_Century = 0));

   function Days_In
     (Year : Year_Number; Month : Month_Number) return Day_Number
   is (case Month is
         when February       => (if Is_Leap (Year) then 29 else 28),
         when 4 | 6 | 9 | 11 => 30,
         when others         => 31);

   function Is_Calendar_Date (D : Date) return Boolean
   is (D.Day <= Days_In (D.Year, D.Month));

   ---------------------------------------------------------------------
   --  Fields of fixed width.
   ---------------------------------------------------------------------

   subtype Digit is Character range '0' .. '9';

   --  The widest field read: a year's four digits.
   Max_Width : constant := 4;

   subtype Field_Width is Positive range 1 .. Max_Width;

   --  Ten to the power of each width a field may have so far.
   Powers : constant array (0 .. Max_Width) of Positive :=
     [1, 10, 100, 1_000, 10_000];

   --  What Number_At answers for a field holding a non-digit.
   No_Number : constant Integer := -1;

   --  The number the Width digits at Offset in Text spell, or
   --  No_Number when one of them is not a digit.
   function Number_At
     (Text : String; Offset : Natural; Width : Field_Width) return Integer
   with
     Pre  => Offset <= Text'Length and then Width <= Text'Length - Offset,
     Post => Number_At'Result in No_Number .. Powers (Max_Width) - 1
   is
      Acc : Natural := 0;
      C   : Character;
   begin
      for I in 0 .. Width - 1 loop
         pragma Loop_Invariant (Acc < Powers (I));
         C := Text (Text'First + Offset + I);
         if C not in Digit then
            return No_Number;
         end if;
         Acc := Acc * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Acc;
   end Number_At;

   --  Whether Text holds Mark at Offset.
   function Mark_At
     (Text : String; Offset : Natural; Mark : Character) return Boolean
   is (Offset < Text'Length and then Text (Text'First + Offset) = Mark);

   ---------------------------------------------------------------------
   --  Dates and times.
   ---------------------------------------------------------------------

   --  The width of every field but a year.
   Pair : constant := 2;

   --  A text of three numbers at fixed places with a mark between each:
   --  YYYY-MM-DD or HH:MM:SS.  The second and third numbers are pairs.
   type Layout is record
      Length      : Positive;
      Mark        : Character;
      First_Width : Field_Width;
      Second_At   : Natural;
      Third_At    : Natural;
   end record;

   --  Whether L's fields follow one another, a mark between each, and
   --  the third ends the text.
   function Is_Layout (L : Layout) return Boolean
   is (L.Second_At = L.First_Width + 1
       and then L.Third_At = L.Second_At + Pair + 1
       and then L.Length = L.Third_At + Pair);

   Date_Layout : constant Layout := (10, '-', Max_Width, 5, 8);
   Time_Layout : constant Layout := (8, ':', Pair, 3, 6);

   --  The three numbers a text holds: each No_Number unless the whole
   --  text has the layout's shape and that field is digits.
   type Parts is record
      First, Second, Third : Integer := No_Number;
   end record;

   function Parts_Of (Text : String; L : Layout) return Parts
   with Pre => Is_Layout (L)
   is
   begin
      if Text'Length /= L.Length
        or else not Mark_At (Text, L.Second_At - 1, L.Mark)
        or else not Mark_At (Text, L.Third_At - 1, L.Mark)
      then
         return (others => No_Number);
      end if;
      return
        (First  => Number_At (Text, 0, L.First_Width),
         Second => Number_At (Text, L.Second_At, Pair),
         Third  => Number_At (Text, L.Third_At, Pair));
   end Parts_Of;

   function Date_Of (Text : String) return Date_Read is
      P : constant Parts := Parts_Of (Text, Date_Layout);
   begin
      if P.First not in Year_Number
        or else P.Second not in Month_Number
        or else P.Third not in Day_Number
        or else not Is_Calendar_Date ((P.First, P.Second, P.Third))
      then
         return (Ok => False, Value => <>);
      end if;
      return (Ok => True, Value => (P.First, P.Second, P.Third));
   end Date_Of;

   function Time_Of (Text : String) return Time_Read is
      P : constant Parts := Parts_Of (Text, Time_Layout);
   begin
      if P.First not in Hour_Number
        or else P.Second not in Minute_Number
        or else P.Third not in Second_Number
      then
         return (Ok => False, Value => <>);
      end if;
      return (Ok => True, Value => (P.First, P.Second, P.Third));
   end Time_Of;

   --  The digits of N, Width of them, zeros leading.
   function Padded (N : Natural; Width : Field_Width) return String
   with
     Pre  => N < Powers (Width),
     Post => Padded'Result'First = 1 and then Padded'Result'Length = Width
   is
      Result : String (1 .. Width);
      Rest   : Natural := N;
   begin
      for I in reverse Result'Range loop
         Result (I) := Character'Val (Character'Pos ('0') + Rest mod 10);
         Rest := Rest / 10;
      end loop;
      return Result;
   end Padded;

   function Date_Text (D : Date) return String
   is (Padded (D.Year, Max_Width)
       & Date_Layout.Mark
       & Padded (D.Month, Pair)
       & Date_Layout.Mark
       & Padded (D.Day, Pair));

   function Time_Text (T : Time_Of_Day) return String
   is (Padded (T.Hour, Pair)
       & Time_Layout.Mark
       & Padded (T.Minute, Pair)
       & Time_Layout.Mark
       & Padded (T.Second, Pair));

   --  The width of a time's milliseconds.
   Millisecond_Width : constant := 3;

   function Time_Text
     (T : Time_Of_Day; Millisecond : Millisecond_Number) return String
   is (Time_Text (T)
       & (if Millisecond = 0
          then ""
          else '.' & Padded (Millisecond, Millisecond_Width)));

   Minutes_Per_Hour : constant := 60;

   function Offset_Text (Offset : Offset_Minutes) return String
   is (if Offset = 0
       then "Z"
       else
         (if Offset < 0 then '-' else '+')
         & Padded (abs Offset / Minutes_Per_Hour, Pair)
         & Time_Layout.Mark
         & Padded (abs Offset mod Minutes_Per_Hour, Pair));

   ---------------------------------------------------------------------
   --  Strings and keys.
   ---------------------------------------------------------------------

   Quote       : constant Character := '"';
   Escape_Mark : constant Character := '\';

   --  What Named_Escape answers for a character with no named escape.
   No_Name : constant Character := ASCII.NUL;

   --  The letter after the backslash that writes C, or No_Name.
   function Named_Escape (C : Character) return Character
   is (case C is
         when ASCII.BS    => 'b',
         when ASCII.HT    => 't',
         when ASCII.LF    => 'n',
         when ASCII.FF    => 'f',
         when ASCII.CR    => 'r',
         when Quote       => Quote,
         when Escape_Mark => Escape_Mark,
         when others      => No_Name);

   --  A control TOML lets into a basic string only as \uXXXX.
   function Needs_Number (C : Character) return Boolean
   is (C in ASCII.NUL .. ASCII.US | ASCII.DEL
       and then Named_Escape (C) = No_Name);

   Hex : constant String (1 .. 16) := "0123456789ABCDEF";

   --  How many values one hex digit holds.
   Hex_Base : constant := 16;

   --  C as \u00XX: Needs_Number has said it is below Hex_Base squared.
   function Numbered (C : Character) return String
   is (Escape_Mark
       & "u00"
       & Hex (Character'Pos (C) / Hex_Base + 1)
       & Hex (Character'Pos (C) mod Hex_Base + 1))
   with Pre => Needs_Number (C);

   --  C as it is written inside a basic string.
   function Escaped (C : Character) return String
   is (if Named_Escape (C) /= No_Name
       then [Escape_Mark, Named_Escape (C)]
       elsif Needs_Number (C)
       then Numbered (C)
       else [C])
   with Post => Escaped'Result'Length in 1 .. Max_Escape;

   function String_Text (Text : String) return String is
      Buffer : String (1 .. Max_Escape * Text'Length + 2) := [others => Quote];
      Last   : Positive := 1;
   begin
      for I in Text'Range loop
         pragma
           Loop_Invariant
             (Last in I - Text'First + 1 .. Max_Escape * (I - Text'First) + 1);
         declare
            E : constant String := Escaped (Text (I));
         begin
            Buffer (Last + 1 .. Last + E'Length) := E;
            Last := Last + E'Length;
         end;
      end loop;
      Last := Last + 1;
      Buffer (Last) := Quote;
      return Buffer (1 .. Last);
   end String_Text;

   function Is_Bare_Key_Character (C : Character) return Boolean
   is (C in 'A' .. 'Z' | 'a' .. 'z' | Digit | '_' | '-');

   function Key_Text (Key : String) return String
   is (if Key'Length > 0
         and then (for all C of Key => Is_Bare_Key_Character (C))
       then Key
       else String_Text (Key));

   function Width (Text : String) return Natural is
      Count : Natural := 0;
   begin
      for I in Text'Range loop
         if not Continues_Codepoint (Text (I)) then
            Count := Count + 1;
         end if;
         pragma Loop_Invariant (Count <= I - Text'First + 1);
      end loop;
      return Count;
   end Width;

   ---------------------------------------------------------------------
   --  Numbers.
   ---------------------------------------------------------------------

   function Has_Point (Text : String) return Boolean
   is (for some C of Text => C = '.');

   --  Whether Text's integer part opens with a zero another digit
   --  follows: 007 and 00.5, which TOML forbids.
   function Leads_With_Zero (Text : String) return Boolean is
      First : Positive;
   begin
      if Text'Length < 2 then
         return False;
      end if;
      First :=
        (if Text (Text'First) in '+' | '-'
         then Text'First + 1
         else Text'First);
      return
        First < Text'Last
        and then Text (First) = '0'
        and then Text (First + 1) in Digit;
   end Leads_With_Zero;

   --  How many digits Text holds from its first non-zero one on.
   function Significant_Digits (Text : String) return Natural is
      Count   : Natural := 0;
      Started : Boolean := False;
   begin
      for I in Text'Range loop
         pragma Loop_Invariant (Count <= I - Text'First);
         Started := Started or else Text (I) in '1' .. '9';
         if Started and then Text (I) in Digit then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Significant_Digits;

   function Is_Number_Text (Text : String) return Boolean
   is (Decimals.Is_Plain_Decimal (Text)
       and then not Leads_With_Zero (Text)
       and then (if Has_Point (Text)
                 then Significant_Digits (Text) <= Max_Float_Digits
                 else Decimals.Scaled (Text, 1).Fits));

   ---------------------------------------------------------------------
   --  A float as a plain decimal.
   ---------------------------------------------------------------------

   Group_Mark : constant Character := '_';
   Point_Mark : constant Character := '.';

   --  Whether Text is digits a single underscore may group: a digit
   --  first and last, and an underscore only before a digit.
   function Is_Digit_Group (Text : String) return Boolean
   is (Text'Length > 0
       and then Text (Text'First) in Digit
       and then Text (Text'Last) in Digit
       and then (for all I in Text'Range =>
                   Text (I) in Digit
                   or else (Text (I) = Group_Mark
                            and then I < Text'Last
                            and then Text (I + 1) in Digit)));

   --  Whether Text is a float's whole part: a digit group with no
   --  leading zero.
   function Is_Whole_Part (Text : String) return Boolean
   is (Is_Digit_Group (Text)
       and then (Text'Length = 1 or else Text (Text'First) /= '0'));

   --  Whether C is a sign.
   function Is_Sign (C : Character) return Boolean
   is (C in '+' | '-');

   --  The place of Text's first A or B from From on, or 0 when none.
   function Index_Of
     (Text : String; From : Positive; A, B : Character) return Natural
   with
     Post =>
       Index_Of'Result = 0
       or else Index_Of'Result in Integer'Max (From, Text'First) .. Text'Last
   is
   begin
      for I in Integer'Max (From, Text'First) .. Text'Last loop
         if Text (I) = A or else Text (I) = B then
            return I;
         end if;
      end loop;
      return 0;
   end Index_Of;

   --  An exponent read from its text: Value is meaningful only when Ok.
   type Exponent_Read is record
      Ok    : Boolean := False;
      Value : Integer range -Max_Exponent .. Max_Exponent := 0;
   end record;

   --  The value of the digit group Text, or Max_Exponent + 1 when it is
   --  more than Max_Exponent.
   function Group_Value (Text : String) return Natural
   with Post => Group_Value'Result <= Max_Exponent + 1
   is
      Acc : Natural := 0;
   begin
      for I in Text'Range loop
         pragma Loop_Invariant (Acc <= Max_Exponent);
         if Text (I) in Digit then
            Acc := Acc * 10 + (Character'Pos (Text (I)) - Character'Pos ('0'));
            if Acc > Max_Exponent then
               return Max_Exponent + 1;
            end if;
         end if;
      end loop;
      return Acc;
   end Group_Value;

   --  Text, an exponent after its e -- an optional sign, then a digit
   --  group, leading zeros allowed -- as its value.
   function Exponent_Of (Text : String) return Exponent_Read
   with Pre => Text'Last < Positive'Last
   is
      Signed : constant Boolean :=
        Text'Length > 0 and then Is_Sign (Text (Text'First));
      Group  : constant String :=
        (if Signed then Text (Text'First + 1 .. Text'Last) else Text);
      Value  : Natural;
   begin
      if not Is_Digit_Group (Group) then
         return (Ok => False, Value => 0);
      end if;
      Value := Group_Value (Group);
      if Value > Max_Exponent then
         return (Ok => False, Value => 0);
      elsif Signed and then Text (Text'First) = '-' then
         return (Ok => True, Value => -Value);
      end if;
      return (Ok => True, Value => Value);
   end Exponent_Of;

   --  The digits of Text, its underscores dropped.
   function Digits_Of (Text : String) return String
   with
     Post =>
       Digits_Of'Result'First = 1
       and then Digits_Of'Result'Length <= Text'Length
       and then (if Text'Length > 0 and then Text (Text'First) /= Group_Mark
                 then Digits_Of'Result'Length > 0)
   is
      Result : String (1 .. Text'Length) := [others => '0'];
      Last   : Natural := 0;
   begin
      for I in Text'Range loop
         pragma Loop_Invariant (Last <= I - Text'First);
         pragma
           Loop_Invariant
             (if I > Text'First and then Text (Text'First) /= Group_Mark
                then Last > 0);
         if Text (I) /= Group_Mark then
            Last := Last + 1;
            Result (Last) := Text (I);
         end if;
      end loop;
      return Result (1 .. Last);
   end Digits_Of;

   --  N zeros.
   function Zeros (N : Natural) return String
   is ([1 .. N => '0'])
   with Post => Zeros'Result'Length = N;

   --  The longest run of figures Placed takes.
   Max_Figures : constant := Max_Literal_Length;

   --  Figures with the point after the first Point of them: zeros lead
   --  when Point is under one, and follow, with no point, when Point is
   --  past the last.
   function Placed (Figures : String; Point : Integer) return String
   is (if Point <= 0
       then "0." & Zeros (-Point) & Figures
       elsif Point >= Figures'Length
       then Figures & Zeros (Point - Figures'Length)
       else
         Figures (Figures'First .. Figures'First + Point - 1)
         & Point_Mark
         & Figures (Figures'First + Point .. Figures'Last))
   with
     Pre  =>
       Figures'First = 1
       and then Figures'Length in 1 .. Max_Figures
       and then Point in 1 - Max_Exponent .. Figures'Length + Max_Exponent,
     Post => Placed'Result'Length <= Figures'Length + Max_Exponent + 2;

   --  Text without the zeros that lead its whole part, one kept.
   function Without_Leading_Zeros (Text : String) return String
   with
     Pre  => Text'Length > 0,
     Post => Without_Leading_Zeros'Result'Length <= Text'Length
   is
      First : Positive := Text'First;
   begin
      while First < Text'Last
        and then Text (First) = '0'
        and then Text (First + 1) /= Point_Mark
      loop
         pragma Loop_Invariant (First in Text'Range);
         pragma Loop_Variant (Increases => First);
         First := First + 1;
      end loop;
      return Text (First .. Text'Last);
   end Without_Leading_Zeros;

   --  Whole and Fraction, a float's parts, shifted by Exponent places.
   function Shifted
     (Whole, Fraction : String; Exponent : Integer) return String
   with
     Pre  =>
       Is_Whole_Part (Whole)
       and then Whole'Length + Fraction'Length <= Max_Figures
       and then Exponent in -Max_Exponent .. Max_Exponent,
     Post =>
       Shifted'Result'Length
       <= Whole'Length + Fraction'Length + Max_Exponent + 2
   is
      Lead    : constant String := Digits_Of (Whole);
      Figures : constant String := Lead & Digits_Of (Fraction);
   begin
      return Without_Leading_Zeros (Placed (Figures, Lead'Length + Exponent));
   end Shifted;

   function Decimal_Of (Literal : String) return String is
      S          : constant String (1 .. Literal'Length) := Literal;
      Start      : constant Positive :=
        (if S'Length > 0 and then Is_Sign (S (1)) then 2 else 1);
      E          : constant Natural := Index_Of (S, Start, 'e', 'E');
      Last       : constant Natural := (if E = 0 then S'Last else E - 1);
      Point      : constant Natural :=
        Index_Of (S (1 .. Last), Start, '.', '.');
      Whole_Last : constant Natural := (if Point = 0 then Last else Point - 1);
      Exponent   : constant Exponent_Read :=
        (if E = 0 then (True, 0) else Exponent_Of (S (E + 1 .. S'Last)));
      Sign       : constant String :=
        (if Start = 2 and then S (1) = '-' then "-" else "");
   begin
      if not Exponent.Ok
        or else (Point = 0 and then E = 0)
        or else not Is_Whole_Part (S (Start .. Whole_Last))
        or else (Point /= 0
                 and then not Is_Digit_Group (S (Point + 1 .. Last)))
      then
         return "";
      end if;
      return
        Sign
        & Shifted
            (S (Start .. Whole_Last),
             (if Point = 0 then "" else S (Point + 1 .. Last)),
             Exponent.Value);
   end Decimal_Of;

end Tabula.Toml_Text;
