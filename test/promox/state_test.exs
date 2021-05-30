defmodule Promox.StateTest do
  use ExUnit.Case, async: true

  alias Promox.State

  describe "new/0" do
    test "cannot retrieve anything from init state" do
      state = State.new()

      assert {nil, _} = State.retrieve(state, [Calculable, :add, 2])
    end
  end

  describe "expect/5" do
    test "stubs 1 function that can be retrieved later" do
      state = State.new() |> State.expect(Calculable, :add, fn 1, 2 -> :stubbed_add end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :stubbed_add
    end

    test "stubs 1 function multiple times" do
      state =
        State.new()
        |> State.expect(Calculable, :add, 2, fn
          1, 2 -> :stubbed_add1
          3, 4 -> :stubbed_add2
        end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(3, 4) == :stubbed_add2
      assert fun.(1, 2) == :stubbed_add1
    end

    test "stubs multiple functions that can be retrieved later" do
      state =
        State.new()
        |> State.expect(Calculable, :add, fn 1, 2 -> :stubbed_add end)
        |> State.expect(Calculable, :mult, fn 3, 4 -> :stubbed_mult end)

      {add, after_add} = State.retrieve(state, {Calculable, :add, 2})
      assert add.(1, 2) == :stubbed_add

      {mult, _after_mult} = State.retrieve(after_add, {Calculable, :mult, 2})
      assert mult.(3, 4) == :stubbed_mult
    end
  end
end
