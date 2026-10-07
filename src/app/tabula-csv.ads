with Tabula.Text_Lists;

private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Strings.Hash;
private with Tabula.Csv_Scan;
private with Tabula.Staged_Files;

--  A CSV file read by its rows, and written by them.  The first record
--  is the header, and each later record is a row whose fields are read
--  by the header's names or by position.  The dialect is
--  Tabula.Csv_Scan's, never guessed.  Neither way holds more than one
--  record at a time.  Nothing raises: a missing file, a refused text and
--  a record whose field count differs from the header's are outcomes,
--  each with the line the refused record began on.

package Tabula.Csv is

   --  One record of a file, during the call that hands it over.
   type Row (<>) is limited private;

   --  How many fields the row has: as many as the header.
   function Field_Count (R : Row) return Natural;

   function Field (R : Row; Index : Positive) return String
   with Pre => Index <= Field_Count (R);

   --  The header's name for the field at Index.
   function Column (R : Row; Index : Positive) return String
   with Pre => Index <= Field_Count (R);

   --  Whether the header names a column Name.
   function Has_Column (R : Row; Name : String) return Boolean;

   --  The field in the column Name: the first so named.
   function Field (R : Row; Name : String) return String
   with Pre => Has_Column (R, Name);

   --  The line of the file the row began on.
   function Line (R : Row) return Positive;

   --  Read: every row was handed over.  Missing: no such file.
   --  Malformed: the text was refused, or could not be read (line 0).
   --  Ragged: a record's field count differs from the header's.
   type Status_Kind is (Read, Missing, Malformed, Ragged);

   --  What came of a read; Line is the refused record's, else 0.
   type Outcome is record
      Status : Status_Kind := Read;
      Line   : Natural := 0;
   end record;

   --  Hand each row of the file at Path to Process, in order, until the
   --  end or a refusal; the rows before a refusal were handed over.
   procedure Each_Row
     (Path    : String;
      Process : not null access procedure (Row : Csv.Row);
      Result  : out Outcome);

   --  What Each_Row hands each row to, in an object of the caller's own.
   type Row_Visitor is limited interface;

   procedure Visit_Row (V : in out Row_Visitor; Row : Csv.Row) is abstract;

   --  Each_Row, handing each row to Visitor.
   procedure Each_Row
     (Path : String; Visitor : in out Row_Visitor'Class; Result : out Outcome);

   --  A CSV file being written: a header, then rows of as many fields,
   --  buffered beside the path and landed whole by Close.  A row unlike
   --  the header, or one Each_Row could not read back (past
   --  Tabula.Csv_Scan's bounds), is refused: the writer has failed, takes
   --  nothing more, and Close lands nothing.  A writer let go of before
   --  Close lands nothing either.
   type Writer is limited private;

   --  Start the file that will be Path with Header; a header of no
   --  columns, or a path no file can be made beside, fails the writer.
   procedure Open
     (W : in out Writer; Path : String; Header : Text_Lists.Vector);

   procedure Put (W : in out Writer; Fields : Text_Lists.Vector);

   --  Whether anything since Open was refused or could not be written.
   function Failed (W : Writer) return Boolean;

   --  Land the file at its path, replacing what is there; Ok is False,
   --  and the old file stands, when the writer failed.
   procedure Close (W : in out Writer; Ok : out Boolean);

private

   type Writer is limited record
      File    : Staged_Files.Staged_File;
      Columns : Natural := 0;
      Failed  : Boolean := False;
   end record;

   package Column_Maps is new
     Ada.Containers.Indefinite_Hashed_Maps
       (Key_Type        => String,
        Element_Type    => Positive,
        Hash            => Ada.Strings.Hash,
        Equivalent_Keys => "=");

   --  The header's names in order, and the first position of each.
   type Header is record
      Names : Text_Lists.Vector;
      Index : Column_Maps.Map;
   end record;

   --  A view of the scanner's record in hand and the file's header.
   type Row is limited record
      Scan : not null access constant Csv_Scan.Scanner;
      Head : not null access constant Header;
   end record;

end Tabula.Csv;
