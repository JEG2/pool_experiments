defmodule Pools.Job do
  defstruct id: nil, work: nil, result: nil, failures: [], retries: 2, notify: nil

  def new(fields) do
    struct!(__MODULE__, fields)
  end

  def generate(extra_fields) do
    [
      id: System.unique_integer(),
      work: fn ->
        wordload = :rand.uniform(10_000)

        if wordload <= 3_000 do
          raise "Oops"
        else
          Process.sleep(wordload)
        end

        wordload
      end
    ]
    |> Keyword.merge(extra_fields)
    |> new()
  end
end
