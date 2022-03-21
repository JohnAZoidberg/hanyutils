defmodule Zhuyin do
  @moduledoc """
  TODO
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

  # ----- #
  # Types #
  # ----- #

  @type t :: %__MODULE__{tone: 0..4, initial: String.t(), final: String.t()}

  @enforce_keys [:final]
  defstruct tone: 0, initial: "", final: ""

  @typedoc """
  List of zhuyin syllables mixed with plain strings.
  """
  @type zhuyin_list :: [t() | String.t()]

  @zhuyin_tones ["˙", "", "ˊ", "ˇ", "ˋ"]

  def tone_index(nil) do
    nil
  end

  def tone_index(tone_char) do
    Enum.find_index(@zhuyin_tones, &(&1 == tone_char))
  end

  @initials %{
    "ㄅ" => "b",
    "ㄆ" => "p",
    "ㄇ" => "m",
    "ㄈ" => "f",
    "ㄉ" => "d",
    "ㄊ" => "t",
    "ㄋ" => "n",
    "ㄌ" => "l",
    "ㄍ" => "g",
    "ㄎ" => "k",
    "ㄏ" => "h",
    "ㄐ" => "j",
    "ㄑ" => "q",
    "ㄒ" => "x",
    "ㄓ" => "zh",
    "ㄔ" => "ch",
    "ㄕ" => "sh",
    "ㄖ" => "r",
    "ㄗ" => "z",
    "ㄘ" => "c",
    "ㄙ" => "s"
  }

  @standalone_finals %{
    "ㄧ" => "yi",
    "ㄨ" => "wu",
    "ㄩ" => "yu",
    "ㄧㄚ" => "ya",
    "ㄨㄚ" => "wa",
    "ㄧㄥ" => "ying",
    "ㄧㄤ" => "yang",
    "ㄧㄝ" => "ye",
    "ㄨㄛ" => "wo",
    "ㄨㄥ" => "weng",
    "ㄨㄤ" => "wang",
    "ㄧㄠ" => "yaog",
    "ㄨㄞ" => "waig",
    "ㄩㄝ" => "yue",
    "ㄩㄥ" => "yong",
    "ㄧㄡ" => "you",
    "ㄨㄟ" => "wei",
    "ㄧㄢ" => "yan",
    "ㄨㄢ" => "wan",
    "ㄩㄢ" => "yuan",
    "ㄧㄣ" => "yin",
    "ㄨㄣ" => "wen",
    "ㄩㄣ" => "yun",
    # Technically standalone initials. Parsed as standalone finals because it's easier to deal with
    "ㄓ" => "zhi",
    "ㄔ" => "chi",
    "ㄕ" => "shi",
    "ㄖ" => "ri",
    "ㄗ" => "zi",
    "ㄘ" => "ci",
    "ㄙ" => "si",
    # Standalone finals that are the same as when combined with an initial
    "ㄦ" => "er",
    "ㄢ" => "an"
  }
  @finals %{
    "ㄧ" => "i",
    "ㄨ" => "u",
    "ㄩ" => "v",
    "ㄚ" => "a",
    "ㄛ" => "o",
    "ㄜ" => "e",
    "ㄝ" => "e",
    "ㄞ" => "ai",
    "ㄟ" => "ei",
    "ㄠ" => "ao",
    "ㄡ" => "ou",
    "ㄢ" => "an",
    "ㄣ" => "en",
    "ㄤ" => "ang",
    "ㄥ" => "eng",
    "ㄦ" => "er",
    "ㄧㄚ" => "ia",
    "ㄨㄚ" => "ua",
    "ㄧㄥ" => "ing",
    "ㄧㄤ" => "iang",
    "ㄧㄝ" => "ie",
    "ㄨㄛ" => "uo",
    "ㄨㄥ" => "ong",
    "ㄨㄤ" => "uang",
    "ㄧㄠ" => "iao",
    "ㄨㄞ" => "uai",
    "ㄩㄝ" => "ve",
    "ㄩㄥ" => "iong",
    "ㄧㄡ" => "iu",
    "ㄨㄟ" => "ui",
    "ㄧㄢ" => "ian",
    "ㄨㄢ" => "uan",
    "ㄩㄢ" => "van",
    "ㄧㄣ" => "in",
    "ㄨㄣ" => "un",
    "ㄩㄣ" => "vn"
  }

  @doc """
  Convert zhuyin to pinyin

  # Examples
   iex>  decode_zhuyin("ㄓㄨㄢˋ")
   "zhuan4"

   iex>  decode_zhuyin("a5")
   nil

   // Special case
   iex>  decode_zhuyin("ㄦ˙")
   "r"
  """
  # @spec decode_zhuyin(String.t()) :: Integer.t()
  def decode_zhuyin(input) do
    case input |> Pinyin.Zhuyin.Parsers.zhuyin_word() do
      {:ok, parsed, _rest, _other1, _other2, _other3} ->
        first = parsed |> List.first()

        if first == input do
          nil
        else
          first |> Zhuyin.to_pinyin() |> Pinyin.numbered()
        end

      true ->
        nil
    end
  end

  @spec to_pinyin(t()) :: Pinyin.t()
  # Special case for this final and tone combination
  def to_pinyin(%Zhuyin{initial: "", final: "ㄦ", tone: 0}) do
    Pinyin.create("", "r", 0)
  end

  def to_pinyin(zhuyin = %Zhuyin{}) do
    pinyin_initial =
      if zhuyin.initial == "" do
        ""
      else
        @initials[zhuyin.initial]
      end

    pinyin_final =
      if zhuyin.initial == "" do
        @standalone_finals[zhuyin.final]
      else
        @finals[zhuyin.final]
      end

    Pinyin.create(pinyin_initial, pinyin_final, zhuyin.tone)
  end

  def to_pinyin(list) when is_list(list) do
    list |> Enum.map(&Zhuyin.to_pinyin/1)
  end

  @spec from_pinyin(Pinyin.t() | Pinyin.pinyin_list()) :: t()
  def from_pinyin(pinyin = %Pinyin{}) do
    initial_map = Map.new(@initials, fn {key, val} -> {val, key} end)
    initial = initial_map[pinyin.initial]

    final =
      if pinyin.initial == "" do
        standalone_finals_map = Map.new(@standalone_finals, fn {key, val} -> {val, key} end)
        standalone_finals_map[pinyin.final]
      else
        finals_map = Map.new(@finals, fn {key, val} -> {val, key} end)
        finals_map[pinyin.final]
      end

    %__MODULE__{initial: initial, final: final, tone: pinyin.tone}
  end

  def from_pinyin(list) when is_list(list) do
    list
    |> Enum.map(fn
      p = %Pinyin{} -> from_pinyin(p)
      str when is_binary(str) -> str
    end)
    |> Enum.join()
  end

  def create(initial, final, tone) do
    %__MODULE__{initial: initial, final: final, tone: tone_index(tone)}
  end

  def create(final, tone) do
    %__MODULE__{final: final, tone: tone_index(tone)}
  end

  @spec read(String.t(), :exclusive | :words | :mixed) ::
          {:ok, zhuyin_list()} | {:error, String.t()}
  def read(string, mode \\ :exclusive) when mode in [:exclusive, :words, :mixed] do
    res =
      case mode do
        :exclusive -> Pinyin.Zhuyin.Parsers.zhuyin_only(string)
        :words -> Pinyin.Zhuyin.Parsers.zhuyin_words(string)
        :mixed -> Pinyin.Zhuyin.Parsers.mixed_words(string)
      end

    case res do
      {:ok, lst, "", %{}, _, _} -> {:ok, lst}
      {:error, _, remainder, %{}, _, _} -> {:error, remainder}
    end
  end

  @spec read!(String.t(), :exclusive | :words | :mixed) ::
          zhuyin_list() | no_return()
  def read!(string, mode \\ :exclusive)
      when mode in [:exclusive, :words, :mixed] do
    case read(string, mode) do
      {:ok, res} -> res
      {:error, remainder} -> raise ParseError, remainder
    end
  end
end

# --------- #
# Protocols #
# --------- #

defimpl String.Chars, for: Zhuyin do
  def to_string(z = %Zhuyin{}) do
    # TODO: Hm, can I access the one defined above?
    zhuyin_tones = ["˙", "", "ˊ", "ˇ", "ˋ"]
    # TODO: Should never be nil
    i =
      if z.initial == nil do
        ""
      else
        z.initial
      end

    i <> z.final <> Enum.at(zhuyin_tones, z.tone)
    # Zhuyin.marked(p)
  end
end

defimpl List.Chars, for: Zhuyin do
  def to_charlist(p = %Zhuyin{}) do
    Kernel.to_charlist(to_string(p))
  end
end

defimpl Inspect, for: Zhuyin do
  import Inspect.Algebra

  def inspect(p = %Zhuyin{}, _) do
    concat(["#Zhuyin<", to_string(p), ">"])
  end
end
