defmodule Mix.Tasks.WorkJobs do
  use Mix.Task
  require Logger
  alias Pools.{Job, CastOnlyPool, ProcessesPool}

  def run(_args) do
    Application.ensure_all_started(:pools)

    jobs =
      Stream.repeatedly(fn -> Job.generate(notify: self()) end)
      |> Enum.take(10)

    exercise_queue(CastOnlyPool, jobs)
    exercise_queue(ProcessesPool, jobs)
  end

  def exercise_queue(queue, jobs) do
    {elapsed, _result} =
      :timer.tc(fn ->
        Enum.each(jobs, fn job -> queue.queue_job(job) end)

        Enum.each(jobs, fn _job ->
          receive do
            {status, %Job{} = job} when status in ~w[completed failed]a ->
              Logger.info("Job #{status}:  #{inspect(job)}")
          end
        end)
      end)

    Logger.info("#{queue} total time:  #{elapsed / 1_000_000} seconds")
  end
end
