= RingyDingy

RingyDingy is a little boat that keeps your DRb service afloat!

Rubyforge Project:

http://rubyforge.org/projects/seattlerb

Documentation:

ri RingyDingy

== About

RingyDingy automatically registers a service with a RingServer.  If
communication between the RingServer and the RingyDingy is lost, RingyDingy
will re-register its service with the RingServer when it reappears.

Similarly, the RingServer will automatically drop registrations by a RingyDingy
that it can't communicate with after a short timeout.

RingyDingy also includes a RingServer wrapper that adds verbose mode to see
what services as they register and expire and an option to list all available
services on the network.

== Installing RingyDingy

Just install the gem:

  $ sudo gem install RingyDingy

== Using RingyDingy

  require 'rubygems'
  require 'ringy_dingy'
  require 'my_drb_service'
  
  my_drb_service = MyDRbService.new
  
  RingyDingy.new(my_drb_service).run
  
  DRb.thread.join

== Using RingyDingy::RingServer

To start a RingServer:

  $ ring_server

To list services on the network:

  $ ring_server -l

To enable or disable verbose mode remotely:

  $ ring_server --set-logging=true/false

