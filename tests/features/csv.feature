Feature: A CSV file is read by its rows, and written whole

  A CSV file's first record is its header, and every later record is a
  row whose fields are read by the header's names or by position.  The
  dialect is one, never guessed: a comma between fields, a double quote
  around a field that holds a comma, a quote or a line break, a doubled
  quote inside one for a quote, and LF or CRLF between records.  A
  record whose field count differs from the header's, and a quote never
  closed, are refused with the line the record began on; the rows
  before it were already handed over.  A file is written a row at a
  time, a field quoted when it holds a comma, a quote or a line break,
  and lands whole when it is closed; what is written reads back the
  same.  In the tables below, \n in a cell is a line break.

  Scenario: Fields are read by their header's names
    Given a CSV file:
      ```csv
      name,qty,note
      alpha,1,x
      beta,2,y
      ```
    When its rows are read
    Then the rows read
    And 2 rows were read
    And the rows by column name are:
      | note | name  |
      | x    | alpha |
      | y    | beta  |

  Scenario: Fields are read by position too
    Given a CSV file:
      ```csv
      name,qty,note
      alpha,1,x
      beta,2,y
      ```
    When its rows are read
    Then the fields of row 2 are:
      | beta | 2 | y |

  Scenario: Quoted fields hold commas, quotes and line breaks
    Given a CSV file:
      ```csv
      text,n
      "a, b",1
      "say ""hi"" now",2
      "one
      two",3
      "",4
      ```
    When its rows are read
    Then the rows read
    And the rows by column name are:
      | text         | n |
      | a, b         | 1 |
      | say "hi" now | 2 |
      | one\ntwo     | 3 |
      |              | 4 |

  Scenario: A ragged record is refused with its line
    Given a CSV file:
      ```csv
      a,b
      1,2
      3
      4,5
      ```
    When its rows are read
    Then the file is refused as ragged at line 3
    And the rows by column name are:
      | a |
      | 1 |

  Scenario: An unclosed quote is refused with the line its record began on
    Given a CSV file:
      ```csv
      a,b
      1,"2
      3,4
      ```
    When its rows are read
    Then the file is refused as malformed at line 2

  Scenario: A missing file is reported missing
    Given a CSV file that does not exist
    When its rows are read
    Then the CSV file is missing

  Scenario: A file written is read back the same
    When a CSV file is written with the rows:
      | name  | note         |
      | plain | x            |
      | comma | a, b         |
      | quote | say "hi" now |
      | break | one\ntwo     |
      | empty |              |
    Then the CSV file was written
    When its rows are read
    Then the rows read
    And the rows read back are the rows written
