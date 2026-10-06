Feature: A document written is read back the same

  A TOML document is written in order -- comments, tables, arrays of
  tables, and keys -- and saved whole or not at all: the file in place
  is the old one or the new one, never part of either.  What is written
  reads back through the reader to the values written.  A key that
  needs quoting is quoted.  A number is written as decimal text, and
  text that is not a number, or a key written twice in one table, is
  refused: the document names the key and is not saved.

  Scenario: A document written is read back the same
    Given a new document
    When the comment "written by a test" is written
    And the table trading is begun
    And the text name is written as "ada"
    And the count retries is written as 12
    And the number bump is written as 0.0314
    And the strings templates are written as "CS_COMMON,IN_ROTH"
    And the flag dry_run is written as false
    And the date start is written as 2020-01-01
    And the time open is written as 09:30:00
    And the document is saved
    Then it was saved
    Given a config labelled "written" from the saved document
    And the section trading
    When the string name is read with default "x"
    Then the reading is ada
    When the count retries is read with default 0
    Then the reading is 12
    When the number bump is read at a scale of 10000 with default 0
    Then the reading is 314
    When the strings of templates are walked
    Then the items were "CS_COMMON,IN_ROTH"
    When the boolean dry_run is read with default true
    Then the reading is false
    When the date start is read with default 1999-12-31
    Then the reading is year 2020, month 1, day 1
    When the time open is read with default 00:00:00
    Then the reading is hour 9, minute 30, second 0
    When the keys are walked
    Then the items were "name,retries,bump,templates,dry_run,start,open"
    And nothing was warned

  Scenario: Arrays of tables are written in order
    Given a new document
    When the array table trades is begun
    And the text name is written as "alpha"
    And the array table trades is begun
    And the text name is written as "beta"
    And the document is saved
    Then it was saved
    Given a config labelled "written" from the saved document
    When the sections of trades are walked
    Then the items were "alpha,beta"

  Scenario: A key that needs quoting gets it
    Given a new document
    When the text a.b is written as "dotted"
    And the document is saved
    Then it was saved
    Given a config labelled "written" from the saved document
    When the keys are walked
    Then the items were "a.b"
    When the string a.b is read with default "x"
    Then the reading is dotted

  Scenario: Text that is not a number is refused as a number
    Given a new document
    When the number quantity is written as 1e3
    Then the document refused quantity
    When the document is saved
    Then it was not saved

  Scenario: A key written twice in one table is refused
    Given a new document
    When the table trading is begun
    And the count retries is written as 1
    And the count retries is written as 2
    Then the document refused retries
    When the document is saved
    Then it was not saved
