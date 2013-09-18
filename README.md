mqtt-free-pascal
================

This the MQTT client code for Delphi by Jamie Ingilby with changes to make it useable in Free Pascal.

http://jamiei.com/blog/code/mqtt-client-library-for-delphi/

Changes:
--------

1) Rewrote the reader thread loop so as to make it simpler and faster also fixes a bug whereby the
client would segfault if the server went down and a major bug where timeouts on rx would cause data corruption.

2) Replaced the original client demo code with a simpler demo that does not use forms. I am using
this in an embedded system with no display.

3) Changed all strings to ansi strings so that it can have topics and payloads longer than 255 bytes. 

4) Also includes the parts of Ararat Synapse required to build.

To build the demo:
------------------

    $ cd examples/embeddedApp
    $ ./build


Running embeddedApp out of the box reqires you have access to test.mosquitto.org.

TODO
----




