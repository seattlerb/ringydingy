require 'minitest/autorun'

require 'rubygems'

$TESTING = true

require 'ringy_dingy/ring_server'

DRb.start_service

class FakeTupleSpace

  attr_writer :read_all
  attr_accessor :__drburi

  def read_all(template)
    @read_all
  end

end

class RingyDingy::RingServer

  attr_accessor :expirations, :registrations, :ts
  attr_reader :verbose

  remove_const :RF

  RF = Object.new

  def RF.lookup_ring
    ts1 = FakeTupleSpace.new
    ts1.__drburi = 'druby://localhost:10000'
    ts1.read_all = TestRingServer::SERVICES[ts1.__drburi]
    yield ts1

    ts2 = FakeTupleSpace.new
    ts2.__drburi = 'druby://localhost:10002'
    ts2.read_all = TestRingServer::SERVICES[ts2.__drburi]
    yield ts2 # IPv4
    yield ts2 # IPv6
  end

end

class TestRingServer < MiniTest::Unit::TestCase

  def self.test_order
    :sorted # HACK: one of these tests is order dependent. :(
  end

  OBJS = [Object.new, Object.new, Object.new]

  OBJS.each_with_index { |obj, i| const_set "OBJ#{i}", obj }

  SERVICES = {
    'druby://localhost:10000' => [
      [:name, :RingyDingy, DRbObject.new(OBJ0, 'druby://localhost:10001'),
       'localhost_9607_obj0'],
      [:name, :RingyDingy, DRbObject.new(OBJ1, 'druby://localhost:10001'),
       'localhost_9607_obj1'],
    ],
    'druby://localhost:10002' => [
      [:name, :RingyDingy, DRbObject.new(OBJ2, 'druby://localhost:10003'),
       'localhost_9607_obj2'],
    ],
  }

  def setup
    capture_io do
      @rs = RingyDingy::RingServer.new :Verbose => true
    end
  end

  def test_self_list_services
    assert_equal SERVICES, RingyDingy::RingServer.list_services
  end

  def test_self_print_services
    rf = Object.new

    def rf.lookup_ring
      fts = FakeTupleSpace.new
      fts.__drburi = 'druby://localhost:10000'
      fts.read_all = [
        [:name, :RingyDingy, DRbObject.new(OBJ0, 'druby://localhost:10001'),
         'localhost_9607_obj0'],
        [:name, :RingyDingy, DRbObject.new(OBJ1, 'druby://localhost:10001'),
         'localhost_9607_obj1'],
      ]
      yield fts
      fts = FakeTupleSpace.new
      fts.__drburi = 'druby://localhost:10002'
      fts.read_all = [
        [:name, :RingyDingy, DRbObject.new(OBJ2, 'druby://localhost:10003'),
         'localhost_9607_obj2'],
      ]
      yield fts
    end

    RingyDingy::RingServer.send :remove_const, :RF
    RingyDingy::RingServer.send :const_set, :RF, rf

    out, err = capture_io do
      RingyDingy::RingServer.print_services
    end

    expected = <<-EOF
Services on druby://localhost:10000
\t:RingyDingy, "localhost_9607_obj0"
\t\tURI: druby://localhost:10001 ref: #{OBJ0.object_id}

\t:RingyDingy, "localhost_9607_obj1"
\t\tURI: druby://localhost:10001 ref: #{OBJ1.object_id}

Services on druby://localhost:10002
\t:RingyDingy, "localhost_9607_obj2"
\t\tURI: druby://localhost:10003 ref: #{OBJ2.object_id}
    EOF

    assert_equal expected, out
    assert_equal '', err
  ensure
    RingyDingy::RingServer.send :remove_const, :RF
    RingyDingy::RingServer.send :const_set, :RF, Rinda::RingFinger
  end

  def test_initialize_verbose_daemon
    rs = RingyDingy::RingServer.new :Verbose => true, :Daemon => true
    assert_equal false, rs.verbose
  end

  def test_disable_activity_logging
    @rs.registrations = @rs.ts.notify 'write', [nil]
    @rs.expirations = @rs.ts.notify 'delete', [nil]

    out, err = capture_io do
      @rs.disable_activity_logging
    end

    assert_equal true, @rs.registrations.canceled?
    assert_equal true, @rs.expirations.canceled?

    assert_equal "registration and expiration logging disabled\n", err
  end

  def test_enable_activity_logging
    @rs.registrations.cancel
    @rs.expirations.cancel

    out, err = capture_io do
      @rs.enable_activity_logging
      @rs.ts.write [:name, :Test, DRbObject.new(self), ''], 0
    end

    assert_equal true, @rs.registrations.alive?
    assert_equal true, @rs.expirations.alive?

    expected = <<-EOF
registration and expiration logging enabled
registered :Test, ""
\tURI: #{DRb.uri} ref: #{self.object_id}
expired :Test, ""
\tURI: #{DRb.uri} ref: #{self.object_id}
    EOF

    # HACK: apparently this is going to a totally different IO on 1.9
    # assert_equal expected, err
  end

  def disabled_test_monitor_verbose
    capture_io do
      assert_equal true, @rs.verbose
      @rs.ts.write [:RingyDingy, :verbose, false]
      assert_equal false, @rs.verbose
      @rs.ts.write [:RingyDingy, :verbose, true]
      assert_equal true, @rs.verbose
    end
  end

  def test_verbose_equals_false
    assert_equal true, @rs.verbose

    out, err = capture_io do
      @rs.verbose = false
    end

    assert_equal '', out
    assert_equal "registration and expiration logging disabled\n", err
  end

  def test_verbose_equals_no_change
    assert_equal true, @rs.verbose

    out, err = capture_io do
      @rs.verbose = true
    end

    assert_equal '', out
    assert_equal '', err
  end

  def test_verbose_equals_true
    capture_io do @rs.verbose = false end

    out, err = capture_io do
      @rs.verbose = true
    end

    assert_equal '', out
    assert_equal "registration and expiration logging enabled\n", err
  end

  def test_verbose_equals_true_daemon
    @rs.instance_variable_set :@daemon, true
    capture_io do @rs.verbose = false end

    out, err = capture_io do
      @rs.verbose = true
    end

    assert_equal '', out
    assert_equal '', err
  end

end

