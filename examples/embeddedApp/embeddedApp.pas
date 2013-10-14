
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

Program embeddedApp;

// cthreads is required to get the MQTTReadThread working.

Uses  cthreads, Classes, MQTT, sysutils;

// The major states of the application.

Type TembeddedAppStates = (
                           CONNECT,
                           WAIT_CONNECT,
                           RUNNING,
                           FAILING
                          );

Type 
  // Define class for the embedded application
  // The MQTT callbacks must be methods of an object not stanalone procedures.
  TembeddedApp = Object
    strict
    Private 
      MQTTClient: TMQTTClient;
      pingCounter : integer;
      pingTimer : integer;
      state : TembeddedAppStates;
      message : ansistring;
      pubTimer : integer;
      connectTimer : integer;
      Procedure OnConnAck(Sender: TObject; ReturnCode: longint);
      Procedure OnPingResp(Sender: TObject);
      Procedure OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
      Procedure OnUnSubAck(Sender: TObject);
      Procedure OnPublish(Sender: TObject; topic, payload: ansistring);
    Public 
      Procedure run ();
  End;

Procedure TembeddedApp.OnConnAck(Sender: TObject; ReturnCode: longint);
Begin
  writeln ('OnConnAck: Return Code = ' + IntToStr(Ord(ReturnCode)));
  If ReturnCode = 0 Then
    Begin
      // Make subscriptions
      MQTTClient.Subscribe('/rsm.ie/fits/detectors');
      // Enter the running state
      state := RUNNING;
    End
  Else
    state := FAILING;
End;

Procedure TembeddedApp.OnPublish(Sender: TObject; topic, payload: ansistring);
Begin
  writeln ('OnPublish: Topic: '+ topic + ' Payload: ' + payload);
End;

Procedure TembeddedApp.OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
Begin
  writeln ('OnSubAck:');
End;

Procedure TembeddedApp.OnUnSubAck(Sender: TObject);
Begin
  writeln ('OnUnSubAck:');
End;

Procedure TembeddedApp.OnPingResp(Sender: TObject);
Begin
  writeln ('PING! PONG!');
  // Reset ping counter to indicate all is OK.
  pingCounter := 0;
End;

Procedure TembeddedApp.run();
Begin
  writeln ('embeddedApp MQTT Client.');
  state := CONNECT;

  message := 


           'All work and no play makes Jack a dull boy. All work and no play makes Jack a dull boy.'
  ;

  //MQTTClient := TMQTTClient.Create('localhost', 1883);
  MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);

  // Setup callback handlers
  MQTTClient.OnConnAck := @OnConnAck;
  MQTTClient.OnPingResp := @OnPingResp;
  MQTTClient.OnPublish := @OnPublish;
  MQTTClient.OnSubAck := @OnSubAck;

  While true Do
    Begin
      Case state Of 
        CONNECT :
                  Begin
                    // Connect to MQTT server
                    pingCounter := 0;
                    pingTimer := 0;
                    pubTimer := 0;
                    connectTimer := 0;
                    MQTTClient.Connect;
                    state := WAIT_CONNECT;
                  End;
        WAIT_CONNECT :
                       Begin
                         // Can only move to RUNNING state on recieving ConnAck 
                         connectTimer := connectTimer + 1;
                         If connectTimer > 300 Then
                           Begin
                             Writeln('embeddedApp: Error: ConnAck time out.');
                             state := FAILING;
                           End;
                       End;
        RUNNING :
                  Begin

                    // Publish stuff
                    If pubTimer Mod 100 = 0 Then
                      Begin
                        If Not MQTTClient.Publish('/jack/says/', message) Then
                          Begin
                            writeln ('embeddedApp: Error: Publish Failed.');
                            state := FAILING;
                          End;
                      End;
                    pubTimer := pubTimer + 1;

                    // Ping the MQTT server occasionally 
                    If (pingTimer Mod 100) = 0 Then
                      Begin
                        // Time to PING !
                        If Not MQTTClient.PingReq Then
                          Begin
                            writeln ('embeddedApp: Error: PingReq Failed.');
                            state := FAILING;
                          End;
                        pingCounter := pingCounter + 1;
                        // Check that pings are being answered
                        If pingCounter > 3 Then
                          Begin
                            writeln ('embeddedApp: Error: Ping timeout.');
                            state := FAILING;
                          End;
                      End;
                    pingTimer := pingTimer + 1;
                  End;
        FAILING :
                  Begin
                    MQTTClient.ForceDisconnect;
                    state := CONNECT;
                  End;
      End;

      // Synch with MQTT Reader Thread
      CheckSynchronize(0);

      // Yawn.
      sleep(10);
    End;
End;


Var 
  app : TembeddedApp;

  // main
Begin
  app.run;
End.
