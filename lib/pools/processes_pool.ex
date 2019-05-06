defmodule Pools.ProcessesPool do
  use GenServer
  require Logger
  alias Pools.Job

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, %{}, options)
  end

  def queue_job(pool \\ __MODULE__, job) do
    GenServer.call(pool, {:queue_job, job})
  end

  def init(jobs) do
    {:ok, jobs}
  end

  def handle_call({:queue_job, job}, _from, jobs) do
    ref = start_job(job)
    {:reply, :ok, Map.put(jobs, ref, job)}
  end

  def handle_info({ref, result}, jobs) do
    job = Map.fetch!(jobs, ref)
    send(job.notify, {:completed, %Job{job | result: result}})
    Process.demonitor(ref, [:flush])
    {:noreply, Map.delete(jobs, ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, error}, jobs)
      when is_tuple(error) do
    job = Map.fetch!(jobs, ref)
    new_job = %Job{job | failures: job.failures ++ [elem(error, 0)]}

    remaining_jobs =
      if length(new_job.failures) > new_job.retries do
        send(new_job.notify, {:failed, new_job})
        jobs
      else
        Map.put(jobs, start_job(new_job), new_job)
      end

    {:noreply, Map.delete(remaining_jobs, ref)}
  end

  def handle_info(message, jobs) do
    Logger.debug("Unexpected message:  #{inspect(message)}")
    {:noreply, jobs}
  end

  def start_job(job) do
    task = Task.Supervisor.async_nolink(Pools.ProcessesPool.Supervisor, job.work)
    task.ref
  end
end
