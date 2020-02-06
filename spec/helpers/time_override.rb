# frozen_string_literal: true

class Time
  cattr_reader :now_override

  class << self
    def now_override= override_time
      if ActiveSupport::TimeWithZone === override_time
        override_time = override_time#.localtime
      else
        override_time.nil? || Time === override_time or raise "override_time should be a Time object, but was a #{override_time.class.name}"
      end
      @@now_override = override_time
    end

    unless defined? @@_old_now_defined
      alias old_now now
      @@_old_now_defined = true
    end
  end

  def self.now
    now_override ? now_override.dup : old_now
  end
end
