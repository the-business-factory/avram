module DB
  class Pool(T)
    def create_expiring_connection!(ttl : Int32, retry_delay : Int32)
      build_resource.tap &.create_expiring!(self, ttl, retry_delay)
    end
  end
end
