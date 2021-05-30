defmodule Promox.State do
  def new() do
    %{expects: %{}}
  end

  def expect(state, protocol, callback, n \\ 1, fun) do
    {:arity, arity} = Function.info(fun, :arity)

    additional_funs = List.duplicate(fun, n)

    update_in(state, [:expects, {protocol, callback, arity}], fn
      nil -> additional_funs
      expects -> expects ++ additional_funs
    end)
  end

  def retrieve(state, pfa) do
    get_and_update_in(state, [:expects, pfa], fn
      nil -> {nil, nil}
      [] -> {nil, []}
      [expect | rest] -> {expect, rest}
    end)
  end
end
