module DB
  class Pool(T)
    def _new_connection!
      build_resource
    end
  end
end
