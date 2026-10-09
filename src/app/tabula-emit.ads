with Tabula.Text_Lists;

private with Ada.Containers.Vectors;
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

   --  How a document writes its key lines: Plain writes key = value;
   --  Aligned pads each key to the width of the widest key in its table
   --  entry (the root's keys, a [table]'s, or one [[array]] entry's), so
   --  the entry's equals signs line up.  Comments and blank lines are
   --  written as they are either way.
   type Key_Layout is (Plain, Aligned);

   --  Default-initialized: empty, nothing refused, its keys Plain.
   --  Document (Aligned) aligns them; what it writes reads back as a
   --  Plain document's does.
   type Document (Layout : Key_Layout := Plain) is private;

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

   --  What a line of the table entry at hand is: a key and its value,
   --  or a line written as it stands (a comment).
   type Held_Kind is (Pair, Verbatim);

   --  A line of the table entry at hand, held until the entry ends so
   --  that its keys can be aligned: Text is the key's text for a Pair,
   --  and the whole line otherwise.
   type Held_Line (Kind : Held_Kind := Verbatim) is record
      Text : Ada.Strings.Unbounded.Unbounded_String;
      case Kind is
         when Pair =>
            Value : Ada.Strings.Unbounded.Unbounded_String;

         when Verbatim =>
            null;
      end case;
   end record;

   package Held_Lines is new
     Ada.Containers.Vectors
       (Index_Type   => Positive,
        Element_Type => Held_Line);

   --  The text of the entries ended, the first refusal, the names written
   --  at the root, the table keys now go to ("" at the root) with the
   --  keys written in it, and the lines of the entry at hand.
   type Document (Layout : Key_Layout := Plain) is record
      Content : Ada.Strings.Unbounded.Unbounded_String;
      Refused : Ada.Strings.Unbounded.Unbounded_String;
      Top     : Name_Maps.Map;
      Table   : Ada.Strings.Unbounded.Unbounded_String;
      Keys    : Key_Sets.Set;
      Held    : Held_Lines.Vector;
   end record;

end Tabula.Emit;
