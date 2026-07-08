--  The shape of a quoted exact decimal, checked before conversion so the
--  conversion cannot surprise: pure, proved free of runtime errors.

package Tabula.Decimals
  with SPARK_Mode
is

   --  True for an optionally-signed plain decimal -- [+|-]digits[.digits]
   --  -- the shape 'Value converts exactly and every price-like config
   --  knob uses.  Deliberately strict: no exponents, no based literals,
   --  no underscores; anything fancier in a quoted knob reads as
   --  malformed and falls back.
   function Is_Plain_Decimal (Text : String) return Boolean;

end Tabula.Decimals;
