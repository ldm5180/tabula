with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Decimals; use Tabula.Decimals;

--  The absence-of-runtime-error story is carried by the proof; what
--  lives here is which shapes count as plain decimals, and what a
--  decimal or an integer comes to at a scale.

package body Tabula_Decimals_Tests is

   use AUnit.Test_Cases.Registration;

   procedure Test_Shapes (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Is_Plain_Decimal ("0.02"), "the motivating price shape");
      Assert (Is_Plain_Decimal ("42"), "bare digits");
      Assert (Is_Plain_Decimal ("-1.5"), "signed decimal");
      Assert (Is_Plain_Decimal ("+7"), "plus-signed digits");

      Assert (not Is_Plain_Decimal (""), "empty");
      Assert (not Is_Plain_Decimal ("."), "lone point");
      Assert (not Is_Plain_Decimal (".5"), "no integer part");
      Assert (not Is_Plain_Decimal ("1."), "no fraction after the point");
      Assert (not Is_Plain_Decimal ("1.2.3"), "two points");
      Assert (not Is_Plain_Decimal ("1-2"), "sign not leading");
      Assert (not Is_Plain_Decimal ("-"), "sign alone");
      Assert (not Is_Plain_Decimal ("1e3"), "exponents are rejected");
      Assert (not Is_Plain_Decimal ("16#FF#"), "based literals are rejected");
      Assert (not Is_Plain_Decimal ("1_000"), "underscores are rejected");
      Assert (not Is_Plain_Decimal (" 1"), "blanks are rejected");
   end Test_Shapes;

   Most : constant Long_Long_Integer := Long_Long_Integer'Last;

   --  Whether Read fits and holds Value.
   function Holds
     (Read : Scaled_Read; Value : Long_Long_Integer) return Boolean
   is (Read.Fits and then Read.Value = Value);

   procedure Test_Scaled_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Holds (Scaled ("0.2621", 1_000_000), 262_100), "the motivating");
      Assert (Holds (Scaled ("42", 1), 42), "digits at a scale of one");
      Assert (Holds (Scaled ("+7", 3), 21), "a plus sign");
      Assert (Holds (Scaled ("-1.5", 10), -15), "a minus sign");
      Assert (Holds (Scaled ("0.02", 7), 0), "0.14 rounds down");
      Assert (Holds (Scaled ("0.125", 100), 13), "a tie rounds up");
      Assert (Holds (Scaled ("-0.125", 100), -13), "and away from zero");
      Assert (Holds (Scaled ("0.12499999", 100), 12), "under a tie, down");
      Assert (Holds (Scaled ("0.5", 1), 1), "a half rounds up");
      Assert (Holds (Scaled ("0.49", 1), 0), "under a half, down");
      Assert
        (Holds (Scaled ("1.000000000000000000000000001", 1_000), 1_000),
         "a fraction longer than any integer still scales");
      Assert
        (Holds (Scaled ("0.333333333333333333333", 3), 1),
         "and its digits all count");
      Assert
        (Holds (Scaled ("0.0000001", Positive'Last), 215),
         "the largest scale: 214.7483647 rounds to 215");
      Assert
        (Holds (Scaled ("9223372036854775807", 1), Most), "the largest value");
      Assert
        (Holds (Scaled ("-9223372036854775807", 1), -Most),
         "and its negation");
      Assert
        (not Scaled ("9223372036854775808", 1).Fits,
         "one past the largest does not fit");
      Assert
        (not Scaled ("922337203685477580.8", 10).Fits,
         "nor does it by way of a fraction");
      Assert
        (not Scaled ("9223372036854775807.5", 1).Fits, "nor by rounding up");
      Assert
        (not Scaled ("99999999999999999999999", 1).Fits,
         "nor an integer part too long to hold");
      Assert
        (not Scaled ("1000000000000", 10_000_000).Fits,
         "nor a product too large");
   end Test_Scaled_Text;

   procedure Test_Scaled_Integer (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Holds (Scaled (7, 1_000), 7_000), "an integer is multiplied");
      Assert (Holds (Scaled (-7, 1_000), -7_000), "a negative one too");
      Assert (Holds (Scaled (0, Positive'Last), 0), "zero at any scale");
      Assert (Holds (Scaled (Most, 1), Most), "the largest at one");
      Assert (Holds (Scaled (-Most, 1), -Most), "its negation");
      Assert
        (not Scaled (Long_Long_Integer'First, 1).Fits,
         "the one value with no negation does not fit");
      Assert (not Scaled (Most / 2 + 1, 2).Fits, "past the largest");
      Assert (not Scaled (-(Most / 2 + 1), 2).Fits, "past the smallest");
   end Test_Scaled_Integer;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Shapes'Access, "which shapes are plain decimals");
      Register_Routine
        (T, Test_Scaled_Text'Access, "a decimal at a scale, from its digits");
      Register_Routine
        (T, Test_Scaled_Integer'Access, "an integer at a scale");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Decimals (decimal shape and scale)");
   end Name;

end Tabula_Decimals_Tests;
