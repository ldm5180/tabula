package body Tabula.Decimals
  with SPARK_Mode
is

   function Is_Plain_Decimal (Text : String) return Boolean is
      Seen_Point  : Boolean := False;
      Int_Digits  : Natural := 0;
      Frac_Digits : Natural := 0;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for I in Text'Range loop
         pragma
           Loop_Invariant
             (Int_Digits <= I - Text'First
                and then Frac_Digits <= I - Text'First);

         case Text (I) is
            when '+' | '-'  =>
               if I /= Text'First then
                  return False;
               end if;

            when '.'        =>
               --  One point, and only after the integer part ("." and
               --  ".5" are not decimals).
               if Seen_Point or else Int_Digits = 0 then
                  return False;
               end if;
               Seen_Point := True;

            when '0' .. '9' =>
               if Seen_Point then
                  Frac_Digits := Frac_Digits + 1;
               else
                  Int_Digits := Int_Digits + 1;
               end if;

            when others     =>
               return False;
         end case;
      end loop;

      --  Digits before the point, and -- when there is a point -- after
      --  it too ("1." is not a decimal).
      return Int_Digits > 0 and then (not Seen_Point or else Frac_Digits > 0);
   end Is_Plain_Decimal;

   Base : constant := 10;

   subtype Digit_Value is Long_Long_Integer range 0 .. Base - 1;

   --  C as a digit; zero for any other character, which a plain
   --  decimal never holds where a digit is read.
   function Digit (C : Character) return Digit_Value
   is (if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0') else 0);

   Does_Not_Fit : constant Scaled_Read := (Fits => False, Value => 0);

   function Scaled
     (Value : Long_Long_Integer; By : Positive) return Scaled_Read
   is
      Scale : constant Long_Long_Integer := Long_Long_Integer (By);
   begin
      if Value = Long_Long_Integer'First or else abs Value > Most / Scale then
         return Does_Not_Fit;
      end if;
      return (Fits => True, Value => Value * Scale);
   end Scaled;

   --  What Point_Of answers for a decimal with no point.
   No_Point : constant Natural := 0;

   --  Where Text's point is, or No_Point.
   function Point_Of (Text : String) return Natural
   with
     Post => Point_Of'Result = No_Point or else Point_Of'Result in Text'Range
   is
   begin
      for I in Text'Range loop
         if Text (I) = '.' then
            return I;
         end if;
      end loop;
      return No_Point;
   end Point_Of;

   --  The digits of Text before its point as a whole number; Fits is
   --  False when they exceed Most.
   function Whole_Part (Text : String) return Scaled_Read
   with Post => Whole_Part'Result.Value >= 0
   is
      Acc : Scaled_Value := 0;
   begin
      for C of Text loop
         exit when C = '.';
         pragma Loop_Invariant (Acc >= 0);
         if C in '0' .. '9' then
            if Acc > (Most - Digit (C)) / Base then
               return Does_Not_Fit;
            end if;
            Acc := Acc * Base + Digit (C);
         end if;
      end loop;
      return (Fits => True, Value => Acc);
   end Whole_Part;

   --  The digits of Text after its point, as a fraction, times By and
   --  rounded with a half up: at most By.  The digits are taken from the
   --  last, each step keeping the whole part of what the digits so far
   --  come to (below By) and dropping a remainder that can no longer
   --  change the rounding; the first digit's step alone decides it.
   function Fraction_Part
     (Text : String; By : Positive) return Long_Long_Integer
   with Post => Fraction_Part'Result in 0 .. Long_Long_Integer (By)
   is
      Scale   : constant Long_Long_Integer := Long_Long_Integer (By);
      Point   : constant Natural := Point_Of (Text);
      Carry   : Long_Long_Integer := 0;
      Product : Long_Long_Integer;
      Half_Up : Boolean := False;
   begin
      if Point = No_Point then
         return 0;
      end if;
      for I in reverse Text'Range loop
         exit when I <= Point;
         pragma Loop_Invariant (Carry in 0 .. Scale - 1);
         Product := Digit (Text (I)) * Scale + Carry;
         Half_Up := Product mod Base >= Base / 2;
         Carry := Product / Base;
      end loop;
      return Carry + (if Half_Up then 1 else 0);
   end Fraction_Part;

   --  Magnitude with Text's sign.
   function Signed
     (Text : String; Magnitude : Scaled_Value) return Scaled_Value
   is (if Text'Length > 0 and then Text (Text'First) = '-'
       then -Magnitude
       else Magnitude);

   function Scaled (Text : String; By : Positive) return Scaled_Read is
      Whole : constant Scaled_Read := Whole_Part (Text);
      Units : constant Scaled_Read :=
        (if Whole.Fits then Scaled (Whole.Value, By) else Does_Not_Fit);
      Part  : constant Long_Long_Integer := Fraction_Part (Text, By);
   begin
      if not Units.Fits or else Units.Value > Most - Part then
         return Does_Not_Fit;
      end if;
      return (Fits => True, Value => Signed (Text, Units.Value + Part));
   end Scaled;

end Tabula.Decimals;
