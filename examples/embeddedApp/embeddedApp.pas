
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
  // The MQTT callbacks must be methods of an object not stanalone procedures.
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
      procedure OnConnAck(Sender: TObject; ReturnCode: longint);
      procedure OnPingResp(Sender: TObject);
      procedure OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
      procedure OnUnSubAck(Sender: TObject);
      procedure OnPublish(Sender: TObject; topic, payload: ansistring);
    public 
      procedure run ();
    end;

    procedure TembeddedApp.OnConnAck(Sender: TObject; ReturnCode: longint);
    begin
      writeln ('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode)));
      // Make subscriptions
      MQTTClient.Subscribe('/rsm.ie/fits/detectors');
      // Enter the running state
      state := RUNNING;
    end;

    procedure TembeddedApp.OnPublish(Sender: TObject; topic, payload: ansistring);
    begin
      writeln ('Publish Received. Topic: '+ topic + ' Payload: ' + payload);
    end;

    procedure TembeddedApp.OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
    begin
      writeln ('################################################################################');
      writeln ('Sub Ack Received');
      writeln ('################################################################################');
    end;

    procedure TembeddedApp.OnUnSubAck(Sender: TObject);
    begin
      writeln ('Unsubscribe Ack Received');
    end;

    procedure TembeddedApp.OnPingResp(Sender: TObject);
    begin
      writeln ('PING! PONG!');
      // Reset ping counter to indicate all is OK.
      pingCounter := 0;
    end;

    procedure TembeddedApp.run();
    begin
      writeln ('embeddedApp MQTT Client.');
      state := CONNECT;

      message := 
           'All work and no play makes Jack a dull boy. All work and no play makes Jack a dull boy.'
      ;

     //MQTTClient := TMQTTClient.Create('www.google.com', 1883);
     MQTTClient := TMQTTClient.Create('www.mosquitto.org', 1883);

      // Setup callback handlers
      MQTTClient.OnConnAck := @OnConnAck;
      MQTTClient.OnPingResp := @OnPingResp;
      MQTTClient.OnPublish := @OnPublish;
      MQTTClient.OnSubAck := @OnSubAck;

      while true do
        begin
          Writeln('Embedded app running:', TimeStampToMSecs(DateTimeToTimeStamp(Now)));
          case state of 
            CONNECT :
                       begin
                         // Connect to MQTT server
                         writeln('CONNECTING...');
                         pingCounter := 0;
                         pingTimer := 0;
                         pubTimer := 0;
                         connectTimer := 0;
                         if MQTTClient.Connect then
                           begin
                             Writeln('!!!!!!!!!!!!!! CONNECT OK !!!!!!!!!!!!');
                             state := WAIT_CONNECT;
                           end
                         else
                           begin
                             Writeln('!!!!!!!!!!!!!! CONNECT FAILED !!!!!!!!!!!!');
                             state := FAILING
                           end;
                       end;
            WAIT_CONNECT :
                       begin
                             // Can only move to RUNNING state on recieving ConnAck 
                             connectTimer := connectTimer + 1;
                             if connectTimer > 10 then
                               state := FAILING; 
                       end;
            RUNNING :
                      begin

                        // Publish stuff
                        if pubTimer mod 10 = 0 then
                          begin
                            if MQTTClient.Publish('/jack/says/', message) then
                              begin
                                writeln ('------------------ PUBLISH OK ----------------------');
                              end
                            else
                              begin
                                writeln ('!!!!!!!!!!!!!!!!!! PUBLISH FAILED !!!!!!!!!!!!!!!!!!');
                                //state := FAILING;
                              end;
                          end;
                        pubTimer := pubTimer + 1;

                        // Ping the MQTT server occasionally 
                        if (pingTimer mod 10) = 0 then
                          begin
                            // Time to PING !
                            if not MQTTClient.PingReq then
                              begin
                                Writeln('!!!!!!!!!!!!!! Ping send failed !!!!!!!!!!!!');
                                  state := FAILING;
                                  sleep(1000);
                              end;
                            pingCounter := pingCounter + 1;
                            // Check that pings are being answered
                            if pingCounter > 3 then
                              begin
                                writeln ('Pings unanswered');
                                state := FAILING;
                              end;
                          end;
                        pingTimer := pingTimer + 1;
                      end;
            FAILING :
                      begin
                        writeln('FAILING...');
                        MQTTClient.ForceDisconnect;
                        state := CONNECT;
                      end;
          end;

          // Synch with MQTT Reader Thread
          CheckSynchronize(0);

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
