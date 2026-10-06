with Ada.Containers.Generic_Array_Sort;
with Ada.Directories;

with TOML.File_IO;

with Tabula.Decimals;
with Tabula.Toml_Text;

package body Tabula.Config is

   use Ada.Strings.Unbounded;
   use type TOML.Any_Value_Kind;
   use type TOML.Float_Kind;
   use type TOML.Valid_Float;
   use type TOML.Any_Millisecond;

   --  One complaint through the table's handler (a no-op when null).
   procedure Complain (T : Table; Suffix : String) is
   begin
      if T.Warn /= null then
         T.Warn (To_String (T.Label) & ": " & Suffix);
      end if;
   end Complain;

   --  Whether V is a table: present, and of the table kind.
   function Is_Table (V : TOML.TOML_Value) return Boolean
   is (not TOML.Is_Null (V) and then TOML.Kind (V) = TOML.TOML_Table);

   --  What a real or scaled knob that is not a number warns, after its
   --  key.
   Not_A_Number : constant String := " is not a number; using default";

   --  Key's value in T -- No_TOML_Value when T is empty (or not a
   --  table) or the key is absent.  Absence is the SILENT path.
   function Lookup (T : Table; Key : String) return TOML.TOML_Value is
   begin
      if not Is_Table (T.Value) or else not TOML.Has (T.Value, Key) then
         return TOML.No_TOML_Value;
      end if;
      return TOML.Get (T.Value, Key);
   end Lookup;

   procedure Wrap
     (Result : TOML.Read_Result;
      Label  : String;
      Warn   : Warner;
      Root   : out Table;
      Status : out Load_Status;
      Error  : out Unbounded_String) is
   begin
      Root :=
        (Value => TOML.No_TOML_Value,
         Label => To_Unbounded_String (Label),
         Warn  => Warn);
      Error := Null_Unbounded_String;

      if Result.Success then
         Root.Value := Result.Value;
         Status := Loaded;
      else
         Status := Malformed;
         Error := Result.Message;
      end if;
   end Wrap;

   procedure Load
     (Path   : String;
      Label  : String;
      Warn   : Warner;
      Root   : out Table;
      Status : out Load_Status;
      Error  : out Unbounded_String) is
   begin
      if not Ada.Directories.Exists (Path) then
         Root :=
           (Value => TOML.No_TOML_Value,
            Label => To_Unbounded_String (Label),
            Warn  => Warn);
         Status := Missing;
         Error := Null_Unbounded_String;
         return;
      end if;
      Wrap (TOML.File_IO.Load_File (Path), Label, Warn, Root, Status, Error);
   end Load;

   procedure Parse
     (Content : String;
      Label   : String;
      Warn    : Warner;
      Root    : out Table;
      Status  : out Load_Status;
      Error   : out Unbounded_String) is
   begin
      Wrap (TOML.Load_String (Content), Label, Warn, Root, Status, Error);
   end Parse;

   function Section (Root : Table; Name : String) return Table is
      V : constant TOML.TOML_Value := Lookup (Root, Name);
   begin
      if not Is_Table (V) then
         return
           (Value => TOML.No_TOML_Value,
            Label => Root.Label,
            Warn  => Root.Warn);
      end if;
      return (Value => V, Label => Root.Label, Warn => Root.Warn);
   end Section;

   function Has (T : Table; Key : String) return Boolean
   is (not TOML.Is_Null (Lookup (T, Key)));

   function Get (T : Table; Key : String; Fallback : Boolean) return Boolean is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      end if;
      if TOML.Kind (V) = TOML.TOML_Boolean then
         return TOML.As_Boolean (V);
      end if;
      Complain (T, Key & " is not a boolean; using default");
      return Fallback;
   end Get;

   function Get
     (T : Table; Key : String; Fallback : Natural; Min : Natural := 0)
      return Natural
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      end if;
      if TOML.Kind (V) = TOML.TOML_Integer
        and then TOML.As_Integer (V)
                 in TOML.Any_Integer (Min) .. TOML.Any_Integer (Natural'Last)
      then
         return Natural (TOML.As_Integer (V));
      end if;
      Complain
        (T,
         Key
         & " is not a number in"
         & Min'Image
         & " .. Natural'Last; using default");
      return Fallback;
   end Get;

   function Get
     (T                 : Table;
      Key               : String;
      Fallback          : String;
      Require_Non_Empty : Boolean := False) return String
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      end if;
      if TOML.Kind (V) = TOML.TOML_String
        and then (not Require_Non_Empty or else TOML.As_String (V)'Length > 0)
      then
         return TOML.As_String (V);
      end if;
      Complain
        (T,
         Key
         & " is not a "
         & (if Require_Non_Empty then "non-empty " else "")
         & "string; using default");
      return Fallback;
   end Get;

   function Get
     (T : Table; Key : String; Fallback : Long_Float) return Long_Float
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      end if;

      if TOML.Kind (V) = TOML.TOML_Float then
         declare
            F : constant TOML.Any_Float := TOML.As_Float (V);
         begin
            if F.Kind = TOML.Regular then
               return Long_Float (F.Value);
            end if;
         end;
      elsif TOML.Kind (V) = TOML.TOML_Integer then
         return Long_Float (TOML.As_Integer (V));
      elsif TOML.Kind (V) = TOML.TOML_String
        and then Tabula.Decimals.Is_Plain_Decimal (TOML.As_String (V))
      then
         --  The proven shape check keeps 'Value's exotica (exponents,
         --  based literals) out; the handler below is only for a decimal
         --  too large for the type.
         begin
            return Long_Float'Value (TOML.As_String (V));
         exception
            when Constraint_Error =>
               null;
         end;
      end if;

      Complain (T, Key & Not_A_Number);
      return Fallback;
   end Get;

   --  A regular float times Scale, rounded by the conversion's own rule
   --  (to the nearest whole, a half away from zero); Fits is False past
   --  Scaled_Value, an infinite product among them.
   function Scaled_Float
     (F : TOML.Valid_Float; Scale : Positive) return Decimals.Scaled_Read
   is
      Bound   : constant TOML.Valid_Float := 2.0**63;
      Product : constant TOML.Valid_Float := F * TOML.Valid_Float (Scale);
   begin
      if abs Product >= Bound then
         return (Fits => False, Value => 0);
      end if;
      return (Fits => True, Value => Long_Long_Integer (Product));
   end Scaled_Float;

   --  A knob read at a scale: Read is meaningful only for a number.
   type Scaled_Knob is record
      Is_Number : Boolean := False;
      Read      : Decimals.Scaled_Read;
   end record;

   --  V at Scale, when V is a number Get_Scaled takes: an integer, a
   --  regular float, or a quoted plain decimal.
   function Scaled_Knob_Of
     (V : TOML.TOML_Value; Scale : Positive) return Scaled_Knob is
   begin
      case TOML.Kind (V) is
         when TOML.TOML_Integer =>
            return
              (True,
               Decimals.Scaled
                 (Long_Long_Integer (TOML.As_Integer (V)), Scale));

         when TOML.TOML_Float   =>
            if TOML.As_Float (V).Kind = TOML.Regular then
               return (True, Scaled_Float (TOML.As_Float (V).Value, Scale));
            end if;

         when TOML.TOML_String  =>
            if Decimals.Is_Plain_Decimal (TOML.As_String (V)) then
               return (True, Decimals.Scaled (TOML.As_String (V), Scale));
            end if;

         when others            =>
            null;
      end case;
      return (Is_Number => False, Read => <>);
   end Scaled_Knob_Of;

   function Get_Scaled
     (T : Table; Key : String; Scale : Positive; Fallback : Long_Long_Integer)
      return Long_Long_Integer
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
      K : Scaled_Knob;
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      end if;
      K := Scaled_Knob_Of (V, Scale);
      if not K.Is_Number then
         Complain (T, Key & Not_A_Number);
      elsif not K.Read.Fits then
         Complain
           (T,
            Key
            & " is out of range at a scale of"
            & Scale'Image
            & "; using default");
      else
         return K.Read.Value;
      end if;
      return Fallback;
   end Get_Scaled;

   --  V as a date: a local date of a real day, or text Toml_Text reads
   --  as one.
   function Date_Of (V : TOML.TOML_Value) return Toml_Text.Date_Read is
   begin
      case TOML.Kind (V) is
         when TOML.TOML_Local_Date =>
            declare
               D   : constant TOML.Any_Local_Date := TOML.As_Local_Date (V);
               Day : constant Date :=
                 (Positive (D.Year), Positive (D.Month), Positive (D.Day));
            begin
               return (Toml_Text.Is_Calendar_Date (Day), Day);
            end;

         when TOML.TOML_String     =>
            return Toml_Text.Date_Of (TOML.As_String (V));

         when others               =>
            return (Ok => False, Value => <>);
      end case;
   end Date_Of;

   function Get (T : Table; Key : String; Fallback : Date) return Date is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      elsif Date_Of (V).Ok then
         return Date_Of (V).Value;
      end if;
      Complain (T, Key & " is not a date; using default");
      return Fallback;
   end Get;

   --  Whether V is a local time with a fraction of a second.
   function Is_Fine_Time (V : TOML.TOML_Value) return Boolean
   is (TOML.Kind (V) = TOML.TOML_Local_Time
       and then TOML.As_Local_Time (V).Millisecond /= 0);

   --  V as a time to the second: a local time with no fraction, or text
   --  Toml_Text reads as one.
   function Time_Of (V : TOML.TOML_Value) return Toml_Text.Time_Read is
   begin
      case TOML.Kind (V) is
         when TOML.TOML_Local_Time =>
            declare
               C : constant TOML.Any_Local_Time := TOML.As_Local_Time (V);
            begin
               return
                 (Ok    => C.Millisecond = 0,
                  Value =>
                    (Natural (C.Hour),
                     Natural (C.Minute),
                     Natural (C.Second)));
            end;

         when TOML.TOML_String     =>
            return Toml_Text.Time_Of (TOML.As_String (V));

         when others               =>
            return (Ok => False, Value => <>);
      end case;
   end Time_Of;

   function Get
     (T : Table; Key : String; Fallback : Time_Of_Day) return Time_Of_Day
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return Fallback;
      elsif Time_Of (V).Ok then
         return Time_Of (V).Value;
      elsif Is_Fine_Time (V) then
         Complain (T, Key & " is not a time to the second; using default");
      else
         Complain (T, Key & " is not a time; using default");
      end if;
      return Fallback;
   end Get;

   procedure Each_String
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : String))
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return;
      end if;
      if TOML.Kind (V) /= TOML.TOML_Array then
         Complain (T, Key & " is not an array; ignoring it");
         return;
      end if;

      for I in 1 .. TOML.Length (V) loop
         declare
            Item : constant TOML.TOML_Value := TOML.Item (V, I);
         begin
            if TOML.Kind (Item) = TOML.TOML_String then
               Process (TOML.As_String (Item));
            else
               Complain (T, "non-string " & Key & " entry skipped");
            end if;
         end;
      end loop;
   end Each_String;

   procedure Each_Section
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : Table))
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return;
      end if;
      if TOML.Kind (V) /= TOML.TOML_Array then
         Complain (T, Key & " is not an array; ignoring it");
         return;
      end if;

      for I in 1 .. TOML.Length (V) loop
         declare
            Item : constant TOML.TOML_Value := TOML.Item (V, I);
         begin
            if TOML.Kind (Item) = TOML.TOML_Table then
               Process ((Value => Item, Label => T.Label, Warn => T.Warn));
            else
               Complain (T, "non-table " & Key & " entry skipped");
            end if;
         end;
      end loop;
   end Each_Section;

   --  Whether the file wrote L before R: where the parser first made
   --  each, earlier line then earlier column; the key breaks a tie, so
   --  the order never depends on the table's hashing.
   function Written_Before (L, R : TOML.Table_Entry) return Boolean is
      A : constant TOML.Source_Location := TOML.Location (L.Value);
      B : constant TOML.Source_Location := TOML.Location (R.Value);
   begin
      if A.Line /= B.Line then
         return A.Line < B.Line;
      elsif A.Column /= B.Column then
         return A.Column < B.Column;
      end if;
      return L.Key < R.Key;
   end Written_Before;

   procedure Sort_Entries is new
     Ada.Containers.Generic_Array_Sort
       (Index_Type   => Positive,
        Element_Type => TOML.Table_Entry,
        Array_Type   => TOML.Table_Entry_Array,
        "<"          => Written_Before);

   procedure Each_Key
     (T : Table; Process : not null access procedure (Key : String)) is
   begin
      if not Is_Table (T.Value) then
         return;
      end if;
      declare
         Entries : TOML.Table_Entry_Array := TOML.Iterate_On_Table (T.Value);
      begin
         Sort_Entries (Entries);
         for E of Entries loop
            Process (To_String (E.Key));
         end loop;
      end;
   end Each_Key;

end Tabula.Config;
