with Ada.Containers.Generic_Array_Sort;
with Ada.Directories;

with TOML.File_IO;

with Tabula.Decimals;

package body Tabula.Config is

   use Ada.Strings.Unbounded;
   use type TOML.Any_Value_Kind;
   use type TOML.Float_Kind;

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

      Complain (T, Key & " is not a number; using default");
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
