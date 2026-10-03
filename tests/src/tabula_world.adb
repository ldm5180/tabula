with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Fixed;

package body Tabula_World is

   package Messages is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);

   --  Every warning since the last Reset or Parse, one message each.
   Warnings : Messages.Vector;

   procedure Record_Warning (Message : String) is
   begin
      Warnings.Append (Message);
   end Record_Warning;

   procedure Reset is
   begin
      Warnings.Clear;
   end Reset;

   procedure Parse
     (Content : String;
      Label   : String;
      Root    : out Tabula.Config.Table;
      Status  : out Tabula.Config.Load_Status;
      Error   : out Ada.Strings.Unbounded.Unbounded_String) is
   begin
      Reset;
      Tabula.Config.Parse
        (Content, Label, Record_Warning'Access, Root, Status, Error);
   end Parse;

   function Silent return Boolean
   is (Warnings.Is_Empty);

   function Warned (Fragment : String) return Boolean
   is (for some Message of Warnings =>
         Ada.Strings.Fixed.Index (Message, Fragment) > 0);

end Tabula_World;
