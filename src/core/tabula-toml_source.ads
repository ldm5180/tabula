--  A TOML document's text as the parser takes it: the text handed to
--  the parser, and where in it the parser placed a number -- the line
--  and column it records for each value, mapped back to the text, so a
--  float's literal can be read as the document wrote it.  Pure, proved
--  free of runtime errors.

package Tabula.Toml_Source
  with SPARK_Mode
is

   --  The columns a tab advances to, as the parser counts them: to the
   --  next multiple of Tab_Stop, or Tab_Stop on from one.
   Tab_Stop : constant := 8;

   --  The longest document Number_At reads: its lines and columns, a
   --  tab's among them, fit a Natural.
   Max_Source_Length : constant := Natural'Last / (2 * Tab_Stop);

   --  A run of a text, First .. Last: meaningful only when Found.
   type Span is record
      Found : Boolean := False;
      First : Positive := 1;
      Last  : Natural := 0;
   end record;

   --  The number Source holds at the place Line and Column -- its run of
   --  digits, signs, points, underscores and exponent marks -- starting
   --  at the codepoint there or at the byte after it: the parser places a
   --  value by the codepoint before its first, or by that first itself
   --  when the codepoint before was read ahead.  It counts columns by
   --  codepoint from one, a tab to its stop, and a line end, CR LF as
   --  one, as column one of the line it opens; the document's first
   --  codepoint is line one, column one.  Found is False when no number
   --  starts there.
   function Number_At (Source : String; Line, Column : Positive) return Span
   with
     Pre  => Source'Length <= Max_Source_Length,
     Post =>
       (if Number_At'Result.Found
        then
          Number_At'Result.First in Source'Range
          and then Number_At'Result.Last
                   in Number_At'Result.First .. Source'Last);

   --  Whether Text ends with neither a line feed nor a carriage return:
   --  the parser's lexer reads past the end of a date or a time that
   --  ends a text so, and fails.
   function Ends_Open (Text : String) return Boolean
   is (Text'Length > 0 and then Text (Text'Last) not in ASCII.LF | ASCII.CR);

   --  The text the parser is handed for Text, from one: Text with a line
   --  feed after it when it ends open, and Text itself otherwise.  A
   --  document may end with a line end or not, so its meaning is the
   --  same.  A lone carriage return at the end is left as it is: it is
   --  refused, and a line feed after it would make it a line end the
   --  parser accepts.
   function Line_Ended (Text : String) return String
   with
     Pre  => Text'Length < Natural'Last,
     Post =>
       Line_Ended'Result'First = 1
       and then Line_Ended'Result'Length
                = Text'Length + (if Ends_Open (Text) then 1 else 0)
       and then Line_Ended'Result (1 .. Text'Length) = Text
       and then not Ends_Open (Line_Ended'Result);

end Tabula.Toml_Source;
