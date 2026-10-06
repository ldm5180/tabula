with AUnit.Assertions; use AUnit.Assertions;

with Tabula.Text_Lists;

--  The list of texts the writers take: what a caller writes as an
--  aggregate arrives as written, in order.

package body Tabula_Text_Lists_Tests is

   use AUnit.Test_Cases.Registration;

   procedure Test_Aggregate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Items : constant Tabula.Text_Lists.Vector := ["CS_COMMON", "", "a,b"];
      None  : constant Tabula.Text_Lists.Vector := [];
   begin
      Assert (Natural (Items.Length) = 3, "three texts");
      Assert (Items (1) = "CS_COMMON", "the first as written");
      Assert (Items (2) = "", "an empty one kept");
      Assert (Items (3) = "a,b", "the last as written");
      Assert (None.Is_Empty, "an empty aggregate is an empty list");
   end Test_Aggregate;

   overriding
   procedure Register_Tests (T : in out Test) is
   begin
      Register_Routine
        (T, Test_Aggregate'Access, "an aggregate is the list it writes");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Tabula.Text_Lists (lists of texts)");
   end Name;

end Tabula_Text_Lists_Tests;
