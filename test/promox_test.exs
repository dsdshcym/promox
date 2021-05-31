defmodule PromoxTest do
  use ExUnit.Case, async: true
  doctest Promox

  describe "new/0" do
    test "raises when calling a function right after initialization" do
      assert_raise(
        Promox.UnexpectedCallError,
        "no expectation defined for Calculable.add/2",
        fn ->
          Promox.new()
          |> Calculable.add(:x)
        end
      )
    end
  end
end
