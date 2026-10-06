--  The shape of a quoted exact decimal, checked before conversion so the
--  conversion cannot surprise, and a decimal or an integer as a whole
--  count of a scale's units: pure, proved free of runtime errors.

package Tabula.Decimals
  with SPARK_Mode
is

   --  True for an optionally-signed plain decimal -- [+|-]digits[.digits]
   --  -- the shape 'Value converts exactly and every price-like config
   --  knob uses.  Deliberately strict: no exponents, no based literals,
   --  no underscores; anything fancier in a quoted knob reads as
   --  malformed and falls back.
   function Is_Plain_Decimal (Text : String) return Boolean;

   --  The largest magnitude a scaled value may have.  The range is
   --  symmetric, so every value that fits has a negation that fits.
   Most : constant Long_Long_Integer := Long_Long_Integer'Last;

   subtype Scaled_Value is Long_Long_Integer range -Most .. Most;

   --  A value at a scale: Value is meaningful only when Fits.
   type Scaled_Read is record
      Fits  : Boolean := False;
      Value : Scaled_Value := 0;
   end record;

   --  Value times By, exactly; Fits is False when the product is
   --  outside Scaled_Value.
   function Scaled
     (Value : Long_Long_Integer; By : Positive) return Scaled_Read
   with
     Post =>
       (if Scaled'Result.Fits
        then Scaled'Result.Value = Value * Long_Long_Integer (By));

   --  Text times By, rounded to the nearest whole unit with a half away
   --  from zero, worked from the digits so no binary fraction intrudes:
   --  "0.2621" at a million is 262100 exactly.  Every digit counts, so
   --  a long fraction rounds as written.  Fits is False when the result
   --  is outside Scaled_Value.
   function Scaled (Text : String; By : Positive) return Scaled_Read
   with Pre => Is_Plain_Decimal (Text);

end Tabula.Decimals;
