module Store
  USERS = {}
  FILES = {}
  COUNTER = [0]

  def self.next_id
    COUNTER[0] += 1
  end
end
