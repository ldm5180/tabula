with Ada.Strings.Fixed;

with TOML;

with Tabula.Toml_Source;
with Tabula.Toml_Text;

package body Tabula.Config.Values is

   use Ada.Strings.Unbounded;
   use type TOML.Float_Kind;

   --  What the float F is.
   function Float_Kind_Of (F : TOML.Any_Float) return Value_Kind
   is (case F.Kind is
         when TOML.Regular  => A_Decimal,
         when TOML.NaN      => Not_A_Number,
         when TOML.Infinity => An_Infinity);

   --  What the value V is.
   function Kind_Of (V : TOML.TOML_Value) return Value_Kind
   is (case TOML.Kind (V) is
         when TOML.TOML_Table           => A_Table,
         when TOML.TOML_Array           => An_Array,
         when TOML.TOML_String          => A_Text,
         when TOML.TOML_Integer         => An_Integer,
         when TOML.TOML_Float           => Float_Kind_Of (TOML.As_Float (V)),
         when TOML.TOML_Boolean         => A_Flag,
         when TOML.TOML_Offset_Datetime => An_Offset_Datetime,
         when TOML.TOML_Local_Datetime  => A_Local_Datetime,
         when TOML.TOML_Local_Date      => A_Date,
         when TOML.TOML_Local_Time      => A_Time);

   --  The decimal the literal in Source at the place P spells, or "" when
   --  no literal is found there.
   function Literal_Decimal
     (Source : String; P : TOML.Source_Location) return String
   is
      Found : Toml_Source.Span;
   begin
      if Source'Length > Toml_Source.Max_Source_Length
        or else P.Line = 0
        or else P.Column = 0
      then
         return "";
      end if;
      Found := Toml_Source.Number_At (Source, P.Line, P.Column);
      if not Found.Found
        or else Found.Last - Found.First >= Toml_Text.Max_Literal_Length
      then
         return "";
      end if;
      return Toml_Text.Decimal_Of (Source (Found.First .. Found.Last));
   end Literal_Decimal;

   --  The text of the float F: its sign and its name.
   function Special_Text (F : TOML.Any_Float) return String
   is ((if F.Positive then "" else "-")
       & (if F.Kind = TOML.NaN then "nan" else "inf"))
   with Pre => F.Kind /= TOML.Regular;

   function Date_Text (D : TOML.Any_Local_Date) return String
   is (Toml_Text.Date_Text (To_Date (D)));

   function Time_Text (C : TOML.Any_Local_Time) return String
   is (Toml_Text.Time_Text (To_Time (C), Natural (C.Millisecond)));

   function Datetime_Text (D : TOML.Any_Local_Datetime) return String
   is (Date_Text (D.Date) & "T" & Time_Text (D.Time));

   --  What an offset date-time whose offset is unknown ends with.
   Unknown_Offset : constant String := "-00:00";

   function Offset_Datetime_Text (D : TOML.Any_Offset_Datetime) return String
   is (Datetime_Text (D.Datetime)
       & (if D.Unknown_Offset
          then Unknown_Offset
          else Toml_Text.Offset_Text (Integer (D.Offset))));

   --  The text of the value V, read from T: a string as it reads, an
   --  integer as its decimal digits, a decimal as the document wrote it
   --  (Toml_Text.Decimal_Of), a special float as its sign and name, a
   --  flag as true or false, and a date, time or date-time in its TOML
   --  form.
   function Text_Of (T : Table; V : TOML.TOML_Value) return String
   is (case Kind_Of (V) is
         when A_Text                     => TOML.As_String (V),
         when An_Integer                 =>
           Ada.Strings.Fixed.Trim
             (TOML.As_Integer (V)'Image, Ada.Strings.Left),
         when A_Decimal                  =>
           Literal_Decimal (To_String (T.Source), TOML.Location (V)),
         when Not_A_Number | An_Infinity => Special_Text (TOML.As_Float (V)),
         when A_Flag                     =>
           (if TOML.As_Boolean (V) then "true" else "false"),
         when A_Date                     => Date_Text (TOML.As_Local_Date (V)),
         when A_Time                     => Time_Text (TOML.As_Local_Time (V)),
         when A_Local_Datetime           =>
           Datetime_Text (TOML.As_Local_Datetime (V)),
         when An_Offset_Datetime         =>
           Offset_Datetime_Text (TOML.As_Offset_Datetime (V)),
         when A_Table | An_Array         => "");

   --  Hand V, read from T under Key, to Visitor; a decimal whose literal
   --  was not found in the document's text is complained of and skipped.
   procedure Visit
     (T       : Table;
      Key     : String;
      V       : TOML.TOML_Value;
      Visitor : in out Value_Visitor'Class)
   is
      Kind : constant Value_Kind := Kind_Of (V);
      Text : constant String := Text_Of (T, V);
   begin
      if Kind = A_Decimal and then Text = "" then
         Complain
           (T,
            "the float at "
            & TOML.Format_Location (TOML.Location (V))
            & " could not be read as written; skipped");
         return;
      end if;
      Visitor.Visit_Value (Key, Kind, Text, Within (T, V));
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

   --  The walk to a procedure: a visitor whose discriminant is the
   --  procedure, over the walk to a visitor.
   type Value_Process
     (Process :
        not null access procedure
          (Key : String; Kind : Value_Kind; Text : String; Item : Table))
   is limited new Value_Visitor with null record;

   overriding
   procedure Visit_Value
     (V    : in out Value_Process;
      Key  : String;
      Kind : Value_Kind;
      Text : String;
      Item : Table) is
   begin
      V.Process (Key, Kind, Text, Item);
   end Visit_Value;

   procedure Each_Value
     (T       : Table;
      Process :
        not null access procedure
          (Key : String; Kind : Value_Kind; Text : String; Item : Table))
   is
      Visitor : Value_Process (Process);
   begin
      Each_Value (T, Visitor);
   end Each_Value;

end Tabula.Config.Values;
