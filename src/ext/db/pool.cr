module DB
  class Pool(T)
    def create_expiring_connection!(ttl : Int32)
      build_resource.tap &.create_expiring!(self, ttl)
    end
  end
end
