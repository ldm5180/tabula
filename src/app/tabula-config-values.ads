--  Every value a table or a list holds, of whatever kind, handed over
--  with its kind and its text: how a reader that keeps a whole document
--  -- every key, known to it or not -- reads one, where the getters ask
--  for one knob by its key and its type.  The walk never warns: every
--  value has a kind.

package Tabula.Config.Values is

   --  What a value is.  A decimal is a TOML float with digits; a float
   --  that is not a number, and an infinite one, are kinds of their own.
   type Value_Kind is
     (A_Table,
      An_Array,
      A_Text,
      An_Integer,
      A_Decimal,
      A_Flag,
      A_Date,
      A_Time,
      A_Local_Datetime,
      An_Offset_Datetime,
      Not_A_Number,
      An_Infinity);

   --  What the walk hands each value to, in an object of the caller's
   --  own.
   type Value_Visitor is limited interface;

   --  One value: Key is its key in a table, and empty in a list; Kind
   --  is what it is, and Text its text (empty for a table and a list);
   --  Item is the value itself, which Each_Value walks in turn when it
   --  is a table or a list.
   procedure Visit_Value
     (V    : in out Value_Visitor;
      Key  : String;
      Kind : Value_Kind;
      Text : String;
      Item : Table)
   is abstract;

   --  Walk the values T holds, handing each to Visitor: a table's in the
   --  order the file first wrote each key, as Each_Key walks them, and a
   --  list's in its order.  An empty table, and a value that is neither
   --  a table nor a list, walk nothing, silently.
   procedure Each_Value (T : Table; Visitor : in out Value_Visitor'Class);

end Tabula.Config.Values;
