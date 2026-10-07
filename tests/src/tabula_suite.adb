with AUnit.Test_Cases;

with Tabula_Config_Tests;
with Tabula_Config_Values_Tests;
with Tabula_Csv_Scan_Tests;
with Tabula_Csv_Tests;
with Tabula_Decimals_Tests;
with Tabula_Emit_Tests;
with Tabula_Staged_Files_Tests;
with Tabula_Text_Lists_Tests;
with Tabula_Toml_Source_Tests;
with Tabula_Toml_Text_Tests;

package body Tabula_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        AUnit.Test_Suites.New_Suite;

      procedure Add (T : AUnit.Test_Cases.Test_Case_Access) is
      begin
         AUnit.Test_Suites.Add_Test (Result, T);
      end Add;
   begin
      Add (new Tabula_Decimals_Tests.Test);
      Add (new Tabula_Config_Tests.Test);
      Add (new Tabula_Config_Values_Tests.Test);
      Add (new Tabula_Toml_Text_Tests.Test);
      Add (new Tabula_Toml_Source_Tests.Test);
      Add (new Tabula_Text_Lists_Tests.Test);
      Add (new Tabula_Staged_Files_Tests.Test);
      Add (new Tabula_Emit_Tests.Test);
      Add (new Tabula_Csv_Scan_Tests.Test);
      Add (new Tabula_Csv_Tests.Test);
      return Result;
   end Suite;

end Tabula_Suite;
