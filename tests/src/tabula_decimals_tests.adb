with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Decimals; use Tabula.Decimals;

--  The shape check's absence-of-runtime-error story is carried by the
--  proof; what lives here is which shapes count as plain decimals.

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

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Shapes'Access, "which shapes are plain decimals");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Decimals (quoted-decimal shape)");
   end Name;

end Tabula_Decimals_Tests;
