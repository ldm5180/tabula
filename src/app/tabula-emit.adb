with Ada.Strings.Fixed;

with Tabula.Staged_Files;
with Tabula.Toml_Text;

package body Tabula.Emit is

   use Ada.Strings.Unbounded;

   ---------------------------------------------------------------------
   --  Writing lines, and refusing.
   ---------------------------------------------------------------------

   --  The first refusal sticks; later ones are dropped.
   procedure Refuse (Doc : in out Document; Why : String) is
   begin
      if Length (Doc.Refused) = 0 then
         Doc.Refused := To_Unbounded_String (Why);
      end if;
   end Refuse;

   procedure Put_Line (Doc : in out Document; Line : String) is
   begin
      Append (Doc.Content, Line & ASCII.LF);
   end Put_Line;

   ---------------------------------------------------------------------
   --  The entry at hand: its lines held, and written when it ends.
   ---------------------------------------------------------------------

   procedure Hold (Doc : in out Document; Line : Held_Line) is
   begin
      Doc.Held.Append (Line);
   end Hold;

   --  The width of the widest key among Held.
   function Widest_Key (Held : Held_Lines.Vector) return Natural is
      Widest : Natural := 0;
   begin
      for Line of Held loop
         if Line.Kind = Pair then
            Widest :=
              Natural'Max (Widest, Toml_Text.Width (To_String (Line.Text)));
         end if;
      end loop;
      return Widest;
   end Widest_Key;

   --  The width Doc pads the keys of the entry at hand to: none when
   --  Plain.
   function Key_Width (Doc : Document) return Natural
   is (if Doc.Layout = Aligned then Widest_Key (Doc.Held) else 0);

   --  Key, then blanks to Width columns when it is narrower.
   function Padded (Key : String; Width : Natural) return String
   is (Key
       & Ada.Strings.Fixed."*"
           (Natural'Max (0, Width - Toml_Text.Width (Key)), ' '));

   --  Line as it is written, a key padded to Width.
   function Line_Text (Line : Held_Line; Width : Natural) return String
   is (case Line.Kind is
         when Pair     =>
           Padded (To_String (Line.Text), Width)
           & " = "
           & To_String (Line.Value),
         when Verbatim => To_String (Line.Text));

   --  The lines of the entry at hand as they are written, each ended.
   function Held_Text (Doc : Document) return String is
      Width  : constant Natural := Key_Width (Doc);
      Result : Unbounded_String;
   begin
      for Line of Doc.Held loop
         Append (Result, Line_Text (Line, Width) & ASCII.LF);
      end loop;
      return To_String (Result);
   end Held_Text;

   --  End the entry at hand: its lines join the text.
   procedure End_Entry (Doc : in out Document) is
   begin
      Append (Doc.Content, Held_Text (Doc));
      Doc.Held.Clear;
   end End_Entry;

   --  Whether Toml_Text can write S: its escapes still fit a String.
   function Fits (S : String) return Boolean
   is (S'Length <= Toml_Text.Max_Text_Length);

   function At_Root (Doc : Document) return Boolean
   is (Length (Doc.Table) = 0);

   --  Note Key as written in the table at hand, or refuse it as written
   --  there already.
   procedure Claim_Key (Doc : in out Document; Key : String; Ok : out Boolean)
   is
   begin
      if At_Root (Doc) then
         Ok := not Doc.Top.Contains (Key);
         if Ok then
            Doc.Top.Insert (Key, Key_Name);
         end if;
      else
         Ok := not Doc.Keys.Contains (Key);
         if Ok then
            Doc.Keys.Insert (Key);
         end if;
      end if;
      if not Ok then
         Refuse
           (Doc,
            Key
            & ": written twice"
            & (if At_Root (Doc) then "" else " in " & To_String (Doc.Table)));
      end if;
   end Claim_Key;

   --  Key = Value_Text, when Key may be written in the table at hand.
   procedure Put_Pair (Doc : in out Document; Key, Value_Text : String) is
      Ok : Boolean;
   begin
      if not Fits (Key) then
         Refuse (Doc, "a key is too long to write");
         return;
      end if;
      Claim_Key (Doc, Key, Ok);
      if Ok then
         Hold
           (Doc,
            (Kind  => Pair,
             Text  => To_Unbounded_String (Toml_Text.Key_Text (Key)),
             Value => To_Unbounded_String (Value_Text)));
      end if;
   end Put_Pair;

   ---------------------------------------------------------------------
   --  Comments and headers.
   ---------------------------------------------------------------------

   --  A control a comment may not hold: all but the tab and the line
   --  feed Comment splits on.
   function Is_Comment_Control (C : Character) return Boolean
   is (C in ASCII.NUL .. ASCII.US | ASCII.DEL
       and then C not in ASCII.HT | ASCII.LF);

   --  Line as a comment: after a "# ", or a bare "#" when it is empty.
   function Comment_Text (Line : String) return String
   is (if Line = "" then "#" else "# " & Line);

   procedure Put_Comment_Line (Doc : in out Document; Line : String) is
   begin
      Hold (Doc, (Verbatim, To_Unbounded_String (Comment_Text (Line))));
   end Put_Comment_Line;

   procedure Comment (Doc : in out Document; Text : String) is
      First : Positive := Text'First;
   begin
      if (for some C of Text => Is_Comment_Control (C)) then
         Refuse (Doc, "a comment holds a control character");
         return;
      end if;
      for I in Text'Range loop
         if Text (I) = ASCII.LF then
            Put_Comment_Line (Doc, Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;
      Put_Comment_Line (Doc, Text (First .. Text'Last));
   end Comment;

   --  Whether Name may begin a header of Kind: unwritten at the root, or
   --  an array of tables continued.
   function May_Begin
     (Doc : Document; Name : String; Kind : Name_Kind) return Boolean
   is (not Doc.Top.Contains (Name)
       or else (Kind = Array_Name and then Doc.Top (Name) = Array_Name));

   --  The header line of Name: [Name] or [[Name]].
   function Header (Name : String; Kind : Name_Kind) return String
   is (if Kind = Array_Name
       then "[[" & Toml_Text.Key_Text (Name) & "]]"
       else "[" & Toml_Text.Key_Text (Name) & "]");

   procedure Begin_Header
     (Doc : in out Document; Name : String; Kind : Name_Kind) is
   begin
      if not Fits (Name) then
         Refuse (Doc, "a table name is too long to write");
         return;
      elsif not May_Begin (Doc, Name, Kind) then
         Refuse (Doc, Name & ": written twice");
         return;
      end if;
      End_Entry (Doc);
      Doc.Top.Include (Name, Kind);
      Doc.Table := To_Unbounded_String (Name);
      Doc.Keys.Clear;
      if Length (Doc.Content) > 0 then
         Put_Line (Doc, "");
      end if;
      Put_Line (Doc, Header (Name, Kind));
   end Begin_Header;

   procedure Begin_Table (Doc : in out Document; Name : String) is
   begin
      Begin_Header (Doc, Name, Table_Name);
   end Begin_Table;

   procedure Begin_Array_Table (Doc : in out Document; Name : String) is
   begin
      Begin_Header (Doc, Name, Array_Name);
   end Begin_Array_Table;

   ---------------------------------------------------------------------
   --  Values.
   ---------------------------------------------------------------------

   procedure Text (Doc : in out Document; Key : String; Value : String) is
   begin
      if Fits (Value) then
         Put_Pair (Doc, Key, Toml_Text.String_Text (Value));
      else
         Refuse (Doc, Key & ": text too long to write");
      end if;
   end Text;

   function Not_A_Number (Key, Value : String) return String
   is (Key & ": " & Value & " is not a number");

   procedure Number (Doc : in out Document; Key : String; Value : String) is
   begin
      if Toml_Text.Is_Number_Text (Value) then
         Put_Pair (Doc, Key, Value);
      else
         Refuse (Doc, Not_A_Number (Key, Value));
      end if;
   end Number;

   procedure Flag (Doc : in out Document; Key : String; Value : Boolean) is
   begin
      Put_Pair (Doc, Key, (if Value then "true" else "false"));
   end Flag;

   procedure Count (Doc : in out Document; Key : String; Value : Natural) is
   begin
      Put_Pair
        (Doc, Key, Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left));
   end Count;

   --  Values as a TOML array, each written by Item.
   function Array_Text
     (Values : Text_Lists.Vector;
      Item   : not null access function (S : String) return String)
      return String
   is
      Result : Unbounded_String := To_Unbounded_String ("[");
   begin
      for I in Values.First_Index .. Values.Last_Index loop
         if I > Values.First_Index then
            Append (Result, ", ");
         end if;
         Append (Result, Item (Values (I)));
      end loop;
      return To_String (Result) & "]";
   end Array_Text;

   function As_Is (S : String) return String
   is (S);

   procedure Strings
     (Doc : in out Document; Key : String; Values : Text_Lists.Vector) is
   begin
      if (for all V of Values => Fits (V)) then
         Put_Pair
           (Doc, Key, Array_Text (Values, Toml_Text.String_Text'Access));
      else
         Refuse (Doc, Key & ": text too long to write");
      end if;
   end Strings;

   procedure Numbers
     (Doc : in out Document; Key : String; Values : Text_Lists.Vector) is
   begin
      for V of Values loop
         if not Toml_Text.Is_Number_Text (V) then
            Refuse (Doc, Not_A_Number (Key, V));
            return;
         end if;
      end loop;
      Put_Pair (Doc, Key, Array_Text (Values, As_Is'Access));
   end Numbers;

   procedure Date (Doc : in out Document; Key : String; Value : Tabula.Date) is
   begin
      if Toml_Text.Is_Calendar_Date (Value) then
         Put_Pair (Doc, Key, Toml_Text.Date_Text (Value));
      else
         Refuse
           (Doc,
            Key
            & ": "
            & Toml_Text.Date_Text (Value)
            & " is not a day the calendar has");
      end if;
   end Date;

   procedure Time
     (Doc : in out Document; Key : String; Value : Tabula.Time_Of_Day) is
   begin
      Put_Pair (Doc, Key, Toml_Text.Time_Text (Value));
   end Time;

   ---------------------------------------------------------------------
   --  The whole.
   ---------------------------------------------------------------------

   function Refusal (Doc : Document) return String
   is (To_String (Doc.Refused));

   function Text_Of (Doc : Document) return String
   is (To_String (Doc.Content) & Held_Text (Doc));

   procedure Save (Doc : Document; Path : String; Ok : out Boolean) is
      File : Staged_Files.Staged_File;
   begin
      Ok := False;
      if Refusal (Doc) /= "" then
         return;
      end if;
      Staged_Files.Open (File, Path, Ok);
      Staged_Files.Put (File, Text_Of (Doc));
      Staged_Files.Commit (File, Ok);
   end Save;

end Tabula.Emit;
