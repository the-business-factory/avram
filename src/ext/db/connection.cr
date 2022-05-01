module DB
  abstract class Connection
    MAX_TTL = 60 * 60 * 24 * 365

    @expires_at : Time?
    @ttl : Int32 = 0
    @reaper : Tasker::OneShot(Nil)?

    property ttl, expires_at, reaper

    # :nodoc:
    getter _avram_stack = [] of DB::Transaction

    # :nodoc:
    def expires_at : Time
      @expires_at || Time.utc + MAX_TTL.seconds
    end

    # :nodoc:
    def expired?
      expires_at <= Time.utc
    end

    def schedule_reaper!(pool : DB::Pool)
      return if do_not_add_reaper?
      puts "scheduling reaper for #{object_id}, #{expires_at}"

      self.reaper ||= Tasker.at(expires_at) { reap!(pool, ttl) }
    end

    def do_not_add_reaper?
      return true if ttl.zero?
      return true if @reaper
    end

    def reap!(pool : DB::Pool, ttl : Int32) : Nil
      puts "\n--------------"
      puts "running reaper: #{expires_at}\n"
      reaped = false
      pool.each_resource do |cnn|
        puts "checking #{cnn.object_id}"
        if cnn.object_id == object_id
          reaped = true
          puts "closing #{cnn.object_id}, #{cnn.expires_at}"
          cnn.close
          new_cnn = pool.create_expiring_connection!(ttl)
          puts "opened #{new_cnn.object_id}, expiring #{new_cnn.expires_at}"
        end
      end
      puts "--------------"
      puts "reaper done\n"

      unless reaped
        # connection likely wasn't in the @idle pool, need to reschedule the job
        old_expire = expires_at
        self.expires_at = Time.utc + 30.seconds # make this configurable
        puts "\n\nrescheduling: #{object_id} from #{old_expire} to #{expires_at}\n\n"
        schedule_reaper!(pool)
      end
    end

    def create_expiring!(pool : DB::Pool, ttl_in_seconds : Int32 = 0)
      self.ttl = ttl_in_seconds + rand(15..120)
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
