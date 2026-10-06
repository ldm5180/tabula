with Sml.Machines.Operators;

package body Tabula.Csv_Scan
  with SPARK_Mode
is

   ---------------------------------------------------------------------
   --  The record being read.
   ---------------------------------------------------------------------

   --  The first refusal sticks; later ones are dropped.
   procedure Refuse (B : in out Record_Buffer; Why : Fault_Kind) is
   begin
      if B.Fault = None then
         B.Fault := Why;
      end if;
   end Refuse;

   --  C after the record's text.  The Text_Full guard sends a full
   --  record to a refusal first; a full one here is refused the same.
   procedure Append (B : in out Record_Buffer; C : Character) is
   begin
      if B.Length = Max_Record_Length then
         Refuse (B, Too_Long);
         return;
      end if;
      B.Length := B.Length + 1;
      B.Text (B.Length) := C;
   end Append;

   --  The field read so far ends where the text does.  The Fields_Full
   --  guard keeps room for it; a record with none is refused the same.
   procedure End_Field (B : in out Record_Buffer) is
   begin
      if B.Count = Max_Fields then
         Refuse (B, Too_Many_Fields);
         return;
      end if;
      B.Count := B.Count + 1;
      B.Ends (B.Count) := B.Length;
   end End_Field;

   function Evaluate
     (G : Guard_Kind; B : Record_Buffer; Evt : Event) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when Text_Full   => B.Length = Max_Record_Length,
           when Fields_Full => B.Count >= Max_Fields - 1);
   end Evaluate;

   procedure Execute (A : Action_Kind; B : in out Record_Buffer; Evt : Event)
   is
   begin
      case A is
         when A_Nothing     =>
            null;

         when A_Append      =>
            Append (B, Evt.Char);

         when A_End_Field   =>
            End_Field (B);

         when A_End_Record  =>
            End_Field (B);
            B.Ready := True;

         when A_Too_Long    =>
            Refuse (B, Too_Long);

         when A_Too_Many    =>
            Refuse (B, Too_Many_Fields);

         when A_Stray_Quote =>
            Refuse (B, Stray_Quote);

         when A_Unclosed    =>
            Refuse (B, Unclosed_Quote);

         when A_Bare_Return =>
            Refuse (B, Bare_Carriage_Return);
      end case;
   end Execute;

   ---------------------------------------------------------------------
   --  The table.
   ---------------------------------------------------------------------

   package Op is new SM.Operators (Always => Always, Nothing => A_Nothing);
   use type Op.Ev, Op.Ev_Guard, Op.Ev_Built, Op.Source;

   Comma       : constant Op.Ev := (Kind => E_Comma);
   Quote       : constant Op.Ev := (Kind => E_Quote);
   CR          : constant Op.Ev := (Kind => E_CR);
   LF          : constant Op.Ev := (Kind => E_LF);
   Other       : constant Op.Ev := (Kind => E_Other);
   End_Of_Text : constant Op.Ev := (Kind => E_End_Of_Text);

   --  Each row reads:  From + Event (Guard) / Action >= To.  Rows for one
   --  state are tried top to bottom, so a refusing guarded row comes
   --  before the row that would take the event.  Malformed and Finished
   --  have no rows: a refused or finished text takes nothing more.
   --!format off
   Table : constant SM.Transition_Table (1 .. Rows) :=
     [Record_End      + Comma (Fields_Full) / A_Too_Many    >= Malformed,
      Record_End      + Comma               / A_End_Field   >= Field_Start,
      Record_End      + Quote                               >= Quoted,
      Record_End      + CR                                  >= Line_Feed_Due,
      Record_End      + LF                  / A_End_Record  >= Record_End,
      Record_End      + Other               / A_Append      >= Unquoted,
      Record_End      + End_Of_Text                         >= Finished,

      Field_Start     + Comma (Fields_Full) / A_Too_Many    >= Malformed,
      Field_Start     + Comma               / A_End_Field   >= Field_Start,
      Field_Start     + Quote                               >= Quoted,
      Field_Start     + CR                                  >= Line_Feed_Due,
      Field_Start     + LF                  / A_End_Record  >= Record_End,
      Field_Start     + Other (Text_Full)   / A_Too_Long    >= Malformed,
      Field_Start     + Other               / A_Append      >= Unquoted,
      Field_Start     + End_Of_Text         / A_End_Record  >= Finished,

      Unquoted        + Comma (Fields_Full) / A_Too_Many    >= Malformed,
      Unquoted        + Comma               / A_End_Field   >= Field_Start,
      Unquoted        + Quote               / A_Stray_Quote >= Malformed,
      Unquoted        + CR                                  >= Line_Feed_Due,
      Unquoted        + LF                  / A_End_Record  >= Record_End,
      Unquoted        + Other (Text_Full)   / A_Too_Long    >= Malformed,
      Unquoted        + Other               / A_Append      >= Unquoted,
      Unquoted        + End_Of_Text         / A_End_Record  >= Finished,

      Quoted          + Quote                               >= Quote_In_Quoted,
      Quoted          + End_Of_Text         / A_Unclosed    >= Malformed,
      Quoted          + Comma (Text_Full)   / A_Too_Long    >= Malformed,
      Quoted          + Comma               / A_Append      >= Quoted,
      Quoted          + CR (Text_Full)      / A_Too_Long    >= Malformed,
      Quoted          + CR                  / A_Append      >= Quoted,
      Quoted          + LF (Text_Full)      / A_Too_Long    >= Malformed,
      Quoted          + LF                  / A_Append      >= Quoted,
      Quoted          + Other (Text_Full)   / A_Too_Long    >= Malformed,
      Quoted          + Other               / A_Append      >= Quoted,

      Quote_In_Quoted + Quote (Text_Full)   / A_Too_Long    >= Malformed,
      Quote_In_Quoted + Quote               / A_Append      >= Quoted,
      Quote_In_Quoted + Comma (Fields_Full) / A_Too_Many    >= Malformed,
      Quote_In_Quoted + Comma               / A_End_Field   >= Field_Start,
      Quote_In_Quoted + CR                                  >= Line_Feed_Due,
      Quote_In_Quoted + LF                  / A_End_Record  >= Record_End,
      Quote_In_Quoted + Other               / A_Stray_Quote >= Malformed,
      Quote_In_Quoted + End_Of_Text         / A_End_Record  >= Finished,

      Line_Feed_Due   + LF                  / A_End_Record  >= Record_End,
      Line_Feed_Due   + Comma               / A_Bare_Return >= Malformed,
      Line_Feed_Due   + Quote               / A_Bare_Return >= Malformed,
      Line_Feed_Due   + CR                  / A_Bare_Return >= Malformed,
      Line_Feed_Due   + Other               / A_Bare_Return >= Malformed,
      Line_Feed_Due   + End_Of_Text            / A_Bare_Return >= Malformed];
   --!format on

   function Initial_Machine return SM.Machine
   is (SM.Make (Table, Initial => Record_End));

   ---------------------------------------------------------------------
   --  Scanning.
   ---------------------------------------------------------------------

   --  C as the event of its kind.
   function Event_Of (C : Character) return Event
   is ((Kind =>
          (case C is
             when ','      => E_Comma,
             when '"'      => E_Quote,
             when ASCII.CR => E_CR,
             when ASCII.LF => E_LF,
             when others   => E_Other),
        Char => C));

   --  Whether Field holds a character the scanner reads as more than
   --  text: a comma, a quote, a carriage return or a line feed.
   function Needs_Quotes (Field : String) return Boolean
   is (for some C of Field => Event_Of (C).Kind /= E_Other);

   --  The buffer starts as all quotes, so every slot skipped holds one:
   --  the opening quote, each doubling, and the closing quote.
   function Field_Text (Field : String) return String is
      Quote  : constant Character := '"';
      Buffer : String (1 .. 2 * Field'Length + 2) := [others => Quote];
      Last   : Positive := 1;
   begin
      if not Needs_Quotes (Field) then
         return Field;
      end if;
      for I in Field'Range loop
         pragma
           Loop_Invariant
             (Last in I - Field'First + 1 .. 2 * (I - Field'First) + 1);
         Last := Last + 1;
         Buffer (Last) := Field (I);
         if Field (I) = Quote then
            Last := Last + 1;
         end if;
      end loop;
      return Buffer (1 .. Last + 1);
   end Field_Text;

   --  Evt through the table.  Only Malformed and Finished leave an
   --  event untaken, and they have no rows because they take nothing
   --  more, so whether a row took it says nothing the state does not.
   procedure Take (S : in out Scanner; Evt : Event) is
      Handled : Boolean;
      pragma
        Warnings
          (Off,
           Handled,
           Reason => "Malformed and Finished take nothing by design");
   begin
      SM.Process_Event (S.M, S.B, Evt, Handled);
   end Take;

   procedure Feed (S : in out Scanner; C : Character) is
   begin
      Take (S, Event_Of (C));
      if C = ASCII.LF and then S.B.Line < Positive'Last then
         S.B.Line := S.B.Line + 1;
      end if;
   end Feed;

   procedure Finish (S : in out Scanner) is
   begin
      Take (S, (Kind => E_End_Of_Text, Char => ' '));
   end Finish;

   procedure Next (S : in out Scanner) is
   begin
      S.B.Length := 0;
      S.B.Count := 0;
      S.B.Ready := False;
      S.B.Record_Line := S.B.Line;
   end Next;

   function Field (S : Scanner; Index : Positive) return String is
      First : constant Positive :=
        (if Index = 1 then 1 else S.B.Ends (Index - 1) + 1);
   begin
      return S.B.Text (First .. S.B.Ends (Index));
   end Field;

end Tabula.Csv_Scan;
