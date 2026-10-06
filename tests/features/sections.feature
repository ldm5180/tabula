Feature: A config is tables and arrays

  A section is read through its name; a missing one, or a key that is
  not a table, is an empty section that keeps every default silently.
  The walkers visit what an array holds in file order: an absent array
  is nothing to walk, silently; a key that is not an array, and each
  entry of the wrong kind, is complained about by name and skipped.
  A table lists the keys it holds in the order the file wrote them, so
  a caller can find a key it did not know to ask for.

  Background:
    Given a config labelled "feed config":
      """toml
      top = 1
      names = ["a", 3, "b"]
      scalar = 1

      [trading]
      dry_run = false

      [[trades]]
      name = "alpha"

      [[trades]]
      name = "beta"
      """

  Scenario: A section's knobs read through it
    Given the section trading
    When the boolean dry_run is read with default true
    Then the reading is false

  Scenario: A missing section keeps every default, silently
    Given the section missing
    When the boolean dry_run is read with default true
    Then the reading is the default
    And nothing was warned

  Scenario: A key that is not a table is an empty section
    Given the section top
    When the boolean dry_run is read with default true
    Then the reading is the default
    And nothing was warned

  Scenario: The strings of an array are walked in order, the rest complained about
    When the strings of names are walked
    Then the items were "a,b"
    And names was complained about

  Scenario: An absent array walks nothing, silently
    When the strings of absent are walked
    Then the items were ""
    And nothing was warned

  Scenario: A key that is not an array walks nothing, and is complained about
    When the strings of scalar are walked
    Then the items were ""
    And scalar was complained about

  Scenario: The tables of an array of tables are walked in file order
    When the sections of trades are walked
    Then the items were "alpha,beta"
    And nothing was warned

  Scenario: Entries that are not tables are complained about and skipped
    When the sections of names are walked
    Then the items were ""
    And names was complained about

  Scenario: A key that is not an array of tables walks nothing, and is complained about
    When the sections of scalar are walked
    Then the items were ""
    And scalar was complained about

  Scenario: A table lists the keys it holds, in the file's order
    When the keys are walked
    Then the items were "top,names,scalar,trading,trades"
    And nothing was warned

  Scenario: A section lists its own keys
    Given the section trading
    When the keys are walked
    Then the items were "dry_run"

  Scenario: A key that is not a table lists no keys, silently
    Given the section top
    When the keys are walked
    Then the items were ""
    And nothing was warned
