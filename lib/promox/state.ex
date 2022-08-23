defmodule Promox.State do
  def new() do
    %{expects: %{}, stubs: %{}}
  end

  def stub(state, protocol, callback, fun) do
    {:arity, arity} = Function.info(fun, :arity)

    put_in(state, [:stubs, {protocol, callback, arity}], fun)
  end

  def expect(state, protocol, callback, n \\ 1, fun) do
    {:arity, arity} = Function.info(fun, :arity)

    additional_funs = List.duplicate(fun, n)

    update_in(state, [:expects, {protocol, callback, arity}], fn
      nil -> {additional_funs, []}
      {expects, used_expects} -> {expects ++ additional_funs, used_expects}
    end)
  end

  def get_expects(state) do
    state.expects
  end

  def retrieve(state, pfa) do
    {expect, new_state} = pop_expect(state, pfa)

    {
      expect || get_stub(state, pfa),
      new_state
    }
  end

  defp pop_expect(state, pfa) do
    case Map.fetch(state.expects, pfa) do
      {:ok, {[], used_expects}} ->
        {nil, put_in(state, [:expects, pfa], {[], used_expects})}

      {:ok, {[expect | rest], used_expects}} ->
        {expect, put_in(state, [:expects, pfa], {rest, [expect | used_expects]})}

      :error ->
        {nil, state}
    end
  end

  defp get_stub(state, pfa) do
    get_in(state, [:stubs, pfa])
  end
end
