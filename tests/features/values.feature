Feature: A reader walks every value a document holds

  A reader that keeps a whole document -- every key, known to it or
  not -- walks its values rather than asking for one knob by its key
  and its type.  Each value comes with its key (none inside a list),
  its kind and its text, and a table or a list is walked in turn.  A
  table's keys come in the order the file wrote them.  A decimal's text
  is the one the document wrote, digit for digit, and a date, a time or
  a date-time is written as TOML writes it.  The walk never complains:
  every value has a kind.

  Scenario: Every value is walked with its kind and its text
    Given a config labelled "pro config" heard by its own listener:
      """toml
      name = "roth"
      quantity = 3
      enabled = true
      weight = 0.25
      """
    When every value is visited
    Then the items were "name:A_TEXT:roth,quantity:AN_INTEGER:3,enabled:A_FLAG:true,weight:A_DECIMAL:0.25"
    And its listener heard nothing

  Scenario: A table's values come in the order the file wrote them
    Given a config labelled "pro config" heard by its own listener:
      """toml
      zeta = 1
      alpha = 2
      """
    When every value is visited
    Then the items were "zeta:AN_INTEGER:1,alpha:AN_INTEGER:2"

  Scenario: A decimal is the text the document wrote
    Given a config labelled "pro config" heard by its own listener:
      """toml
      bump = 0.10
      fine = 0.123456789012345678
      small = 1.5e-3
      """
    When every value is visited
    Then the items were "bump:A_DECIMAL:0.10,fine:A_DECIMAL:0.123456789012345678,small:A_DECIMAL:0.0015"

  Scenario: Dates inside a list are walked
    Given a config labelled "pro config" heard by its own listener:
      """toml
      entry_time = 09:30:00
      start_date = [2020-01-01]
      """
    When every value is visited
    Then the items were "entry_time:A_TIME:09:30:00,start_date:AN_ARRAY:[:A_DATE:2020-01-01]"
    And its listener heard nothing

  Scenario: Tables and lists are walked in turn
    Given a config labelled "pro config" heard by its own listener:
      """toml
      entry_targets = [[15, 25], [20]]

      [report]
      engine = "native"
      """
    When every value is walked
    Then the items were "entry_targets:AN_ARRAY:[:AN_ARRAY:[:AN_INTEGER:15,:AN_INTEGER:25],:AN_ARRAY:[:AN_INTEGER:20]],report:A_TABLE:{engine:A_TEXT:native}"
