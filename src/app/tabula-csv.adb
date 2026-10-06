with Ada.Directories;
with Ada.Finalization;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;

package body Tabula.Csv is

   use Ada.Streams;
   use Ada.Streams.Stream_IO;
   use type Csv_Scan.Fault_Kind;

   ---------------------------------------------------------------------
   --  A row.
   ---------------------------------------------------------------------

   function Field_Count (R : Row) return Natural
   is (Csv_Scan.Field_Count (R.Scan.all));

   function Field (R : Row; Index : Positive) return String
   is (Csv_Scan.Field (R.Scan.all, Index));

   function Column (R : Row; Index : Positive) return String
   is (R.Head.Names (Index));

   function Has_Column (R : Row; Name : String) return Boolean
   is (R.Head.Index.Contains (Name));

   function Field (R : Row; Name : String) return String
   is (Csv_Scan.Field (R.Scan.all, R.Head.Index (Name)));

   function Line (R : Row) return Positive
   is (Csv_Scan.Line (R.Scan.all));

   ---------------------------------------------------------------------
   --  One read of a file: the file, its scanner (on the heap: a record's
   --  bounds make it large), its header, and what came of it so far.
   --  Finalize closes and frees, however the read ends.
   ---------------------------------------------------------------------

   type Scanner_Access is access Csv_Scan.Scanner;

   procedure Free is new
     Ada.Unchecked_Deallocation (Csv_Scan.Scanner, Scanner_Access);

   type Reading is new Ada.Finalization.Limited_Controlled with record
      File       : File_Type;
      Scan       : Scanner_Access := new Csv_Scan.Scanner;
      Head       : aliased Header;
      Has_Header : Boolean := False;
      Stopped    : Boolean := False;
      Result     : Outcome;
   end record;

   overriding
   procedure Finalize (Rd : in out Reading) is
   begin
      if Is_Open (Rd.File) then
         Close (Rd.File);
      end if;
      Free (Rd.Scan);
   end Finalize;

   --  Name as the header's column at Position; a name already there
   --  keeps its first position.
   procedure Add_Column
     (Head : in out Header; Name : String; Position : Positive) is
   begin
      Head.Names.Append (Name);
      if not Head.Index.Contains (Name) then
         Head.Index.Insert (Name, Position);
      end if;
   end Add_Column;

   --  The record in hand as the header.
   procedure Keep_Header (Rd : in out Reading) is
   begin
      for I in 1 .. Csv_Scan.Field_Count (Rd.Scan.all) loop
         Add_Column (Rd.Head, Csv_Scan.Field (Rd.Scan.all, I), I);
      end loop;
      Rd.Has_Header := True;
   end Keep_Header;

   --  Whether the record in hand has as many fields as the header.
   function Fits_Header (Rd : Reading) return Boolean
   is (Csv_Scan.Field_Count (Rd.Scan.all) = Natural (Rd.Head.Names.Length));

   --  The record in hand: the header, a row for Process, or a ragged
   --  record that stops the read.
   procedure Take_Record
     (Rd : in out Reading; Process : not null access procedure (Row : Csv.Row))
   is
   begin
      if not Rd.Has_Header then
         Keep_Header (Rd);
      elsif not Fits_Header (Rd) then
         Rd.Result := (Ragged, Csv_Scan.Line (Rd.Scan.all));
         Rd.Stopped := True;
         return;
      else
         Process (Row'(Scan => Rd.Scan, Head => Rd.Head'Unchecked_Access));
      end if;
      Csv_Scan.Next (Rd.Scan.all);
   end Take_Record;

   --  Whether the read has ended early: stopped, or the text refused.
   function Ended (Rd : Reading) return Boolean
   is (Rd.Stopped or else Csv_Scan.Fault (Rd.Scan.all) /= Csv_Scan.None);

   --  How much of the file is read at a time.
   Block_Size : constant := 65_536;

   subtype Block is Stream_Element_Array (1 .. Block_Size);

   procedure Feed_Block
     (Rd      : in out Reading;
      Bytes   : Block;
      Last    : Stream_Element_Offset;
      Process : not null access procedure (Row : Csv.Row)) is
   begin
      for I in Bytes'First .. Last loop
         Csv_Scan.Feed (Rd.Scan.all, Character'Val (Bytes (I)));
         if Csv_Scan.Ready (Rd.Scan.all) then
            Take_Record (Rd, Process);
         end if;
         exit when Ended (Rd);
      end loop;
   end Feed_Block;

   procedure Read_All
     (Rd : in out Reading; Process : not null access procedure (Row : Csv.Row))
   is
      Bytes : Block;
      Last  : Stream_Element_Offset;
   begin
      while not Ended (Rd) and then not End_Of_File (Rd.File) loop
         Read (Rd.File, Bytes, Last);
         Feed_Block (Rd, Bytes, Last, Process);
      end loop;
      if not Ended (Rd) then
         Csv_Scan.Finish (Rd.Scan.all);
         if Csv_Scan.Ready (Rd.Scan.all) then
            Take_Record (Rd, Process);
         end if;
      end if;
   end Read_All;

   --  What a read that ended came to.
   function Outcome_Of (Rd : Reading) return Outcome
   is (if Csv_Scan.Fault (Rd.Scan.all) /= Csv_Scan.None
       then (Malformed, Csv_Scan.Line (Rd.Scan.all))
       else Rd.Result);

   procedure Each_Row
     (Path    : String;
      Process : not null access procedure (Row : Csv.Row);
      Result  : out Outcome)
   is
      Rd : Reading;
   begin
      if not Ada.Directories.Exists (Path) then
         Result := (Missing, 0);
         return;
      end if;
      Open (Rd.File, In_File, Path);
      Read_All (Rd, Process);
      Result := Outcome_Of (Rd);
   exception
      when
        Ada.IO_Exceptions.Name_Error
        | Ada.IO_Exceptions.Use_Error
        | Ada.IO_Exceptions.Device_Error
        | Ada.IO_Exceptions.End_Error
        | Ada.IO_Exceptions.Data_Error
      =>
         Result := (Malformed, 0);
   end Each_Row;

   ---------------------------------------------------------------------
   --  Writing.
   ---------------------------------------------------------------------

   --  Whether Fields make a record Each_Row can read back: within the
   --  scanner's bounds on fields and on their text.
   function Readable (Fields : Text_Lists.Vector) return Boolean is
      Total : Natural := 0;
   begin
      if Natural (Fields.Length) > Csv_Scan.Max_Fields then
         return False;
      end if;
      for F of Fields loop
         if F'Length > Csv_Scan.Max_Record_Length - Total then
            return False;
         end if;
         Total := Total + F'Length;
      end loop;
      return True;
   end Readable;

   procedure Put_Record (W : in out Writer; Fields : Text_Lists.Vector) is
   begin
      for I in Fields.First_Index .. Fields.Last_Index loop
         if I > Fields.First_Index then
            Staged_Files.Put (W.File, ",");
         end if;
         Staged_Files.Put (W.File, Csv_Scan.Field_Text (Fields (I)));
      end loop;
      Staged_Files.Put (W.File, [ASCII.LF]);
   end Put_Record;

   procedure Put (W : in out Writer; Fields : Text_Lists.Vector) is
   begin
      if W.Failed then
         return;
      elsif Natural (Fields.Length) /= W.Columns or else not Readable (Fields)
      then
         W.Failed := True;
         return;
      end if;
      Put_Record (W, Fields);
   end Put;

   procedure Open
     (W : in out Writer; Path : String; Header : Text_Lists.Vector)
   is
      Opened : Boolean;
   begin
      Staged_Files.Open (W.File, Path, Opened);
      W.Columns := Natural (Header.Length);
      W.Failed := not Opened or else W.Columns = 0;
      Put (W, Header);
   end Open;

   function Failed (W : Writer) return Boolean
   is (W.Failed);

   procedure Close (W : in out Writer; Ok : out Boolean) is
   begin
      if W.Failed then
         Staged_Files.Abandon (W.File);
         Ok := False;
      else
         Staged_Files.Commit (W.File, Ok);
      end if;
      W.Failed := True;
   end Close;

end Tabula.Csv;
