--  Tabula: narrow TOML reading for configuration files -- typed knob
--  getters with fallbacks over the ada_toml parser (Tabula.Config) and a
--  SPARK-proven decimal shape check (Tabula.Decimals) gating the quoted
--  exact-decimal form.  Absence is silent (the caller's default stands);
--  a present-but-wrong value warns through the caller's handler and
--  falls back -- a config file can degrade a run, never crash it.

package Tabula
  with Pure, SPARK_Mode
is

end Tabula;
