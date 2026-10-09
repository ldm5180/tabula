--  What a scenario writes (emit.feature): a document begun, plain or
--  with its keys aligned, its comments, headers and keys written, and
--  the document saved; then whether it saved, the text it saved, and
--  what it refused.  A region of the registry: Offer takes this
--  region's steps, Reset starts a scenario, Phase names its state.

package Tabula_Steps.Emits is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Tabula_Steps.Emits;
