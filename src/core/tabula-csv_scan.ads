with Sml.Machines;

--  A CSV text scanned one character at a time, one record at a time: a
--  comma between fields, a double quote around a field that holds a
--  comma, a quote or a line break, a doubled quote inside one for a
--  quote, and LF or CRLF ending a record.  No other dialect is guessed.
--  The scanner is an sml machine; its record is bounded, and a record
--  past the bounds is refused, never cut.  Pure, proved free of runtime
--  errors.

package Tabula.Csv_Scan
  with SPARK_Mode
is

   --  The most characters one record's fields may hold together.
   Max_Record_Length : constant := 65_536;

   --  The most fields one record may have.
   Max_Fields : constant := 1_024;

   --  Why a text was refused: a quote inside a bare field or after a
   --  closing one, a quote never closed, a carriage return no line feed
   --  follows, or a record past a bound.
   type Fault_Kind is
     (None,
      Stray_Quote,
      Unclosed_Quote,
      Bare_Carriage_Return,
      Too_Long,
      Too_Many_Fields);

   --  Default-initialized: at the start of a text.
   type Scanner is private;

   --  Whether a whole record is in hand, its fields to be read before
   --  Next lets it go.
   function Ready (S : Scanner) return Boolean;

   --  Why the text was refused; None while it has not been.  A refused
   --  scanner takes no more.
   function Fault (S : Scanner) return Fault_Kind;

   --  The line the record in hand, or the one being read, began on --
   --  the line a refusal names.
   function Line (S : Scanner) return Positive;

   function Field_Count (S : Scanner) return Natural
   with Post => Field_Count'Result <= Max_Fields;

   function Field (S : Scanner; Index : Positive) return String
   with Pre => Ready (S) and then Index <= Field_Count (S);

   --  The next character of the text.
   procedure Feed (S : in out Scanner; C : Character)
   with Pre => not Ready (S);

   --  The end of the text: a last record with no line end after it is
   --  then in hand, and an open quote is refused.
   procedure Finish (S : in out Scanner)
   with Pre => not Ready (S);

   --  Let the record in hand go, and read on.
   procedure Next (S : in out Scanner)
   with Pre => Ready (S), Post => not Ready (S);

private

   --  Record_End: no part of a record seen.  Field_Start: after a
   --  comma.  Unquoted, Quoted: inside a bare or a quoted field.
   --  Quote_In_Quoted: a quote inside a quoted field, which closes it or
   --  is doubled.  Line_Feed_Due: after a carriage return.
   type State is
     (Record_End,
      Field_Start,
      Unquoted,
      Quoted,
      Quote_In_Quoted,
      Line_Feed_Due,
      Malformed,
      Finished);

   type Event_Kind is (E_Comma, E_Quote, E_CR, E_LF, E_Other, E_End_Of_Text);

   --  A character of the text, by its kind; Finish carries none.
   type Event is record
      Kind : Event_Kind := E_End_Of_Text;
      Char : Character := ' ';
   end record;

   function Kind_Of (Evt : Event) return Event_Kind
   is (Evt.Kind);

   --  Text_Full: no room for another character.  Fields_Full: no room
   --  for the field a comma promises after the one it ends.
   type Guard_Kind is (Always, Text_Full, Fields_Full);

   type Action_Kind is
     (A_Nothing,
      A_Append,
      A_End_Field,
      A_End_Record,
      A_Too_Long,
      A_Too_Many,
      A_Stray_Quote,
      A_Unclosed,
      A_Bare_Return);

   subtype Text_Count is Natural range 0 .. Max_Record_Length;
   subtype Field_Total is Natural range 0 .. Max_Fields;

   type Field_Ends is array (1 .. Max_Fields) of Text_Count;

   --  The record being read: its fields' text end to end, where each
   --  field ends, whether it is whole, why the text was refused, the
   --  line being read and the line the record began on.
   type Record_Buffer is record
      Text        : String (1 .. Max_Record_Length) := [others => ' '];
      Length      : Text_Count := 0;
      Ends        : Field_Ends := [others => 0];
      Count       : Field_Total := 0;
      Ready       : Boolean := False;
      Fault       : Fault_Kind := None;
      Line        : Positive := 1;
      Record_Line : Positive := 1;
   end record;

   function Evaluate
     (G : Guard_Kind; B : Record_Buffer; Evt : Event) return Boolean;

   procedure Execute (A : Action_Kind; B : in out Record_Buffer; Evt : Event);

   package SM is new
     Sml.Machines
       (State       => State,
        Event_Kind  => Event_Kind,
        Event       => Event,
        Context     => Record_Buffer,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Kind_Of     => Kind_Of,
        Evaluate    => Evaluate,
        Execute     => Execute);

   --  How many rows the scanner's transition table has.
   Rows : constant := 47;

   --  A machine over the table, at the start of a text.
   function Initial_Machine return SM.Machine
   with Post => Initial_Machine'Result.Count = Rows;

   type Scanner is record
      M : SM.Machine (Rows) := Initial_Machine;
      B : Record_Buffer;
   end record;

   function Ready (S : Scanner) return Boolean
   is (S.B.Ready);

   function Fault (S : Scanner) return Fault_Kind
   is (S.B.Fault);

   function Line (S : Scanner) return Positive
   is (S.B.Record_Line);

   function Field_Count (S : Scanner) return Natural
   is (S.B.Count);

end Tabula.Csv_Scan;
