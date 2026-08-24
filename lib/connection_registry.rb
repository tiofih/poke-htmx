# frozen_string_literal: true

require "pg"

# Registra UMA conexão por (repositório, thread). Repositórios são singletons
# compartilhados entre as threads do Puma; uma única conexão por repositório
# corrompe o protocolo PG quando usada concorrentemente ("message type ...
# arrived from server while idle"). O `after_teardown` dos testes fecha tudo.
module ConnectionRegistry
  @entries = {}
  @mutex = Mutex.new

  class << self
    def connection_for(owner, thread_id, db_url)
      @mutex.synchronize do
        @entries[[owner, thread_id]] ||= PG.connect(db_url)
      end
    end

    def size
      @mutex.synchronize { @entries.size }
    end

    def close_all!
      @mutex.synchronize do
        @entries.each_value { |connection| connection.close unless connection.finished? }
        @entries.clear
      end
    end
  end
end
