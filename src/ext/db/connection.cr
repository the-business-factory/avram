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
      return if do_not_add_reaper?
      puts "scheduling reaper for #{object_id}, #{expires_at}"

      self.reaper ||= Tasker.at(expires_at.not_nil!) { reap!(pool, ttl) }
    end

    def do_not_add_reaper?
      return true if ttl.zero?
      return true if @reaper
    end

    def reap!(pool : DB::Pool, ttl : Int32) : Nil
      reaped = false
      puts "\n--------------"
      puts "running reaper: #{expires_at}\n"

      pool.each_resource do |cnn|
        if cnn.object_id == object_id
          puts "closing #{cnn.object_id}"
          reaped = true
          cnn.close
          spawn { pool.create_expiring_connection!(ttl, retry_delay) }
        end
      end

      puts "--------------"
      puts "reaper done\n"

      sleep(@retry_delay) && reap!(pool, ttl) unless reaped
    end

    def create_expiring!(pool : DB::Pool, ttl_seconds = 0, retry_delay = 1)
      self.ttl = ttl_seconds
      self.retry_delay = retry_delay
      self.expires_at = Time.utc + ttl.seconds

      return self if do_not_add_reaper?

      schedule_reaper!(pool)
      self
    end

    # :nodoc:
    def _avram_in_transaction? : Bool
      !_avram_stack.empty?
    end
  end
end
