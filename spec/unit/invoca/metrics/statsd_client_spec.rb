# frozen_string_literal: true

require_relative '../../../spec_helper'

describe Invoca::Metrics::StatsdClient do
  subject { described_class.new("127.0.0.1", 8125) }

  before(:each) { Thread.current.thread_variable_set(:statsd_socket, nil) }
  after(:each) do
    Invoca::Metrics::StatsdClient.logger = nil
    Invoca::Metrics::StatsdClient.log_send_failures = true
  end

  # This test will fail with destination address required if not connected
  it "connects the socket so we don't do extra DNS queries" do
    socket = subject.send(:socket)
    socket.send("test message", 0)
  end

  it "uses a bound udp socket to connect to statsd" do
    addr = subject.send(:socket).remote_address
    expect(addr.ip_address).to eq("127.0.0.1")
    expect(addr.ip_port).to eq(8125)
  end

  it "uses a new socket per Thread" do
    main_socket = subject.send(:socket)
    new_thread  = Thread.new do
      thread_socket = subject.send(:socket)
      expect(main_socket.fileno != thread_socket.fileno).to be_truthy
    end
    new_thread.join
  end

  it "does not use a new socket per Fiber" do
    main_socket = subject.send(:socket)
    new_fiber   = Fiber.new do
      fiber_socket = subject.send(:socket)
      Fiber.yield((main_socket.fileno == fiber_socket.fileno))
    end
    expect(new_fiber.resume).to be_truthy
  end

  context "with logger" do
    let(:log_stream) { StringIO.new }
    let(:logger) { Logger.new(log_stream) }
    before(:each) { Invoca::Metrics::StatsdClient.logger = logger }

    context "with log_send_failures = true" do
      before { Invoca::Metrics::StatsdClient.log_send_failures = true }

      describe "#send_to_socket" do
        it "rescues and logs exceptions" do
          message = "ABC"
          expect(subject.send(:socket)).to receive(:send).with(message, 0) { raise "!!!" }
          subject.send_to_socket(message)
          log_messages = log_stream.string.split("\n")
          expect(log_messages[0]).to match(/Statsd: ABC\z/)
          expect(log_messages[1]).to match(/Statsd exception sending: RuntimeError: !!!\z/)
        end
      end
    end

    context "with log_send_failures = false" do
      before { Invoca::Metrics::StatsdClient.log_send_failures = false }

      describe "#send_to_socket" do
        it "rescues and logs exceptions" do
          message = "ABC"
          expect(subject.send(:socket)).to receive(:send).with(message, 0) { raise "!!!" }
          subject.send_to_socket(message)
          log_messages = log_stream.string.split("\n")
          expect(log_messages[0]).to match(/Statsd: ABC\z/)
          expect(log_messages[1]).to eq(nil)
        end
      end
    end
  end

  context "without logger" do
    before(:each) { Invoca::Metrics::StatsdClient.logger = nil }

    describe "#send_to_socket" do
      it "rescues and stays silent" do
        message = "ABC"
        expect(subject.send(:socket)).to receive(:send).with(message, 0) { raise "!!!" }
        subject.send_to_socket(message)
      end
    end
  end
end
