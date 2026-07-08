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

end Tabula.Decimals;
