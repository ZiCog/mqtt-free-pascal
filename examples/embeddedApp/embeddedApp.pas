
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
                           STARTING,
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
    end;

    procedure TembeddedApp.OnPublish(Sender: TObject; topic, payload: ansistring);
    begin
      writeln ('Publish Received. Topic: '+ topic + ' Payload: ' + payload);
    end;

    procedure TembeddedApp.OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
    begin
      writeln ('Sub Ack Received');
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
      state := STARTING;

      message := 
           'All work and no play makes Jack a dull boy. All work and no play makes Jack a dull boy.'
      ;

      MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);

      // Setup callback handlers
      MQTTClient.OnConnAck := @OnConnAck;
      MQTTClient.OnPingResp := @OnPingResp;
      MQTTClient.OnPublish := @OnPublish;
      MQTTClient.OnSubAck := @OnSubAck;

      while true do
        begin
          case state of 
            STARTING :
                       begin
                         // Connect to MQTT server
                         writeln('STARTING...');
                         pingCounter := 0;
                         pingTimer := 0;
                         pubTimer := 50;
                         if MQTTClient.Connect then
                           begin
                             // Make subscriptions
                             MQTTClient.Subscribe('/jack/says/#');
                             state := RUNNING;
                           end
                         else
                           begin
                             state := FAILING
                           end;
                       end;
            RUNNING :
                      begin
                        // Publish stuff
                        if pubTimer mod 10 = 0 then
                          begin
                            if not MQTTClient.Publish('/jack/says/', message) then
                              begin
                                state := FAILING;
                              end;
                          end;
                        pubTimer := pubTimer + 1;

                        // Ping the MQTT server occasionally 
                        if (pingTimer mod 100) = 0 then
                          begin
                            if not MQTTClient.PingReq then
                              begin
                                state := FAILING;
                              end
                            else
                              begin
                                pingCounter := pingCounter + 1;
                              end;
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
                        state := STARTING;
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
