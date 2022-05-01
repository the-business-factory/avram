module DB
  class Pool(T)
    def create_expiring_connection!(amount_in_seconds)
      build_resource.tap &.set_expiration!(amount_in_seconds)
    end
  end
end
