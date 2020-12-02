# typed: false
# frozen_string_literal: true

module MongoTransaction
  class Rollback < StandardError; end

  class << self
    def log(message, **options)
      if !options["log"] && !options[:log]
        return
      end
      LOG.info message
    end

    def log_error(message, **options)
      if !options["log"] && !options[:log]
        return
      end
      LOG.error message
    end

    def with_session(client: :default, **options)
      raise Mongoid::Errors::InvalidSessionUse.new(:invalid_session_nesting) if Mongoid::Threaded.get_session
      Thread.current[:current_transaction_id] = Time.now.to_i
      session = Mongoid::Clients.with_name(client).start_session(options)
      Mongoid::Threaded.set_session(session)
      Thread.current[:in_user_started_transcation] = true
      yield(session)
    rescue Mongo::Error::InvalidSession => ex
      if ex.message == Mongo::Session::SESSIONS_NOT_SUPPORTED
        raise Mongoid::Errors::InvalidSessionUse.new(:sessions_not_supported)
      end
      raise Mongoid::Errors::InvalidSessionUse.new(:invalid_session_use)
    ensure
      Thread.current[:in_user_started_transcation] = false
      Mongoid::Threaded.clear_session

      case Thread.current[:user_started_transcation_status]
      when :aborted
        execute_transaction_aborted_callbacks
      when :committed
        execute_transaction_committed_callbacks
      end

      txn_id = Thread.current[:current_transaction_id]
      Thread.current[:current_transaction_id] = nil
      Thread.current["#{txn_id}_committed_callbacks"] = nil
      Thread.current["#{txn_id}_aborted_callbacks"] = nil
      Thread.current[:user_started_transcation_status] = nil
    end

    def start(**options)
      with_session(**options) do |session|
        # Note: For more details about readConcern please go to https://docs.mongodb.com/manual/reference/read-concern/
        # Note: in snapshot mode, count command is not supported
        session.with_transaction(read: { mode: :primary }, read_concern: { level: :snapshot }, write_concern: { w: :majority, wtimeout: 5000 }) do
          begin
            started_at = Time.now
            log "Transcation started, session=#{session.session_id}, thread=#{Thread.current.object_id}", **options
            abort_result = nil
            result = yield(-> (abrv) { abort_result = abrv })
            if !abort_result.nil?
              log "Aborting transaction ...", **options
              session.abort_transaction
              log "Transaction aborted", **options
              Thread.current[:user_started_transcation_status] = :aborted
              abort_result
            else
              finished_at = Time.now
              log "Transaction committed, duration=#{((finished_at - started_at) * 1000).to_i}ms", **options
              Thread.current[:user_started_transcation_status] = :committed
              result
            end
          rescue => ex
            log_error "Rollback: #{ex.message}"
            log "Aborting transaction ...", **options
            session.abort_transaction
            log "Transaction aborted", **options
            log_error "Error during commit: #{ ex.message }", **options
            Thread.current[:user_started_transcation_status] = :aborted
            raise
          end
        end
      end
    end

    def print_handler_proc(handler)
      "#{handler.source_location.first.gsub("#{Rails.root}/", "")}:#{handler.source_location.last}"
    end

    def execute_transaction_committed_callbacks
      txn_id = Thread.current[:current_transaction_id]
      cbs    = Thread.current["#{txn_id}_committed_callbacks"] || []
      cbs.each do |callback|
        callback.call
      rescue => e
        log_error "Failed to execute committed callback #{print_handler_proc(callback)} #{e.pretty_print}", log: true
      end
    end

    def execute_transaction_aborted_callbacks
      txn_id = Thread.current[:current_transaction_id]
      cbs    = Thread.current["#{txn_id}_aborted_callbacks"] || []
      cbs.each do |callback|
        callback.call
      rescue => e
        log_error "Failed to execute aborted callback #{print_handler_proc(callback)} #{e.pretty_print}", log: true
      end
    end

    def committed(&blk)
      if Thread.current[:current_transaction_id]
        txn_id = Thread.current[:current_transaction_id]
        Thread.current["#{txn_id}_committed_callbacks"] ||= []
        Thread.current["#{txn_id}_committed_callbacks"] << blk
      else
        blk.call
      end
    end

    def aborted(&blk)
      if Thread.current[:current_transaction_id]
        txn_id = Thread.current[:current_transaction_id]
        Thread.current["#{txn_id}_aborted_callbacks"] ||= []
        Thread.current["#{txn_id}_aborted_callbacks"] << blk
      end
    end
  end
end
