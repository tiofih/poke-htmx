# frozen_string_literal: true

require "pg"

module ConnectionRegistry
  @entries = []
  @mutex = Mutex.new

  class << self
    def register(owner, connection)
      @mutex.synchronize { @entries << [owner, connection] }
      connection
    end

    def size
      @mutex.synchronize { @entries.size }
    end

    def close_all!
      @mutex.synchronize do
        @entries.each do |owner, connection|
          owner.instance_variable_set(:@connection, nil)
          connection.close unless connection.finished?
        end
        @entries.clear
      end
    end
  end
end
