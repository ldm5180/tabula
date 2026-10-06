--  What a scenario does with a CSV file (csv.feature): a file given or
--  absent, its rows read, and what the read came to checked -- the
--  rows by name and by position, and a refusal with its line.  A region
--  of the registry: Offer takes this region's steps, Reset starts a
--  scenario, Phase names its state.

package Tabula_Steps.Csv_Files is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Tabula_Steps.Csv_Files;
