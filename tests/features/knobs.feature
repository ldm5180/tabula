Feature: A knob reads with its type, or keeps its default

  Background:
    Given a config labelled "test config":
      """toml
      count = 7
      """

  Scenario: A count reads
    When the count count is read with default 0
    Then the reading is 7
