with Tabula.Text_Lists;

private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Containers.Indefinite_Hashed_Sets;
private with Ada.Strings.Hash;
private with Ada.Strings.Unbounded;

--  A TOML document, written in order: comments, tables, arrays of
--  tables, and keys, each key in the table last begun (or at the root,
--  before any).  What it writes, Tabula.Config reads back to the same
--  values.  Nothing raises: what cannot be written is refused, the first
--  refusal is kept for the caller to read, and a document that refused
--  anything is not saved.

package Tabula.Emit is

   --  Default-initialized: empty, nothing refused.
   type Document is private;

   --  Text as comment lines, one per line of it; a control character
   --  other than a tab is refused.
   procedure Comment (Doc : in out Document; Text : String);

   --  Begin the table Name ([Name]); its keys follow.  A name already
   --  written at the root is refused.
   procedure Begin_Table (Doc : in out Document; Name : String);

   --  Begin the next table of the array Name ([[Name]]); its keys
   --  follow.  A name already written at the root as a key or a table
   --  is refused.
   procedure Begin_Array_Table (Doc : in out Document; Name : String);

   --  Each of these writes Key = its value, and refuses a key already
   --  written in the same table.  A key is quoted when it must be.

   procedure Text (Doc : in out Document; Key : String; Value : String);

   --  Value is decimal text, written unquoted; text that is not a
   --  number Tabula.Toml_Text.Is_Number_Text passes is refused.
   procedure Number (Doc : in out Document; Key : String; Value : String);

   procedure Flag (Doc : in out Document; Key : String; Value : Boolean);

   procedure Count (Doc : in out Document; Key : String; Value : Natural);

   procedure Strings
     (Doc : in out Document; Key : String; Values : Text_Lists.Vector);

   --  Each of Values is decimal text, as Number takes.
   procedure Numbers
     (Doc : in out Document; Key : String; Values : Text_Lists.Vector);

   --  A day the calendar lacks is refused.
   procedure Date (Doc : in out Document; Key : String; Value : Tabula.Date);

   procedure Time
     (Doc : in out Document; Key : String; Value : Tabula.Time_Of_Day);

   --  The first thing Doc refused, beginning with the key or table name
   --  it refused ("qty: 1e3 is not a number"); "" when nothing was.
   function Refusal (Doc : Document) return String;

   --  The document as written so far.
   function Text_Of (Doc : Document) return String;

   --  Write Doc to Path whole, replacing what is there by a rename.  Ok
   --  is False, and Path untouched, when Doc refused anything or the
   --  file could not be written.
   procedure Save (Doc : Document; Path : String; Ok : out Boolean);

private

   --  What a name at the root was written as.
   type Name_Kind is (Key_Name, Table_Name, Array_Name);

   package Name_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Name_Kind,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

   package Key_Sets is new
     Ada.Containers.Indefinite_Hashed_Sets
       (Element_Type        => String,
        Hash                => Ada.Strings.Hash,
        Equivalent_Elements => "=");

   --  The text so far, the first refusal, the names written at the root,
   --  and the table keys now go to ("" at the root) with the keys
   --  written in it.
   type Document is record
      Content : Ada.Strings.Unbounded.Unbounded_String;
      Refused : Ada.Strings.Unbounded.Unbounded_String;
      Top     : Name_Maps.Map;
      Table   : Ada.Strings.Unbounded.Unbounded_String;
      Keys    : Key_Sets.Set;
   end record;

end Tabula.Emit;
