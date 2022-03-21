defmodule ZhuyinTest do
  use ExUnit.Case
  import Zhuyin
  doctest Zhuyin

  test "Decode Zhuyin" do
    tests = [
      {"ㄝ", nil},
      {"ㄝ", nil},
      {"ㄐㄩ˙", "jv"},
      {"ㄌㄩˇ", "lv3"},
      {"ㄓㄠˊ", "zhao2"},
      {"ㄓˋ", "zhi4"},
      {"ㄌㄥ", "leng1"},
      {"ㄕㄨㄟˇ", "shui3"},
      {"ㄌㄧㄡˊ", "liu2"},
      {"ㄧˊ", "yi2"},
      {"ㄇㄧㄣˊ", "min2"},
      {"ㄐˇ", nil},
      {"ㄨㄥˊ", "weng2"},
      {"ㄨˊ", "wu2"},
      {"ㄩ", "yu1"},
      {"ㄩㄝˇ", "yue3"},
      {"ㄩㄝˋ", "yue4"},
      {"ㄩㄢˊ", "yuan2"},
      {"ㄌㄩㄢˋ", "lvan4"},
      {"ㄌㄢˇ", "lan3"},
      {"ㄦˊ", "er2"},
      {"ㄦ˙", "r"}
    ]

    Enum.each(tests, fn {z, p} -> assert Zhuyin.decode_zhuyin(z) == p end)
  end
end
