with Ada.Containers.Indefinite_Vectors;

--  Lists of texts, which the writers take and the readers hand over: a
--  caller writes one as an aggregate, ["CS_COMMON", "IN_ROTH"].

package Tabula.Text_Lists is new
  Ada.Containers.Indefinite_Vectors
    (Index_Type   => Positive,
     Element_Type => String);
