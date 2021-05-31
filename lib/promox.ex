defmodule Promox do
  @moduledoc """
  Documentation for `Promox`.
  """

  defmodule UnexpectedCallError do
    defexception [:message]
  end

  defmacro defmock(for: protocol) do
    protocol_mod = Macro.expand(protocol, __CALLER__)

    mock_funs =
      for {fun, arity} <- protocol_mod.__protocol__(:functions) do
        args = Macro.generate_unique_arguments(arity - 1, __MODULE__)

        quote do
          def unquote(fun)(promox, unquote_splicing(args)) do
            Promox.call(
              promox,
              {unquote(protocol_mod), unquote(fun), unquote(arity)},
              [promox | unquote(args)]
            )
          end
        end
      end

    quote do
      defimpl unquote(protocol_mod), for: Promox do
        unquote(mock_funs)
      end
    end
  end

  @enforce_keys [:agent]
  defstruct [:agent]

  def new() do
    {:ok, agent} = Agent.start_link(Promox.State, :new, [])

    %__MODULE__{agent: agent}
  end

  def expect(promox, protocol, name, n \\ 1, code) do
    :ok = Agent.update(promox.agent, &Promox.State.expect(&1, protocol, name, n, code))

    promox
  end

  @doc false
  def call(promox, pfa, args) do
    promox.agent
    |> Agent.get_and_update(&Promox.State.retrieve(&1, pfa))
    |> case do
      nil ->
        {protocol, fun, arity} = pfa

        raise UnexpectedCallError,
              "no expectation defined for #{Exception.format_mfa(protocol, fun, arity)}"

      fun when is_function(fun) ->
        apply(fun, args)
    end
  end
end
