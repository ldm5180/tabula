with Fabula.Main;

with Tabula_Steps;

--  The feature runner: Fabula.Main over the crate's step registry, run
--  over tests/features/ by `make features` and `alr test`.

procedure Tabula_Features is new
  Fabula.Main
    (Steps     => Tabula_Steps.Steps,
     Step_Defs => Tabula_Steps.Step_Defs,
     Hook_Defs => Tabula_Steps.Hook_Defs,
     Execute   => Tabula_Steps.Execute,
     Run_Hook  => Tabula_Steps.Run_Hook);
