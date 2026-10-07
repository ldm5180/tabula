Feature: A knob reads with its type, or keeps its default

  An absent knob keeps the caller's default silently: a config
  states only what it changes.  A present knob of the wrong type,
  out of range, or empty when substance is required keeps the
  default and is complained about through the handler the caller
  gave, by its table's label and its name.  No getter raises.  A
  list of numbers is walked at a scale the way one number is read,
  and an entry that is not a number is complained about and skipped.

  Background:
    Given a config labelled "test config":
      """toml
      flag = true
      count = 7
      name = "ada"
      wrong = "not a number"
      zero = 0
      empty = ""
      ratio = 0.2621
      quoted_ratio = "0.2621"
      tie = 0.125
      quoted_tie = "-0.125"
      huge = 9223372036854775807
      start = 2020-01-01
      quoted_start = "2024-02-29"
      no_such_day = 2021-02-29
      open = 09:30:00
      quoted_open = "16:15:00"
      precise = 09:30:00.5
      targets = [15, "0.0210", 0.2621]
      levels = [1, "x", 9223372036854775807, 2]
      """

  Scenario: A boolean reads
    When the boolean flag is read with default false
    Then the reading is true
    And nothing was warned

  Scenario: A count reads
    When the count count is read with default 0
    Then the reading is 7

  Scenario: A string reads
    When the string name is read with default "x"
    Then the reading is ada

  Scenario: An absent knob keeps its default, silently
    When the count absent is read with default 9
    Then the reading is the default
    And nothing was warned

  Scenario: A wrong-typed knob keeps its default, and is complained about
    When the count wrong is read with default 9
    Then the reading is the default
    And wrong was complained about

  Scenario: A count below its floor keeps its default, and is complained about
    When the count zero is read with default 5 and at least 1
    Then the reading is the default
    And zero was complained about

  Scenario: An empty string is a string, unless substance is required
    When the string empty is read with default "d"
    Then the reading is the text ""
    When the non-empty string empty is read with default "d"
    Then the reading is the default
    And empty was complained about

  Scenario: Presence is asked without a fallback, and never warns
    When wrong is asked for
    Then it is present
    When absent is asked for
    Then it is absent
    And nothing was warned

  Scenario Outline: The number <key> at a scale of <scale> is <value>
    When the number <key> is read at a scale of <scale> with default 0
    Then the reading is <value>
    And nothing was warned

    Examples:
      | key          | scale   | value   |
      | ratio        | 1000000 | 262100  |
      | quoted_ratio | 1000000 | 262100  |
      | count        | 1000    | 7000    |
      | tie          | 100     | 13      |
      | quoted_tie   | 100     | -13     |

  Scenario: A number too large for its scale keeps its default, and is complained about
    When the number huge is read at a scale of 10 with default 5
    Then the reading is the default
    And huge was complained about

  Scenario: A scaled knob that is not a number keeps its default, and is complained about
    When the number wrong is read at a scale of 100 with default 5
    Then the reading is the default
    And wrong was complained about

  Scenario: An absent scaled knob keeps its default, silently
    When the number absent is read at a scale of 100 with default -5
    Then the reading is the default
    And nothing was warned

  Scenario: A list of decimals reads as scaled integers
    When the numbers of targets are walked at a scale of 1000000
    Then the items were "15000000,21000,262100"
    And nothing was warned

  Scenario: A list's entry that is not a number, or does not fit, is complained about and skipped
    When the numbers of levels are walked at a scale of 10
    Then the items were "10,20"
    And levels was complained about

  Scenario: A scaled knob that is not a list walks nothing, and is complained about
    When the numbers of count are walked at a scale of 10
    Then the items were ""
    And count was complained about

  Scenario: An absent list of numbers walks nothing, silently
    When the numbers of absent are walked at a scale of 10
    Then the items were ""
    And nothing was warned

  Scenario: A bare date reads as its year, month and day
    When the date start is read with default 1999-12-31
    Then the reading is year 2020, month 1, day 1
    And nothing was warned

  Scenario: A quoted date reads the same way
    When the date quoted_start is read with default 1999-12-31
    Then the reading is year 2024, month 2, day 29

  Scenario Outline: The date <key> keeps its default, and is complained about
    When the date <key> is read with default 1999-12-31
    Then the reading is the default
    And <key> was complained about

    Examples:
      | key         |
      | no_such_day |
      | wrong       |
      | open        |

  Scenario Outline: The time <key> reads as its hour, minute and second
    When the time <key> is read with default 00:00:00
    Then the reading is hour <hour>, minute <minute>, second 0
    And nothing was warned

    Examples:
      | key         | hour | minute |
      | open        | 9    | 30     |
      | quoted_open | 16   | 15     |

  Scenario Outline: The time <key> keeps its default, and is complained about
    When the time <key> is read with default 12:00:00
    Then the reading is the default
    And <key> was complained about

    Examples:
      | key     |
      | precise |
      | start   |
      | wrong   |

  Scenario: An absent date or time keeps its default, silently
    When the date absent is read with default 1999-12-31
    Then the reading is the default
    When the time absent is read with default 12:00:00
    Then the reading is the default
    And nothing was warned
