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

  describe "expect/5" do
    test "stubs 1 function call" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "raises if a function gets called after `n` times" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      Calculable.add(mock, :x)

      assert_raise(
        Promox.UnexpectedCallError,
        "no expectation defined for Calculable.add/2",
        fn -> mock |> Calculable.add(:x) end
      )
    end

    test "stubs function call multiple times" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, 3, fn _mock, :x -> :stubbed_add end)

      assert Calculable.add(mock, :x) == :stubbed_add
      assert Calculable.add(mock, :x) == :stubbed_add
      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "stubs different function calls" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add end)
        |> Promox.expect(Calculable, :mult, fn _mock, :y -> :stubbed_mult end)

      assert Calculable.mult(mock, :y) == :stubbed_mult
      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "stubs different mocks separately" do
      mock1 =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add1 end)

      mock2 =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :y -> :stubbed_add2 end)

      assert Calculable.add(mock1, :x) == :stubbed_add1
      assert Calculable.add(mock2, :y) == :stubbed_add2
    end

    test "mock can be used in other processes" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      assert fn -> Calculable.add(mock, :x) end
             |> Task.async()
             |> Task.await() == :stubbed_add
    end
  end
end
