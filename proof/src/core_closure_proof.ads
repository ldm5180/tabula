with Tabula;
with Tabula.Decimals;
with Tabula.Toml_Text;

--  Withs every core unit so the whole SPARK closure is in gnatprove's
--  tree even when a unit temporarily has no other proof-side client.
--  No core unit is generic, so withing each here is all the analysis
--  needs.

package Core_Closure_Proof
  with SPARK_Mode
is

end Core_Closure_Proof;
