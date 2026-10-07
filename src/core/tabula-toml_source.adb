package body Tabula.Toml_Source
  with SPARK_Mode
is

   --  Whether C may open a number: a digit or a sign.
   function Opens_Number (C : Character) return Boolean
   is (C in '0' .. '9' | '+' | '-');

   --  Whether C may be part of a number.
   function In_Number (C : Character) return Boolean
   is (Opens_Number (C) or else C in '.' | '_' | 'e' | 'E');

   --  Whether the byte C begins no codepoint of its own: a CR, which
   --  the LF after it makes one line end with, or a UTF-8 continuation.
   function Takes_No_Column (C : Character) return Boolean
   is (C = ASCII.CR or else Character'Pos (C) in 16#80# .. 16#BF#);

   --  The column after Column that a tab advances to.
   function Tab_From (Column : Natural) return Natural
   is (Column + Tab_Stop - Column mod Tab_Stop)
   with Pre => Column <= Natural'Last - Tab_Stop;

   --  Where a codepoint is: its line and column.
   type Place is record
      Line, Column : Natural := 0;
   end record;

   --  Where the codepoint C is, the one before it at Before; the first
   --  of the document, at no place, is at line one, column one.
   function Next (Before : Place; C : Character) return Place
   is (if Before.Line = 0
       then (1, 1)
       elsif C = ASCII.LF
       then (Before.Line + 1, 1)
       elsif C = ASCII.HT
       then (Before.Line, Tab_From (Before.Column))
       else (Before.Line, Before.Column + 1))
   with
     Pre =>
       Before.Line < Natural'Last
       and then Before.Column <= Natural'Last - Tab_Stop;

   --  The number that starts at From or at the byte after it.
   function Run_From (Source : String; From : Positive) return Span
   with
     Pre  => From in Source'Range,
     Post =>
       (if Run_From'Result.Found
        then
          Run_From'Result.First in Source'Range
          and then Run_From'Result.Last
                   in Run_From'Result.First .. Source'Last)
   is
      First : Positive := From;
      Last  : Positive;
   begin
      if not Opens_Number (Source (First)) then
         if First = Source'Last then
            return (others => <>);
         end if;
         First := First + 1;
      end if;
      if not Opens_Number (Source (First)) then
         return (others => <>);
      end if;
      Last := First;
      while Last < Source'Last and then In_Number (Source (Last + 1)) loop
         pragma Loop_Invariant (Last in First .. Source'Last - 1);
         pragma Loop_Variant (Increases => Last);
         Last := Last + 1;
      end loop;
      return (Found => True, First => First, Last => Last);
   end Run_From;

   function Number_At (Source : String; Line, Column : Positive) return Span is
      At_Byte : Place;
   begin
      for I in Source'Range loop
         pragma
           Loop_Invariant
             (At_Byte.Line <= I - Source'First
                and then At_Byte.Column <= Tab_Stop * (I - Source'First) + 1);
         if not Takes_No_Column (Source (I)) then
            At_Byte := Next (At_Byte, Source (I));
            if At_Byte = (Line, Column) then
               return Run_From (Source, I);
            elsif At_Byte.Line > Line then
               return (others => <>);
            end if;
         end if;
      end loop;
      return (others => <>);
   end Number_At;

   function Line_Ended (Text : String) return String is
      Ended :
        String (1 .. Text'Length + (if Ends_Open (Text) then 1 else 0)) :=
          [others => ASCII.LF];
   begin
      Ended (1 .. Text'Length) := Text;
      return Ended;
   end Line_Ended;

end Tabula.Toml_Source;
