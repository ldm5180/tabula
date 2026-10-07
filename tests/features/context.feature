Feature: A reader keeps what it hears in its own objects

  A reader may hand tabula objects of its own rather than procedures: a
  listener that hears what a table complains about, carried by every
  section taken from it, and a visitor that a walk hands each item to.
  What they hear and gather stays in the reader's objects, so two
  readers never share it.  What is read, walked and complained about
  is the same as through procedures.

  Scenario: A reader's own listener hears what its table complains about
    Given a config labelled "feed config" heard by its own listener:
      """toml
      retries = "three"
      """
    When the count retries is read with default 3
    Then the reading is the default
    And its listener heard retries complained about

  Scenario: A section complains to the listener of the table it came from
    Given a config labelled "feed config" heard by its own listener:
      """toml
      [trading]
      dry_run = "no"
      """
    And the section trading
    When the boolean dry_run is read with default true
    Then the reading is the default
    And its listener heard dry_run complained about

  Scenario: A listener hears nothing of a knob that reads
    Given a config labelled "feed config" heard by its own listener:
      """toml
      retries = 5
      """
    When the count retries is read with default 3
    Then the reading is 5
    And its listener heard nothing

  Scenario: A reader's visitor gathers the strings of an array, its listener the rest
    Given a config labelled "feed config" heard by its own listener:
      """toml
      names = ["a", 3, "b"]
      """
    When the strings of names are visited
    Then the items were "a,b"
    And its listener heard names complained about

  Scenario: A reader's visitor gathers the numbers of an array at a scale
    Given a config labelled "feed config" heard by its own listener:
      """toml
      targets = [15, "0.0210", 0.2621]
      """
    When the numbers of targets are visited at a scale of 1000000
    Then the items were "15000000,21000,262100"
    And its listener heard nothing

  Scenario: A reader's visitor gathers the tables of an array of tables
    Given a config labelled "feed config" heard by its own listener:
      """toml
      [[trades]]
      name = "alpha"

      [[trades]]
      name = "beta"
      """
    When the sections of trades are visited
    Then the items were "alpha,beta"

  Scenario: A reader's visitor gathers a table's keys in the file's order
    Given a config labelled "feed config" heard by its own listener:
      """toml
      zeta = 1
      alpha = 2

      [box]
      inner = true
      """
    When the keys are visited
    Then the items were "zeta,alpha,box"
