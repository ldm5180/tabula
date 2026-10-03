Feature: A decimal reads exactly, bare or quoted

  A real knob takes a TOML integer, a TOML float, or a quoted plain
  decimal -- digits, an optional sign and an optional fraction.  A bare
  0.02 reads as 0.02, never as 0.2.  A quoted shape fancier than a
  plain decimal keeps the default and is complained about.

  Background:
    Given a config labelled "prices":
      """toml
      whole = 2
      plain = 1.5
      small = 0.02
      mixed = 1.05
      quoted = "0.02"
      signed = "-1.5"
      fancy = "1e3"
      based = "16#FF#"
      spaced = "1_000"
      """

  Scenario Outline: The real <key> reads as <value>
    When the real <key> is read with default 0
    Then the reading is <value>
    And nothing was warned

    Examples:
      | key    | value |
      | whole  | 2     |
      | plain  | 1.5   |
      | small  | 0.02  |
      | mixed  | 1.05  |
      | quoted | 0.02  |

  Scenario: A quoted signed decimal reads exactly
    When the real signed is read with default 0
    Then the reading is -1.5
    And nothing was warned

  Scenario Outline: A quoted <key> is not a plain decimal: it keeps its default
    When the real <key> is read with default 7
    Then the reading is the default
    And <key> was complained about

    Examples:
      | key    |
      | fancy  |
      | based  |
      | spaced |
