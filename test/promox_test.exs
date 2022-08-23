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

  describe "stub/4" do
    test "stubs 1 function call" do
      mock =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "overwrites previous stub/4 call" do
      mock =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :stubbed_add end)
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :override_stubbed_add end)

      assert Calculable.add(mock, :x) == :override_stubbed_add
      assert Calculable.add(mock, :x) == :override_stubbed_add
      assert Calculable.add(mock, :x) == :override_stubbed_add
    end

    test "stubs different function calls" do
      mock =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :stubbed_add end)
        |> Promox.stub(Calculable, :mult, fn _mock, :y -> :stubbed_mult end)

      assert Calculable.mult(mock, :y) == :stubbed_mult
      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "stubs different mocks separately" do
      mock1 =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :stubbed_add1 end)

      mock2 =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :y -> :stubbed_add2 end)

      assert Calculable.add(mock1, :x) == :stubbed_add1
      assert Calculable.add(mock2, :y) == :stubbed_add2
    end

    test "mock can be used in other processes" do
      mock =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      assert fn -> Calculable.add(mock, :x) end
             |> Task.async()
             |> Task.await() == :stubbed_add
    end

    test "raises ArgumentError if Promox.defmock(protocol) has not been called" do
      assert_raise(
        ArgumentError,
        "unmocked Protocol Enumerable. Call Promox.defmock(for: Enumerable) first.",
        fn ->
          Promox.new()
          |> Promox.stub(Enumerable, :count, fn _ -> :should_not_be_called end)
        end
      )
    end

    test "raises ArgumentError if protocol doesn't have this callback" do
      assert_raise(ArgumentError, "unknown callback function Calculable.div/2", fn ->
        Promox.new()
        |> Promox.stub(Calculable, :div, fn _mock, :z -> :stubbed_div end)
      end)
    end
  end

  describe "expect/5" do
    test "stubs 1 function call" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _mock, :x -> :stubbed_add end)

      assert Calculable.add(mock, :x) == :stubbed_add
    end

    test "raises if a function gets called if it's expected to be called 0 times" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, 0, fn _mock, :x -> :stubbed_add end)

      assert_raise(
        Promox.UnexpectedCallError,
        "no expectation defined for Calculable.add/2",
        fn -> Calculable.add(mock, :x) end
      )
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

    test "raises ArgumentError if Promox.defmock(protocol) has not been called" do
      assert_raise(
        ArgumentError,
        "unmocked Protocol Enumerable. Call Promox.defmock(for: Enumerable) first.",
        fn ->
          Promox.new()
          |> Promox.expect(Enumerable, :count, fn _ -> :should_not_be_called end)
        end
      )
    end

    test "raises ArgumentError if protocol doesn't have this callback" do
      assert_raise(ArgumentError, "unknown callback function Calculable.div/2", fn ->
        Promox.new()
        |> Promox.expect(Calculable, :div, fn _mock, :z -> :stubbed_div end)
      end)
    end
  end

  describe "verify!/1" do
    test "passes for an empty mock (which doesn't have any expects)" do
      mock = Promox.new()

      assert Promox.verify!(mock) == :ok
    end

    test "fails for a mock that didn't met 1 function expects" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _, _ -> :stubbed_add end)

      assert_raise(
        Promox.VerificationError,
        "error while verifying mocks for these protocols:\n\n  * expect Calculable.add/2 to be called once, but it was called 0 times",
        fn -> Promox.verify!(mock) end
      )
    end

    test "fails for a mock that didn't met multiple functions expects" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _, _ -> :stubbed_add end)
        |> Promox.expect(Calculable, :mult, fn _, _ -> :stubbed_mult end)

      assert_raise(
        Promox.VerificationError,
        "error while verifying mocks for these protocols:\n\n  * expect Calculable.add/2 to be called once, but it was called 0 times\n  * expect Calculable.mult/2 to be called once, but it was called 0 times",
        fn -> Promox.verify!(mock) end
      )
    end

    test "fails for a mock that didn't met function expects more than once" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, 5, fn _, _ -> :stubbed_add end)

      :stubbed_add = Calculable.add(mock, :x)

      assert_raise(
        Promox.VerificationError,
        "error while verifying mocks for these protocols:\n\n  * expect Calculable.add/2 to be called 5 times, but it was called once",
        fn -> Promox.verify!(mock) end
      )
    end

    test "fails for a mock that didn't met multiple protocols expects" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _, _ -> :stubbed_add end)
        |> Promox.expect(ScientificCalculable, :exponent, fn _, _ -> :stubbed_exponent end)

      assert_raise(
        Promox.VerificationError,
        "error while verifying mocks for these protocols:\n\n  * expect Calculable.add/2 to be called once, but it was called 0 times\n  * expect ScientificCalculable.exponent/2 to be called once, but it was called 0 times",
        fn -> Promox.verify!(mock) end
      )
    end

    test "stub should not interfere with verify!" do
      mock =
        Promox.new()
        |> Promox.stub(Calculable, :add, fn _, 1 -> 2 end)
        |> Promox.expect(Calculable, :mult, fn _, 2 -> 3 end)

      Calculable.add(mock, 1)
      Calculable.mult(mock, 2)

      Promox.verify!(mock)
    end

    test "passes for a mock that expect a function to be called 0 times" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, 0, fn _mock, :x -> :stubbed_add end)

      assert Promox.verify!(mock) == :ok
    end

    test "passes for a mock that satisfies expects" do
      mock =
        Promox.new()
        |> Promox.expect(Calculable, :add, fn _, _ -> :stubbed_add end)

      Calculable.add(mock, :whatever)

      assert Promox.verify!(mock) == :ok
    end
  end
end
