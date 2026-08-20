# frozen_string_literal: true

module Parallelizer
  DEFAULT_CONCURRENCY = 8

  def self.map(items, concurrency: DEFAULT_CONCURRENCY, &)
    list = items.to_a
    return list.map(&) if concurrency <= 1 || list.size <= 1

    dispatch(list, limited_concurrency(list.size, concurrency), &)
  end

  def self.limited_concurrency(list_size, requested)
    [requested, list_size].min
  end

  def self.dispatch(list, count, &)
    queue = build_queue(list, count)
    results = Array.new(list.size)
    errors = Queue.new
    workers = count.times.map { worker(queue, results, errors, &) }
    workers.each(&:join)
    raise errors.pop unless errors.empty?

    results
  end

  def self.build_queue(list, count)
    queue = Queue.new
    list.each_with_index { |item, index| queue << [index, item] }
    count.times { queue << :stop }
    queue
  end

  def self.worker(queue, results, errors, &)
    Thread.new do
      loop do
        job = queue.pop
        break if job == :stop

        index, item = job
        results[index] = yield(item)
      rescue StandardError => e
        errors << e
      end
    end
  end
end
