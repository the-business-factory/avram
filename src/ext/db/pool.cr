module DB
  class Pool(T)
    def create_expiring_connection!(amount_in_seconds)
      build_resource.tap do |connection|
        connection.set_expiration!(amount_in_seconds)
        ::Log.info { "DB Connection Opened: #{connection.conndata}" }
      end
    end
  end
end
