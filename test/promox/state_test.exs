defmodule Promox.StateTest do
  use ExUnit.Case, async: true

  alias Promox.State

  describe "new/0" do
    test "cannot retrieve anything from init state" do
      state = State.new()

      assert {nil, _} = State.retrieve(state, [Calculable, :add, 2])
    end
  end

  describe "stub/4" do
    test "stubs 1 function that can be retrieved later" do
      state = State.new() |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :stubbed_add
    end

    test "stubs 1 function that can be retrieved multiple times later" do
      state = State.new() |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)

      {fun, state1} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :stubbed_add

      {fun, _state2} = State.retrieve(state1, {Calculable, :add, 2})
      assert fun.(1, 2) == :stubbed_add
    end

    test "overwrites previous stub/4 call" do
      state =
        State.new()
        |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)
        |> State.stub(Calculable, :add, fn 1, 2 -> :override_stubbed_add end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :override_stubbed_add
    end

    test "stubs multiple functions that can be retrieved later" do
      state =
        State.new()
        |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)
        |> State.stub(Calculable, :mult, fn 3, 4 -> :stubbed_mult end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :stubbed_add

      {fun, _} = State.retrieve(state, {Calculable, :mult, 2})
      assert fun.(3, 4) == :stubbed_mult
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

  describe "expect/5 and stub/4" do
    test "retrieves expect over stub" do
      state =
        State.new()
        |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)
        |> State.expect(Calculable, :add, fn 1, 2 -> :expect_add end)
        |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)

      {fun, _} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :expect_add
    end

    test "falls back to stub when expects are used-up" do
      state =
        State.new()
        |> State.stub(Calculable, :add, fn 1, 2 -> :stubbed_add end)
        |> State.expect(Calculable, :add, fn 1, 2 -> :expect_add end)
        |> State.stub(Calculable, :add, fn 1, 2 -> :override_stubbed_add end)

      {fun, state1} = State.retrieve(state, {Calculable, :add, 2})
      assert fun.(1, 2) == :expect_add

      {fun, _state2} = State.retrieve(state1, {Calculable, :add, 2})
      assert fun.(1, 2) == :override_stubbed_add
    end
  end
end
