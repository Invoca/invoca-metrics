# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Invoca::Metrics::StatsdWithPersistentConnection do
  subject { described_class.new("127.0.0.1", 8125) }

  before(:each) { Thread.current.thread_variable_set(:statsd_socket, nil) }

  # This test will fail with destination address required if not connected
  it "connect the socket so we don't do extra DNS queries" do
    socket = subject.send(:socket)
    socket.send("test message", 0)
  end

  it "use a bound udp socket to connect to statsd" do
    addr = subject.send(:socket).remote_address
    expect(addr.ip_address).to eq("127.0.0.1")
    expect(addr.ip_port).to eq(8125)
  end

  it "use a new socket per Thread" do
    main_socket = subject.send(:socket)
    new_thread  = Thread.new do
      thread_socket = subject.send(:socket)
      expect(main_socket.fileno != thread_socket.fileno).to be_truthy
    end
    new_thread.join
  end

  it "not use a new socket per Fiber" do
    main_socket = subject.send(:socket)
    new_fiber   = Fiber.new do
      fiber_socket = subject.send(:socket)
      Fiber.yield((main_socket.fileno == fiber_socket.fileno))
    end
    expect(new_fiber.resume).to be_truthy
  end
end
