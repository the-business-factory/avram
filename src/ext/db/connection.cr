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
      ::Log.info { "scheduling reaper for #{Time.utc}, #{object_id}, #{expires_at}" }

      self.reaper ||= Tasker.at(expires_at.not_nil!) { reap!(pool, ttl) }
    end

    def reap!(pool : DB::Pool, ttl : Int32) : Nil
      reaped = false

      puts "\nreaping, closed: #{closed?}"
      ::Log.info { "reaping #{object_id}" }

      pool.each_resource do |cnn|
        puts "resource pool found #{cnn.object_id}"
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

      sleep(@retry_delay) && reap!(pool, ttl)
    end

    def create_expiring!(pool : DB::Pool, ttl_seconds = 0, retry_delay = 1)
      # ttl = (ttl_seconds * rand(0.5..1.5)).floor.to_i + ttl_seconds
      self.ttl = ttl_seconds
      self.retry_delay = retry_delay
      self.expires_at = Time.utc + 3.seconds

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
