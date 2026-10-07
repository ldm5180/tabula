with Ada.Strings.Fixed;

with TOML;

package body Tabula.Config.Values is

   use Ada.Strings.Unbounded;

   --  What the value V is.
   function Kind_Of (V : TOML.TOML_Value) return Value_Kind
   is (case TOML.Kind (V) is
         when TOML.TOML_Table           => A_Table,
         when TOML.TOML_Array           => An_Array,
         when TOML.TOML_String          => A_Text,
         when TOML.TOML_Integer         => An_Integer,
         when TOML.TOML_Float           => A_Decimal,
         when TOML.TOML_Boolean         => A_Flag,
         when TOML.TOML_Offset_Datetime => An_Offset_Datetime,
         when TOML.TOML_Local_Datetime  => A_Local_Datetime,
         when TOML.TOML_Local_Date      => A_Date,
         when TOML.TOML_Local_Time      => A_Time);

   --  The text of the value V: a string as it reads, an integer as its
   --  decimal digits, a flag as true or false.
   function Text_Of (V : TOML.TOML_Value) return String
   is (case Kind_Of (V) is
         when A_Text     => TOML.As_String (V),
         when An_Integer =>
           Ada.Strings.Fixed.Trim
             (TOML.As_Integer (V)'Image, Ada.Strings.Left),
         when A_Flag     => (if TOML.As_Boolean (V) then "true" else "false"),
         when others     => "");

   --  Hand V, read from T under Key, to Visitor.
   procedure Visit
     (T       : Table;
      Key     : String;
      V       : TOML.TOML_Value;
      Visitor : in out Value_Visitor'Class) is
   begin
      Visitor.Visit_Value (Key, Kind_Of (V), Text_Of (V), Within (T, V));
   end Visit;

   procedure Each_Value (T : Table; Visitor : in out Value_Visitor'Class) is
   begin
      if TOML.Is_Null (T.Value) then
         return;
      end if;
      case TOML.Kind (T.Value) is
         when TOML.TOML_Table =>
            for E of Written_Entries (T.Value) loop
               Visit (T, To_String (E.Key), E.Value, Visitor);
            end loop;

         when TOML.TOML_Array =>
            for I in 1 .. TOML.Length (T.Value) loop
               Visit (T, "", TOML.Item (T.Value, I), Visitor);
            end loop;

         when others          =>
            null;
      end case;
   end Each_Value;

end Tabula.Config.Values;
