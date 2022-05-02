module DB
  abstract class Connection
    @expires_at : Time?
    @ttl : Int32 = 0
    @retry_delay : Int32 = 1
    @reaper : Tasker::OneShot(Nil)?

    property ttl, expires_at, reaper, retry_delay

    # :nodoc:
    getter _avram_stack = [] of DB::Transaction

    # :nodoc:
    def expired?
      @expires_at.try &.<= Time.utc
    end

    def schedule_reaper!(pool : DB::Pool)
      return if @reaper || ttl.zero?
      ::Log.info { "scheduling reaper for #{object_id}, #{expires_at}" }

      self.reaper ||= Tasker.at(expires_at.not_nil!) { reap!(pool, ttl) }
    end

    def reap!(pool : DB::Pool, ttl : Int32) : Nil
      reaped = false

      ::Log.info { "reaping #{object_id}" }

      pool.each_resource do |cnn|
        if cnn.object_id == object_id
          ::Log.info { "closing #{cnn.object_id}" }
          reaped = true
          cnn.close
          spawn { pool.create_expiring_connection!(ttl, retry_delay) }
        end
      end

      # A Task can be scheduled for the future, but then the connection could
      # have been closed.
      return if reaped || closed?

      ::Log.info { "rescheduling #{object_id}, #{ttl}" }
      sleep(@retry_delay) && reap!(pool, ttl)
    end

    def create_expiring!(
      pool : DB::Pool,
      ttl_seconds : Int32,
      retry_delay : Int32
    )
      # Add some variance to prevent the thundering herd problem.
      ttl = (ttl_seconds * rand(-0.1..0.1)).floor.to_i + ttl_seconds
      self.ttl = ttl
      self.retry_delay = retry_delay
      self.expires_at = Time.utc + ttl.seconds

      return self if @reaper || ttl.zero?

      schedule_reaper!(pool)
      self
    end

    # :nodoc:
    def _avram_in_transaction? : Bool
      !_avram_stack.empty?
    end
  end
end
