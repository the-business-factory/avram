module DB
  abstract class Connection
    # :nodoc:
    getter _avram_stack = [] of DB::Transaction

    # :nodoc:
    property _expires_at : Time?

    # :nodoc:
    def expired?
      _expires_at.try &.>=(Time.utc)
    end

    def set_expiration!(amount_in_seconds : Int32)
      self._expires_at ||= Time.utc + amount_in_seconds.seconds
    end

    # :nodoc:
    def _avram_in_transaction? : Bool
      !_avram_stack.empty?
    end
  end
end
