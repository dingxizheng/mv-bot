# frozen_string_literal: true

class BaseProcessor
  THREAD_POOL = []
  class << self
    def start_processing(&block)
      THREAD_POOL << [name, Thread.new(&block)]
    end

    def stop_all
      THREAD_POOL&.each do |th|
        th.last.exit
      end
    end

    def stop
      THREAD_POOL&.each do |th|
        th.last.exit if th.first == name
      end
    end
  end
end