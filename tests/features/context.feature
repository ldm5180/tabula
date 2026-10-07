Feature: A reader keeps what it hears in its own objects

  A reader may hand tabula objects of its own rather than procedures: a
  listener that hears what a table complains about, carried by every
  section taken from it.  What a listener hears stays in the reader's
  object, so two readers never share it.  What is read and complained
  about is the same as through a handler procedure.

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
