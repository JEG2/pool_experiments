defmodule Pools.CastOnlyPool do
  use GenServer
  alias Pools.Job

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, %{}, options)
  end

  def queue_job(pool \\ __MODULE__, job) do
    GenServer.cast(pool, {:queue_job, job})
  end

  def init(jobs) do
    {:ok, jobs}
  end

  def handle_cast({:queue_job, job}, jobs) do
    {:noreply, Map.put(jobs, job.id, job), {:continue, :work_job}}
  end

  def handle_continue(:work_job, jobs) when map_size(jobs) == 0,
    do: {:noreply, %{}}

  def handle_continue(:work_job, jobs) do
    next_job =
      jobs
      |> Map.values()
      |> List.first()

    remaining_jobs =
      case work_job(next_job) do
        {:ok, result} ->
          send(next_job.notify, {:completed, %Job{next_job | result: result}})
          Map.delete(jobs, next_job.id)

        {:error, error} ->
          new_job = %Job{next_job | failures: next_job.failures ++ [error]}

          if length(new_job.failures) > new_job.retries do
            send(new_job.notify, {:failed, new_job})
            Map.delete(jobs, new_job.id)
          else
            Map.put(jobs, new_job.id, new_job)
          end
      end

    {:noreply, remaining_jobs, {:continue, :work_job}}
  end

  defp work_job(job) do
    try do
      {:ok, job.work.()}
    rescue
      error in RuntimeError ->
        {:error, error}
    end
  end
end
