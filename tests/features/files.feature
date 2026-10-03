Feature: A config file is loaded, missing, or malformed -- never a crash

  A config on disk loads into a table.  A file that is not there is
  reported missing, and one the parser refuses is reported malformed
  with the parser's message; either way the table in hand is empty, so
  every knob read from it keeps its default.  Neither raises.

  Scenario: A file loads
    Given a config labelled "feed config" from the file feed
    Then the config loaded
    When the count retries is read with default 3
    Then the reading is 12

  Scenario: A missing file is reported missing, and every knob keeps its default
    Given a config labelled "feed config" from a file that does not exist
    Then the config is missing
    When the boolean anything is read with default true
    Then the reading is the default

  Scenario: A broken file is refused as malformed, with the parser's message
    Given a config labelled "feed config" from the file broken
    Then the config is malformed
    When the count not is read with default 3
    Then the reading is the default
