# frozen_string_literal: true

# meant to extend Statsd to capture what would be sent out the socket

module TrackSentMessage
  attr_reader :sent_messages

  def sent_message
    if defined?(@sent_messages) && @sent_messages
      @sent_messages.size <= 1 or raise "#{@sent_messages.size} sent_messages! #{sent_messages.inspect}"
      @sent_messages.first
    end
  end

  def send_to_socket(message)
    @sent_messages ||= []
    @sent_messages << message
  end
end
