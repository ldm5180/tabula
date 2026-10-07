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

   --  Message to where a table's complaints go.
   procedure Tell (To : Sink; Message : String) is
   begin
      if To.Heard_By /= null then
         To.Heard_By.Warn (Message);
      elsif To.Warn /= null then
         To.Warn (Message);
      end if;
   end Tell;

   --  One complaint from T, after its label.
   procedure Complain (T : Table; Suffix : String) is
   begin
      Tell (T.To, To_String (T.Label) & ": " & Suffix);
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

   --  The empty table, labelled Label, complaining to To.
   function Empty (Label : String; To : Sink) return Table
   is ((Value => TOML.No_TOML_Value,
        Label => To_Unbounded_String (Label),
        To    => To));

   --  What the parser read, as Root and what came of it.
   procedure Wrap
     (Read   : TOML.Read_Result;
      Label  : String;
      To     : Sink;
      Root   : out Table;
      Result : out Load_Outcome) is
   begin
      Root := Empty (Label, To);
      if Read.Success then
         Root.Value := Read.Value;
         Result := (Loaded, Null_Unbounded_String);
      else
         Result := (Malformed, Read.Message);
      end if;
   end Wrap;

   --  The one Load: the file at Path, complaining to To.
   procedure Load_To
     (Path   : String;
      Label  : String;
      To     : Sink;
      Root   : out Table;
      Result : out Load_Outcome) is
   begin
      if not Ada.Directories.Exists (Path) then
         Root := Empty (Label, To);
         Result := (Missing, Null_Unbounded_String);
         return;
      end if;
      Wrap (TOML.File_IO.Load_File (Path), Label, To, Root, Result);
   end Load_To;

   --  Result as the status and message the warner's forms return.
   procedure Split
     (Result : Load_Outcome;
      Status : out Load_Status;
      Error  : out Unbounded_String) is
   begin
      Status := Result.Status;
      Error := Result.Error;
   end Split;

   --  Where the complaints of a table heard by Heard_By go.
   function Heard (Heard_By : not null access Listener'Class) return Sink
   is ((Warn => null, Heard_By => Heard_By.all'Unchecked_Access));

   procedure Load
     (Path   : String;
      Label  : String;
      Warn   : Warner;
      Root   : out Table;
      Status : out Load_Status;
      Error  : out Unbounded_String)
   is
      Result : Load_Outcome;
   begin
      Load_To (Path, Label, (Warn, null), Root, Result);
      Split (Result, Status, Error);
   end Load;

   procedure Parse
     (Content : String;
      Label   : String;
      Warn    : Warner;
      Root    : out Table;
      Status  : out Load_Status;
      Error   : out Unbounded_String)
   is
      Result : Load_Outcome;
   begin
      Wrap (TOML.Load_String (Content), Label, (Warn, null), Root, Result);
      Split (Result, Status, Error);
   end Parse;

   procedure Load
     (Path     : String;
      Label    : String;
      Heard_By : not null access Listener'Class;
      Root     : out Table;
      Result   : out Load_Outcome) is
   begin
      Load_To (Path, Label, Heard (Heard_By), Root, Result);
   end Load;

   procedure Parse
     (Content  : String;
      Label    : String;
      Heard_By : not null access Listener'Class;
      Root     : out Table;
      Result   : out Load_Outcome) is
   begin
      Wrap (TOML.Load_String (Content), Label, Heard (Heard_By), Root, Result);
   end Parse;

   function Section (Root : Table; Name : String) return Table is
      V : constant TOML.TOML_Value := Lookup (Root, Name);
   begin
      if not Is_Table (V) then
         return (TOML.No_TOML_Value, Root.Label, Root.To);
      end if;
      return (Value => V, Label => Root.Label, To => Root.To);
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

   --  What a number that does not fit at Scale warns, after its key.
   function Out_Of_Range (Scale : Positive) return String
   is ("out of range at a scale of" & Scale'Image);

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
         Complain (T, Key & " is " & Out_Of_Range (Scale) & "; using default");
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

   ---------------------------------------------------------------------
   --  The walks.  Each array walk is the one Each_Entry, handing every
   --  entry to the private entry visitor of its kind, which hands what it
   --  takes to the caller's visitor and complains of the rest.
   ---------------------------------------------------------------------

   --  What Each_Entry hands each entry of an array knob to: a package
   --  of its own, since an interface's primitives are declared in a
   --  package's spec.
   package Walking is

      type Entry_Visitor is limited interface;

      procedure Take
        (V    : in out Entry_Visitor;
         T    : Table;
         Key  : String;
         Item : TOML.TOML_Value)
      is abstract;

   end Walking;

   use Walking;

   --  Hand each entry of the array knob Key to Entries, in order: an
   --  absent key does nothing, silently; a non-array warns and does
   --  nothing.
   procedure Each_Entry
     (T : Table; Key : String; Entries : in out Entry_Visitor'Class)
   is
      V : constant TOML.TOML_Value := Lookup (T, Key);
   begin
      if TOML.Is_Null (V) then
         return;
      elsif TOML.Kind (V) /= TOML.TOML_Array then
         Complain (T, Key & " is not an array; ignoring it");
         return;
      end if;
      for I in 1 .. TOML.Length (V) loop
         Entries.Take (T, Key, TOML.Item (V, I));
      end loop;
   end Each_Entry;

   --  The strings of an array, to To.
   type String_Entries (To : not null access String_Visitor'Class) is limited
     new Entry_Visitor
   with null record;

   overriding
   procedure Take
     (V    : in out String_Entries;
      T    : Table;
      Key  : String;
      Item : TOML.TOML_Value) is
   begin
      if TOML.Kind (Item) = TOML.TOML_String then
         V.To.Visit_String (TOML.As_String (Item));
      else
         Complain (T, "non-string " & Key & " entry skipped");
      end if;
   end Take;

   --  The numbers of an array at Scale, to To.
   type Scaled_Entries
     (Scale : Positive;
      To    : not null access Scaled_Visitor'Class)
   is limited new Entry_Visitor with null record;

   overriding
   procedure Take
     (V    : in out Scaled_Entries;
      T    : Table;
      Key  : String;
      Item : TOML.TOML_Value)
   is
      K : constant Scaled_Knob := Scaled_Knob_Of (Item, V.Scale);
   begin
      if not K.Is_Number then
         Complain (T, "non-number " & Key & " entry skipped");
      elsif not K.Read.Fits then
         Complain (T, Key & " entry " & Out_Of_Range (V.Scale) & "; skipped");
      else
         V.To.Visit_Scaled (K.Read.Value);
      end if;
   end Take;

   --  The tables of an array, each carrying T's label and sink, to To.
   type Section_Entries (To : not null access Section_Visitor'Class) is limited
     new Entry_Visitor
   with null record;

   overriding
   procedure Take
     (V    : in out Section_Entries;
      T    : Table;
      Key  : String;
      Item : TOML.TOML_Value) is
   begin
      if TOML.Kind (Item) = TOML.TOML_Table then
         V.To.Visit_Section ((Value => Item, Label => T.Label, To => T.To));
      else
         Complain (T, "non-table " & Key & " entry skipped");
      end if;
   end Take;

   procedure Each_String
     (T : Table; Key : String; Visitor : in out String_Visitor'Class)
   is
      Entries : String_Entries (Visitor'Access);
   begin
      Each_Entry (T, Key, Entries);
   end Each_String;

   procedure Each_Scaled
     (T       : Table;
      Key     : String;
      Scale   : Positive;
      Visitor : in out Scaled_Visitor'Class)
   is
      Entries : Scaled_Entries (Scale, Visitor'Access);
   begin
      Each_Entry (T, Key, Entries);
   end Each_Scaled;

   procedure Each_Section
     (T : Table; Key : String; Visitor : in out Section_Visitor'Class)
   is
      Entries : Section_Entries (Visitor'Access);
   begin
      Each_Entry (T, Key, Entries);
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

   --  The entries of the table V, in the order the file wrote them.
   function Written_Entries (V : TOML.TOML_Value) return TOML.Table_Entry_Array
   is
      Entries : TOML.Table_Entry_Array := TOML.Iterate_On_Table (V);
   begin
      Sort_Entries (Entries);
      return Entries;
   end Written_Entries;

   procedure Each_Key (T : Table; Visitor : in out Key_Visitor'Class) is
   begin
      if Is_Table (T.Value) then
         for E of Written_Entries (T.Value) loop
            Visitor.Visit_Key (To_String (E.Key));
         end loop;
      end if;
   end Each_Key;

   ---------------------------------------------------------------------
   --  The walks to a procedure: a visitor whose discriminant is the
   --  procedure, over the walks to a visitor.
   ---------------------------------------------------------------------

   type String_Process (Process : not null access procedure (Item : String)) is
      limited new String_Visitor
   with null record;

   overriding
   procedure Visit_String (V : in out String_Process; Item : String) is
   begin
      V.Process (Item);
   end Visit_String;

   type Scaled_Process
     (Process : not null access procedure (Item : Long_Long_Integer))
   is limited new Scaled_Visitor with null record;

   overriding
   procedure Visit_Scaled (V : in out Scaled_Process; Item : Long_Long_Integer)
   is
   begin
      V.Process (Item);
   end Visit_Scaled;

   type Section_Process (Process : not null access procedure (Item : Table)) is
      limited new Section_Visitor
   with null record;

   overriding
   procedure Visit_Section (V : in out Section_Process; Item : Table) is
   begin
      V.Process (Item);
   end Visit_Section;

   type Key_Process (Process : not null access procedure (Key : String)) is
      limited new Key_Visitor
   with null record;

   overriding
   procedure Visit_Key (V : in out Key_Process; Key : String) is
   begin
      V.Process (Key);
   end Visit_Key;

   procedure Each_String
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : String))
   is
      Visitor : String_Process (Process);
   begin
      Each_String (T, Key, Visitor);
   end Each_String;

   procedure Each_Scaled
     (T       : Table;
      Key     : String;
      Scale   : Positive;
      Process : not null access procedure (Item : Long_Long_Integer))
   is
      Visitor : Scaled_Process (Process);
   begin
      Each_Scaled (T, Key, Scale, Visitor);
   end Each_Scaled;

   procedure Each_Section
     (T       : Table;
      Key     : String;
      Process : not null access procedure (Item : Table))
   is
      Visitor : Section_Process (Process);
   begin
      Each_Section (T, Key, Visitor);
   end Each_Section;

   procedure Each_Key
     (T : Table; Process : not null access procedure (Key : String))
   is
      Visitor : Key_Process (Process);
   begin
      Each_Key (T, Visitor);
   end Each_Key;

end Tabula.Config;
