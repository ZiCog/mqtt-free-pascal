


{
 -------------------------------------------------
  embeddedApp.pas -  An example of using the MQTT Client from a command line program
                     as might be used in an embedded system.

  MQTT - http://mqtt.org/
  Spec - http://publib.boulder.ibm.com/infocenter/wmbhelp/v6r0m0/topic/com.ibm.etools.mft.doc/ac10840_.htm

  MIT License -  http://www.opensource.org/licenses/mit-license.php
  Copyright (c) 2009 RSM Ltd.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
   -------------------------------------------------
}

{$mode objfpc}

program embeddedApp;

// cthreads is required to get the MQTTReadThread working.

uses  cthreads, Classes, MQTT, sysutils;

// The major states of the application.

type TembeddedAppStates = (
                           CONNECT,
                           WAIT_CONNECT,
                           RUNNING,
                           FAILING
                          );

type 
  // Define class for the embedded application
  TembeddedApp = object
    strict
    private 
      MQTTClient: TMQTTClient;
      pingCounter : integer;
      pingTimer : integer;
      state : TembeddedAppStates;
      message : ansistring;
      pubTimer : integer;
      connectTimer : integer;
    public 
      procedure run ();
    end;

    procedure TembeddedApp.run();

    var 
      msg : TMQTTMessage;
      ack : TMQTTMessageAck;
    begin
      writeln ('embeddedApp MQTT Client.');
      state := CONNECT;

      message := 
           'All work and no play makes Jack a dull boy. All work and no play makes Jack a dull boy.'
      ;

      MQTTClient := TMQTTClient.Create('192.168.0.26', 1883);

      while true do
        begin
          case state of 
            CONNECT :
                      begin
                        // Connect to MQTT server
                        pingCounter := 0;
                        pingTimer := 0;
                        pubTimer := 0;
                        connectTimer := 0;
                        MQTTClient.Connect;
                        state := WAIT_CONNECT;
                      end;
            WAIT_CONNECT :
                           begin
                             // Can only move to RUNNING state on recieving ConnAck 
                             connectTimer := connectTimer + 1;
                             if connectTimer > 300 then
                               begin
                                 Writeln('embeddedApp: Error: ConnAck time out.');
                                 state := FAILING;
                               end;
                           end;
            RUNNING :
                      begin
                        // Publish stuff
                        if pubTimer mod 1 = 0 then
                          begin
                            if not MQTTClient.Publish('/jack/says/', message) then
                              begin
                                writeln ('embeddedApp: Error: Publish Failed.');
                                state := FAILING;
                              end;
                          end;
                        pubTimer := pubTimer + 1;

                        // Ping the MQTT server occasionally 
                        if (pingTimer mod 100) = 0 then
                          begin
                            // Time to PING !
                            if not MQTTClient.PingReq then
                              begin
                                writeln ('embeddedApp: Error: PingReq Failed.');
                                state := FAILING;
                              end;
                            pingCounter := pingCounter + 1;
                            // Check that pings are being answered
                            if pingCounter > 3 then
                              begin
                                writeln ('embeddedApp: Error: Ping timeout.');
                                state := FAILING;
                              end;
                          end;
                        pingTimer := pingTimer + 1;
                      end;
            FAILING :
                      begin
                        MQTTClient.ForceDisconnect;
                        state := CONNECT;
                      end;
          end;

          // Read incomming MQTT messages.
          repeat
            msg := MQTTClient.getMessage;
            if Assigned(msg) then
              begin
                writeln ('getMessage: ' + msg.topic + ' Payload: ' + msg.payload);

                // Important to free messages here. 
                msg.free;
              end;
          until not Assigned(msg);

          // Read incomming MQTT message acknowledgments
          repeat
            ack := MQTTClient.getMessageAck;
            if Assigned(ack) then
              begin
                case ack.messageType of 
                  CONNACK :
                            begin
                              if ack.returnCode = 0 then
                                begin
                                  // Make subscriptions
                                  MQTTClient.Subscribe('/jack/says/');
                                  // Enter the running state
                                  state := RUNNING;
                                end
                              else
                                state := FAILING;
                            end;
                  PINGRESP :
                             begin
                               writeln ('PING! PONG!');
                               // Reset ping counter to indicate all is OK.
                               pingCounter := 0;
                             end;
                  SUBACK :
                           begin
                             write   ('SUBACK: ');
                             write   (ack.messageId);
                             write   (', ');
                             writeln (ack.qos);
                           end;
                  UNSUBACK :
                             begin
                               write   ('UNSUBACK: ');
                               writeln (ack.messageId);
                             end;
                end;
              end;
            // Important to free messages here. 
            ack.free;
          until not Assigned(ack);

          // Main application loop must call this else we leak threads!
          CheckSynchronize;

          // Yawn.
          sleep(100);
        end;
    end;

    var 
      app : TembeddedApp;

      // main
    begin
      app.run;
    end.
