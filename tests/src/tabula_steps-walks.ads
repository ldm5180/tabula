--  What a scenario walks in its table (sections.feature, knobs.feature):
--  the strings of an array, the numbers of an array at a scale, the
--  tables of an array of tables, or the table's own keys, and the items
--  checked.  A region of the registry: Offer takes this region's steps,
--  Reset starts a scenario, Phase names its state.

package Tabula_Steps.Walks is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Tabula_Steps.Walks;
