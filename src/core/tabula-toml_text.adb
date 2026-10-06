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
         if C not in '0' .. '9' then
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

end Tabula.Toml_Text;
