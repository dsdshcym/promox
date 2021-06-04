defmodule Promox do
  @moduledoc """
  Documentation for `Promox`.
  """

  defmodule UnexpectedCallError do
    defexception [:message]
  end

  defmodule VerificationError do
    defexception [:message]
  end

  defmacro defmock(for: protocol) do
    protocol_mod = Macro.expand(protocol, __CALLER__)

    mock_funs =
      for {fun, arity} <- protocol_mod.__protocol__(:functions) do
        args = Macro.generate_unique_arguments(arity - 1, __MODULE__)

        quote do
          def unquote(fun)(mock, unquote_splicing(args)) do
            Promox.call(
              mock,
              {unquote(protocol_mod), unquote(fun), unquote(arity)},
              [mock | unquote(args)]
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

  def stub(mock, protocol, name, code) do
    verify_protocol!(protocol, mock)
    verify_callback!(protocol, name, code)

    :ok = Agent.update(mock.agent, &Promox.State.stub(&1, protocol, name, code))

    mock
  end

  def expect(mock, protocol, name, n \\ 1, code) do
    verify_protocol!(protocol, mock)
    verify_callback!(protocol, name, code)

    :ok = Agent.update(mock.agent, &Promox.State.expect(&1, protocol, name, n, code))

    mock
  end

  defp verify_protocol!(protocol, mock) do
    case protocol.impl_for(mock) do
      nil ->
        raise ArgumentError,
              "unmocked Protocol #{inspect(protocol)}. Call Promox.defmock(for: #{inspect(protocol)}) first."

      _ ->
        :ok
    end
  end

  defp verify_callback!(protocol, name, code) do
    {:arity, arity} = Function.info(code, :arity)

    if Enum.find(protocol.__protocol__(:functions), &(&1 == {name, arity})),
      do: :ok,
      else:
        raise(
          ArgumentError,
          "unknown callback function #{Exception.format_mfa(protocol, name, arity)}"
        )
  end

  @doc false
  def call(mock, pfa, args) do
    mock.agent
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

  def verify!(mock) do
    mock.agent
    |> Agent.get(&Promox.State.get_expects/1)
    |> Enum.filter(fn {_pfa, expects} -> length(expects) > 0 end)
    |> case do
      [] ->
        :ok

      unmet_expects ->
        messages =
          unmet_expects
          |> Enum.map(fn {{protocol, fun, arity}, _expects} ->
            "  * #{Exception.format_mfa(protocol, fun, arity)}"
          end)

        raise VerificationError,
              "error while verifying mocks for these protocols:\n\n" <> Enum.join(messages, "\n")
    end
  end
end
