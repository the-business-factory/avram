module DB
  abstract class Connection
    # :nodoc:
    getter _avram_stack = [] of DB::Transaction

    # :nodoc:
    property _expires_at : Time?

    # :nodoc:
    def expired?
      _expires_at.try &.<=(Time.utc)
    end

    def set_expiration!(seconds : Int32)
      # Stagger expiration to avoid thundering herd
      expires_in = rand((seconds * 0.5)..(seconds * 1.5)).floor.to_i
      self._expires_at ||= Time.utc + expires_in.seconds
    end

    def conndata
      "#{object_id}, #{_expires_at}"
    end

    # :nodoc:
    def _avram_in_transaction? : Bool
      !_avram_stack.empty?
    end
  end
end
