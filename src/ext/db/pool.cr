module DB
  class Pool(T)
    def create_expiring_connection!(ttl : Int32, retry_delay : Int32)
      build_resource.tap do |conn|
        ::Log.info { "creating #{conn.object_id} w/ttl of #{ttl}" }
        conn.create_expiring!(self, ttl, retry_delay)
      end
    end
  end
end
