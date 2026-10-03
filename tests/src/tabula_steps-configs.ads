--  Where a scenario's table comes from (every feature): a config given
--  as a doc string, or a section of it; and what that table complained
--  about.  A region of the registry: Offer takes this
--  region's steps, Reset starts a scenario, Phase names its state.

package Tabula_Steps.Configs is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

   --  Whether a config was given, so a table is in hand to read from.
   function Holds_Table return Boolean;

end Tabula_Steps.Configs;
