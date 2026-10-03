--  What a scenario reads from its table (knobs.feature): a knob through
--  its typed getter, and the reading checked.  A region of the
--  registry: Offer takes this region's steps, Reset starts a scenario,
--  Phase names its state.

package Tabula_Steps.Knobs is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Tabula_Steps.Knobs;
