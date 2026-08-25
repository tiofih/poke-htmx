# frozen_string_literal: true

require "pg"

# Registra UMA conexão por (repositório, thread). Repositórios são singletons
# compartilhados entre as threads do Puma; uma única conexão por repositório
# corrompe o protocolo PG quando usada concorrentemente ("message type ...
# arrived from server while idle"). O `after_teardown` dos testes fecha tudo.
#
# Produção (BUG-4): o app libera as conexões da thread ao fim de cada request
# (`release_current_thread!` via `after` no server) e o registro tem teto
# `MAX_CONNECTIONS` com evicção (thread morta primeiro, senão LRU) — evita o
# "too many clients" por acúmulo de (repos × threads) nunca fechadas.
module ConnectionRegistry
  MAX_CONNECTIONS = Integer(ENV.fetch("PG_MAX_CONNECTIONS", "30"))

  @entries = {}
  @mutex = Mutex.new

  class << self
    def connection_for(owner, thread_id, db_url)
      @mutex.synchronize do
        key = [owner, thread_id]
        if (entry = @entries[key])
          entry[:last_used_at] = monotonic
          entry[:connection]
        else
          create_connection(key, db_url)
        end
      end
    end

    def release_current_thread!
      thread_id = Thread.current.object_id
      @mutex.synchronize do
        @entries.delete_if do |(_, entry_thread_id), entry|
          next false unless entry_thread_id == thread_id

          close(entry)
          true
        end
      end
    end

    def size
      @mutex.synchronize { @entries.size }
    end

    def close_all!
      @mutex.synchronize do
        @entries.each_value { |entry| close(entry) }
        @entries.clear
      end
    end

    private

    def create_connection(key, db_url)
      evict_if_full
      connection = PG.connect(db_url)
      @entries[key] = { connection: connection, last_used_at: monotonic, thread: Thread.current }
      connection
    end

    def evict_if_full
      return if @entries.size < MAX_CONNECTIONS

      stale_key, stale_entry = dead_entry || lru_entry
      return unless stale_key

      close(stale_entry)
      @entries.delete(stale_key)
    end

    def dead_entry
      @entries.find { |_key, entry| !entry[:thread].alive? }
    end

    def lru_entry
      @entries.min_by { |_key, entry| entry[:last_used_at] }
    end

    def close(entry)
      connection = entry[:connection]
      connection.close unless connection.finished?
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
