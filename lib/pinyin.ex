defmodule Pinyin do
  @moduledoc """
  Utilities to deal with pinyin syllables and groups thereof.

  The main goal of this module is to provide functions to manipulate strings that contain pinyin
  words, which are potentially mixed with other content.  Users of this module can use `read/2`,
  `read!/2` or `sigil_p/2` to parse a string and turn it into a `t:pinyin_list/0`. Afterwards,
  such a list can be converted into a "numbered" or a "marked" string. Numbered strings are
  created with `numbered/1`; in this representation, tone marks are not added to the pinyin
  syllable, numbers are used to indicate the tone instead. When `marked/1` is used, pinyin is
  printed with tone marks.

  When a string is parsed with `read/2`, it is converted into a list containing strings and
  `t:t/0` structs. These structs encode pinyin syllables. Users of this module generally do not
  need to worry about manipulating these structs directly, but they are exposed for users who want
  to handle pinyin using custom logic. `create/2`, `from_marked/1` and `from_numbered/2` can be
  used to directly create a pinyin struct for a given syllable. Like `t:pinyin_list/0`, `t:t/0`
  structs can be converted to strings with `numbered/1` and `marked/1`.
  """

  defmodule ParseError do
    @moduledoc """
    Error that may be raised by `read!/2` or `sigil_p/2`
    """
    defexception [:message]

    @impl true
    def exception(remainder) do
      msg = "Error occurred when attempting to parse: `#{remainder}`"
      %__MODULE__{message: msg}
    end
  end

  # ----------------- #
  # Compile-time Work #
  # ----------------- #

  # Characters which can take a tone mark
  markeable_characters = ~w(a e i o u ü ê n m)
  markeable_characters = markeable_characters ++ Enum.map(markeable_characters, &String.upcase/1)

  # Unicode combining diacritics which represent the various tone markers
  tone_diacritic_combiners = [0x0304, 0x0301, 0x030C, 0x0300]

  # Function which can add a tone mark to a character. We generate all valid combinations at
  # compile time.
  @spec _mark(String.t(), 0..4) :: String.t()
  def _mark(char, tone)

  for char <- markeable_characters, {tone, idx} <- Enum.with_index(tone_diacritic_combiners, 1) do
    # We normalise the string to ensure a compact representation
    marked = String.normalize(<<char::binary, tone::utf8>>, :nfc)

    def _mark(unquote(char), unquote(idx)), do: unquote(marked)
  end

  def _mark("v", t), do: _mark("ü", t)
  def _mark(c, _), do: c

  # ----- #
  # Types #
  # ----- #

  @typedoc """
  Representation of a pinyin syllable.

  This struct represents a single syllable in pinyin. It stores a textual representation of the
  syllable _without_ any tone marks. In this representation, `ü` is always stored as v. The tone
  of the syllable is stored in the `tone` field. `0` represents the neutral tone.

  Do not create a pinyin struct manually. Instead, use a function such as `create/2`,
  `from_marked/1`, `from_numbered/2` or use the `sigil_p/2` sigil.
  """
  @type t :: %__MODULE__{tone: 0..4, initial: String.t(), final: String.t()}

  @enforce_keys [:final]
  defstruct tone: 0, initial: "", final: ""

  @typedoc """
  List of pinyin syllables mixed with plain strings.
  """
  @type pinyin_list :: [t() | String.t()]

  # ---------------------- #
  # Pinyin Struct Creation #
  # ---------------------- #

  @doc """
  Create a Pinyin struct (`t:t/0`) from an unmarked string and a tone numeral.

  This function is useful if you want to dynamically create pinyin structs. The use of this
  function is preferred over directly using `%Pinyin{}`, as this function normalises `word` and
  verifies `tone` is valid before the struct is created.

  ## Examples

      iex> Pinyin.create("n", "i", 3)
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.create("l", "üe", 4)
      %Pinyin{tone: 4, initial: "l", final: "ve"}

      iex> Pinyin.create("l", "ve", 4)
      %Pinyin{tone: 4, initial: "l", final: "ve"}

      iex> Pinyin.create("n", "i", 5)
      ** (FunctionClauseError) no function clause matching in Pinyin.create/3

  """
  @spec create(String.t(), String.t(), 0..4) :: t()
  def create(initial, final, tone \\ 0) when tone in 0..4 do
    final = String.replace(final, "ü", "v")
    %Pinyin{initial: initial, final: final, tone: tone}
  end

  @doc """
  Create a pinyin struct (`t:t/0`) from a string with tone marks.

  When converting the string, the tone marker is stripped and placed in the `tone` field of the
  resulting struct. An `ArgumentError` is thrown if multiple tone marks are present. Therefore,
  this function should only be used for a single pinyin word.

  ## Examples

      iex> Pinyin.from_marked("nǐ")
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.from_marked("nǐ")
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.from_marked("nǐhǎo")
      ** (ArgumentError) Multiple tone marks present in 'nǐhǎo'

      iex> Pinyin.from_marked("hello")
      ** (ArgumentError) No Pinyin word found in 'hello'

  """
  @spec from_marked(String.t()) :: t()
  def from_marked(word) do
    {:ok, parsed, _, _, _, _} = Pinyin.Parsers.pinyin_words(word)

    case parsed do
      [head = %Pinyin{} | []] ->
        head

      [head = %Pinyin{} | _tail] ->
        raise ArgumentError, "Multiple tone marks present in '#{word}'"

      _ ->
        raise ArgumentError, "No Pinyin word found in '#{word}'"
    end
  end

  @doc """
  Create a pinyin struct (`t:t/0`) from an initial string and finalstring, with tone marks.

  When converting the string, the tone marker is stripped and placed in the `tone` field of the
  resulting struct. An `ArgumentError` is thrown if multiple tone marks are present. Therefore,
  this function should only be used for a single pinyin word.

  ## Examples

      iex> Pinyin.from_marked("n", "ǐ")
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.from_marked("n", "ǐ")
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.from_marked("n", "ǐhǎo")
      ** (ArgumentError) Multiple tone marks present in 'n,ǐhǎo'

  """
  @spec from_marked(String.t(), String.t()) :: t()
  def from_marked(initial, final) do
    {final, tone} =
      final
      |> String.graphemes()
      |> Enum.map(&Pinyin.Char.split/1)
      |> Enum.map_reduce(0, fn
        {char, tone}, 0 -> {char, tone}
        {char, 0}, acc -> {char, acc}
        _, _ -> raise ArgumentError, "Multiple tone marks present in '#{initial},#{final}'"
      end)

    create(initial, Enum.join(final), tone)
  end

  @doc """
  Create a pinyin struct (`t:t/0`) from a string with a tone number.

  The tone number has to be 1, 2, 3 or 4 and has to be the last element of the string. If this is
  not the case, an invalid pinyin struct is obtained.

  If the tone of the word is known upfront, the use of `create/2` should be preferred, as it does
  not need to parse the string.

  ## Examples

      iex> Pinyin.from_numbered("n", "i3")
      %Pinyin{tone: 3, initial: "n", final: "i"}

      iex> Pinyin.from_numbered("n", "i5")
      %Pinyin{tone: 0, initial: "n", final: "i5"}

      iex> Pinyin.from_numbered("n", "i")
      %Pinyin{tone: 0, initial: "n", final: "i"}

  """
  @spec from_numbered(String.t(), String.t()) :: t()
  def from_numbered(initial, final) do
    if String.ends_with?(final, ~w(1 2 3 4)) do
      {final, tone} = String.split_at(final, -1)
      create(initial, final, String.to_integer(tone))
    else
      create(initial, final)
    end
  end

  # -------------- #
  # Pinyin Strings #
  # -------------- #

  @doc """
  Read a string and convert it into a list of string and pinyin structs.

  This function reads a string containing pinyin mixed with normal text. The output of this
  function is a list of strings and pinyin structs. White space and punctuation will be separated
  from other strings.

  The input string may contain tone-marked (e.g. "nǐ") pinyin, numbered ("ni3") pinyin or a mix
  thereof (nǐ hao3). Note that in numbered pinyin mode tone numerals __must not__ be separated
  from their word. For instance, "ni3" will be correctly parsed as "nǐ", "ni 3" will not. When
  tone marked pinyin is used the tone must be marked on the correct letter. For instance, hǎo will
  parse correctly, haǒ will not; we recommend the use of numbered pinyin if there is uncertainty
  about the location of the tone mark.

  ## Parse Modes

  By default, this function only accepts strings which consists exclusively of pinyin, whitespace
  and puncutation. Parsing any text that cannot be interpreted as pinyin will result in an error:

      iex> Pinyin.read("Ni3hao3!")
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, "!"]}

      iex> Pinyin.read("Ni3hao3, hello!")
      {:error, "hello!"}

  This behaviour can be tweaked if pinyin mixed with regular text needs to be parsed; this can be
  done by passing a `mode` to this function. There are 3 available modes:

  - `:exclusive`: The default. Every character (except white space and punctuation) is
    interpreted as pinyin. If this is not possible, an error is returned.
  - `:words`: Any word (i.e. a continuous part of the string that does not contain whitespace or
    punctuation) is either interpreted as a sequence of pinyin syllables or as non-pinyin text. If
    a word contains any characters that cannot be interpreted as pinyin, the whole word is
    considered to be non-pinyin text. This mode does not return errors.
  - `:mixed`: Any word can contain a mixture of pinyin and non-pinyin characters. The read
    function will interpret anything it can interpret as pinyin as pinyin and leaves the other
    text unmodified. This is mainly useful to mix characters and pinyin. It is not recommended to
    use this mode to mix pinyin and normal text. This mode does not return errors.

  The following examples show the use of all three modes:

      iex> Pinyin.read("Ni3hao3!", :exclusive)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, "!"]}

      iex> Pinyin.read("Ni3hao3, hello!", :exclusive)
      {:error, "hello!"}

      iex> Pinyin.read("Ni3好hao3, hello!", :exclusive)
      {:error, "Ni3好hao3, hello!"}

      iex> Pinyin.read("Ni3hao3!", :words)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, "!"]}

      iex> Pinyin.read("Ni3hao3, hello!", :words)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, ", ", "hello", "!"]}

      iex> Pinyin.read("Ni3好hao3, hello!", :words)
      {:ok, ["Ni3好hao3",  ", ", "hello", "!"]}

      iex> Pinyin.read("Ni3hao3!", :mixed)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, "!"]}

      iex> Pinyin.read("Ni3hao3, hello!", :mixed)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}, ", ", %Pinyin{initial: "h", final: "e"}, "l", %Pinyin{initial: "l", final: "o"}, "!"]}

      iex> Pinyin.read("Ni3好hao3, hello!", :mixed)
      {:ok, [%Pinyin{tone: 3, initial: "N", final: "i"}, "好",  %Pinyin{tone: 3, initial: "h", final: "ao"}, ", ", %Pinyin{initial: "h", final: "e"}, "l", %Pinyin{initial: "l", final: "o"}, "!"]}

  When `:mixed` or `:word` mode is used, it is possible some words are incorrectly identified as
  pinyin. This is generally not a problem for users who just wish to use `marked/1` or
  `numbered/1` on the result of `read/2`, since pinyin syllables with no tone are printed as is.

  ## Capitalization and -r suffix

  This function is able to read capitalized and uppercase pinyin strings. That is, strings such as
  "Ni3hao3", "NI3HAO3" and "NI3hao3" are accepted. However, pinyin words with mixed capitalization
  are not recognized:

      iex> Pinyin.read("Lei3")
      {:ok, [%Pinyin{tone: 3, initial: "L", final: "ei"}]}

      iex> Pinyin.read("LEI3")
      {:ok, [%Pinyin{tone: 3, initial: "L", final: "EI"}]}

      iex> Pinyin.read("LeI")
      {:error, "LeI"}

      iex> Pinyin.read("LEi")
      {:error, "LEi"}

  Finally, this function does not detect the _-r_ suffix. Users of the library should take care to
  fully write out _er_ instead. That is, do not write "zher", use "zheer" instead.

      iex> Pinyin.read("zher")
      {:error, "zher"}

      iex> Pinyin.read("zheer")
      {:ok, [%Pinyin{initial: "zh", final: "e"}, %Pinyin{initial: "", final: "er"}]}

  """
  @spec read(String.t(), :exclusive | :words | :mixed) ::
          {:ok, pinyin_list()} | {:error, String.t()}
  def read(string, mode \\ :exclusive) when mode in [:exclusive, :words, :mixed] do
    res =
      case mode do
        :exclusive -> Pinyin.Parsers.pinyin_only(string)
        :words -> Pinyin.Parsers.pinyin_words(string)
        :mixed -> Pinyin.Parsers.mixed_words(string)
      end

    case res do
      {:ok, lst, "", %{}, _, _} -> {:ok, lst}
      {:error, _, remainder, %{}, _, _} -> {:error, remainder}
    end
  end

  @doc """
  Identical to `read/2`, but returns the result or a `Pinyin.ParseError`

  ## Examples

      iex> Pinyin.read!("ni3hao3")
      [%Pinyin{tone: 3, initial: "n", final: "i"}, %Pinyin{tone: 3, initial: "h", final: "ao"}]

      iex> Pinyin.read!("ni3 hao3")
      [%Pinyin{tone: 3, initial: "n", final: "i"}, " ", %Pinyin{tone: 3, initial: "h", final: "ao"}]

      iex> Pinyin.read!("ni 3")
      ** (Pinyin.ParseError) Error occurred when attempting to parse: `3`

  """
  @spec read!(String.t(), :exclusive | :words | :mixed) ::
          pinyin_list() | no_return()
  def read!(string, mode \\ :exclusive)
      when mode in [:exclusive, :words, :mixed] do
    case read(string, mode) do
      {:ok, res} -> res
      {:error, remainder} -> raise ParseError, remainder
    end
  end

  @doc """
  Sigil to create a pinyin list or struct.

  When used without any modifiers, this sigil converts its input into a pinyin list through the
  use of `read!/2` in `:exclusive` mode. The `w` and `m` modifiers can be used to use `:words` or
  `:mixed` mode respectively.

  When this sigil is called with the `s` modifier, a pinyin struct is created by calling
  `from_numbered/1`.

  ## Examples

      iex> ~p/ni3/
      [%Pinyin{tone: 3, initial: "n", final: "i"}]

      iex> ~p/ni3 hello/w
      [%Pinyin{tone: 3, initial: "n", final: "i"}, " ", "hello"]

      iex> ~p/ni3好/m
      [%Pinyin{tone: 3, initial: "n", final: "i"}, "好"]

      iex> ~p/ni3/s
      %Pinyin{tone: 3, initial: "n", final: "i"}

  """
  defmacro sigil_p({:<<>>, _, [word]}, [?s]) when is_binary(word) do
    [pinyin] = read!(word)

    quote do
      unquote(Macro.escape(pinyin))
    end
  end

  defmacro sigil_p({:<<>>, _, [string]}, mode)
           when is_binary(string) and mode in [[], [?w], [?m]] do
    mode =
      case mode do
        [?w] -> :words
        [?m] -> :mixed
        [] -> :exclusive
      end

    res = Macro.escape(read!(string, mode))

    quote do
      unquote(res)
    end
  end

  # ----------------- #
  # String Conversion #
  # ----------------- #

  @doc """
  Convert a `t:t/0` or `t:pinyin_list/0` to a numbered version.

  The numbered version consists of the word without tone markings followed by the number of the
  tone. It is often used when typing pinyin manually. Any occurence of "ü" is shown as "v".
  Non-pinyin text is not modified.

  ## Examples

      iex> numbered(~p/nǐ/s)
      "ni3"

      iex> numbered(~p/lüè/s)
      "lve4"

      iex> numbered(~p/nǐhǎo/)
      "ni3hao3"

      iex> numbered(~p/NǏHǍO/)
      "NI3HAO3"

      iex> numbered(~p/Nǐhǎo, how are you?/w)
      "Ni3hao3, how are you?"

  """
  @spec numbered(t() | pinyin_list()) :: String.t()
  def numbered(%Pinyin{initial: i, final: f, tone: 0}), do: i <> f
  def numbered(%Pinyin{initial: i, final: f, tone: t}), do: i <> f <> to_string(t)

  def numbered(list) when is_list(list) do
    list
    |> Enum.map(fn
      p = %Pinyin{} -> numbered(p)
      str when is_binary(str) -> str
    end)
    |> Enum.join()
  end

  @doc """
  Convert a `t:t/0` or `t:pinyin_list/0` to a tone-marked string.

  The tone-marked string consists of the pinyin word with the tone added in the correct location.
  It is generally used when printing pinyin. Any occurence of "v" is shown as "ü".

  ## Examples

      iex> marked(~p/ni3/s)
      "nǐ"

      iex> marked(~p/lve4/s)
      "lüè"

      iex> marked(~p/ni3hao3/)
      "nǐhǎo"

      iex> marked(~p/NI3HAO3/)
      "NǏHǍO"

      iex> marked(~p/Ni3hao3, how are you?/w)
      "Nǐhǎo, how are you?"

  """
  @spec marked(t() | pinyin_list()) :: String.t()
  def marked(%Pinyin{initial: i, final: f, tone: t}) do
    final = String.replace(f, "v", "ü")
    # Special case for ng standlone final
    vowel =
      if final == "ng" do
        "n"
      else
        final |> String.codepoints() |> Enum.reduce(nil, &select_max/2)
      end

    if vowel == nil do
      # Finals without vowels that can be marked, like hng
      i <> final
    else
      replacing = _mark(vowel, t)
      i <> String.replace(final, vowel, replacing)
    end
  end

  def marked(list) when is_list(list) do
    list
    |> Enum.map(fn
      p = %Pinyin{} -> marked(p)
      str when is_binary(str) -> str
    end)
    |> Enum.join()
  end

  # Tone Placement
  # --------------
  # Order matters here, do not randomly rearrange these clauses!

  # a always wins
  defp select_max("a", _), do: "a"
  defp select_max(_, "a"), do: "a"
  defp select_max("A", _), do: "A"
  defp select_max(_, "A"), do: "A"

  # e never occurs with a and always wins
  defp select_max("e", _), do: "e"
  defp select_max(_, "e"), do: "e"
  defp select_max("E", _), do: "E"
  defp select_max(_, "E"), do: "E"

  # o always wins if there is no a present
  defp select_max("o", _), do: "o"
  defp select_max(_, "o"), do: "o"
  defp select_max("O", _), do: "O"
  defp select_max(_, "O"), do: "O"

  # in the case of ui, the second letter takes the mark Keep in mind the "left" argument is the
  # new letter, this is done to make it easy to pass the function to reduce.
  defp select_max("i", "u"), do: "i"
  defp select_max("I", "U"), do: "I"
  defp select_max("i", "U"), do: "i"
  defp select_max("I", "u"), do: "I"

  defp select_max("u", "i"), do: "u"
  defp select_max("U", "I"), do: "U"
  defp select_max("u", "I"), do: "u"
  defp select_max("U", "i"), do: "U"

  # If none of the above match whichever vowel is present takes the mark
  defp select_max(v, _) when v in ["a", "e", "i", "o", "u", "ü", "v", "ê"], do: v
  defp select_max(v, _) when v in ["A", "E", "I", "O", "U", "Ü", "v", "Ê"], do: v

  # If there is no vowel, stay with previous selection
  defp select_max(_, p), do: p
end

# --------- #
# Protocols #
# --------- #

defimpl String.Chars, for: Pinyin do
  def to_string(p = %Pinyin{}), do: Pinyin.marked(p)
end

defimpl List.Chars, for: Pinyin do
  def to_charlist(p = %Pinyin{}), do: Kernel.to_charlist(Pinyin.marked(p))
end

defimpl Inspect, for: Pinyin do
  import Inspect.Algebra

  def inspect(p = %Pinyin{}, _) do
    concat(["#Pinyin<", to_string(p), ">"])
  end
end
