# frozen_string_literal: true

class Time
  class << self
    attr_reader :now_override

    def now_override=(override_time)
      override_time.nil? || override_time.is_a?(Time) or raise "override_time should be a Time object, but was a #{override_time.class.name}"
      @now_override = override_time
    end

    unless defined? @_old_now_defined
      alias old_now now
      @_old_now_defined = true
    end

    def now
      now_override ? now_override.dup : old_now
    end
  end
end
