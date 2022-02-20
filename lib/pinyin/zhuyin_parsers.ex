defmodule Pinyin.ZhuYinParsers do

  import NimbleParsec
  alias Pinyin.Parsers.Utils, as: Utils

  # Empty tone must be last for parsing to work
  zhuyin_tones = ["˙", "ˊ", "ˇ", "ˋ", ""]

  initials = ~w(
    ㄅ ㄆ ㄇ ㄈ
    ㄉ ㄊ ㄋ ㄌ
    ㄍ ㄎ ㄏ
    ㄐ ㄑ ㄒ
  )

  standalone_initials = ~w(
    ㄓ ㄔ ㄕ ㄖ
    ㄗ ㄘ ㄙ
  )

  two_finals = ~w(
    ㄧㄚ
    ㄨㄚ
    ㄧㄥ
    ㄧㄤ
    ㄧㄝ
    ㄨㄛ
    ㄨㄥ
    ㄨㄤ
    ㄧㄠ
    ㄨㄞ
    ㄩㄝ
    ㄩㄥ
    ㄧㄡ
    ㄨㄟ
    ㄩㄝ
    ㄧㄢ
    ㄨㄢ
    ㄩㄢ
    ㄧㄣ
    ㄨㄣ
    ㄩㄣ
  )
  single_finals = ~w(
    ㄧ ㄨ ㄩ
    ㄚ ㄛ ㄜ ㄦ
    ㄞ ㄟ ㄠ ㄡ
    ㄢ ㄣ ㄤ ㄥ
  )

  initials_parser =
    Enum.concat(initials, standalone_initials) |> Utils.wordlist_to_parser

  standalone_initials_parser =
    standalone_initials |> Utils.wordlist_to_parser

  finals_parser =
    choice([
      two_finals |> Utils.wordlist_to_parser,
      single_finals |> Utils.wordlist_to_parser
    ])

  tone_parser =
    zhuyin_tones |> Utils.wordlist_to_parser

  defp to_zhuyin([initial, final, tone]) do
    Zhuyin.create(initial, final, tone)
  end
  defp to_zhuyin([final, tone]) do
    Zhuyin.create(final, tone)
  end

  zhuyin_word =
    choice([
      finals_parser,
      concat(initials_parser, finals_parser),
      standalone_initials_parser,
    ])
    |> concat(optional(tone_parser))
    |> reduce({:to_zhuyin, []})

  defparsec(
    :zhuyin_word,
    Utils.repeat_choice_parser([
      zhuyin_word,
      Utils.split(),
      Utils.not_split()
    ]),
    inline: true
  )

  defparsec(
    :zhuyin_only,
    Utils.repeat_choice_parser([zhuyin_word, Utils.split()]),
    inline: true
  )

  defparsec(
    :zhuyin_words,
    Utils.repeat_choice_parser([
      zhuyin_word,
      Utils.split(),
      Utils.not_split()
    ]),
    inline: true
  )

  # TODO: Do I need syllable?
  defparsec(
    :mixed_words,
    Utils.repeat_choice_parser([
      zhuyin_word,
      Utils.split(),
      Utils.not_split_until(zhuyin_word)
    ]),
    inline: true
  )
end
