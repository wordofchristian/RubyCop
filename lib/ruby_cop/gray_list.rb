require 'set'

module RubyCop
  # Combination blacklist and whitelist.
  class GrayList
    attr_accessor :strict

    def initialize(strict = false)
      @strict = strict
      @blacklist = Set.new
      @whitelist = Set.new
    end

    # An item is allowed if it's whitelisted, or if it's not blacklisted.
    def allow?(item)
      item = item.to_s
      @whitelist.include?(item) || (!@blacklist.include?(item) && !strict)
    end

    def blacklist(item)
      @whitelist.delete(item)
      @blacklist.add(item)
    end

    def whitelist(item)
      @blacklist.delete(item)
      @whitelist.add(item)
    end
  end
end
