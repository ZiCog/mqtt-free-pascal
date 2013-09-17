
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

Program embeddedApp;

// cthreads is required to get the MQTTReadThread working.

Uses  cthreads, Classes, MQTT, sysutils;

// The major states of the application.

Type TembeddedAppStates = (
                           STARTING,
                           RUNNING,
                           FAILING
                          );

Type 
  // Define class for the embedded application
  // The MQTT callbacks must be methods of an object not stanalone procedures.
  TembeddedApp = Object
    MQTTClient: TMQTTClient;
    pingCounter : integer;
    pingTimer : integer;
    state : TembeddedAppStates;
    Procedure run ();
    Procedure OnConnAck(Sender: TObject; ReturnCode: longint);
    Procedure OnPingResp(Sender: TObject);
    Procedure OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
    Procedure OnUnSubAck(Sender: TObject);
    Procedure OnPublish(Sender: TObject; topic, payload: String);
  End;

Procedure TembeddedApp.OnConnAck(Sender: TObject; ReturnCode: longint);
Begin
  writeln ('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode)));
End;

Procedure TembeddedApp.OnPublish(Sender: TObject; topic, payload: String);
Begin
  writeln ('Publish Received. Topic: '+ topic + ' Payload: ' + payload);
End;

Procedure TembeddedApp.OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
Begin
  writeln ('Sub Ack Received');
End;

Procedure TembeddedApp.OnUnSubAck(Sender: TObject);
Begin
  writeln ('Unsubscribe Ack Received');
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
  state := STARTING;

  MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);

  // Setup callback handlers
  MQTTClient.OnConnAck := @OnConnAck;
  MQTTClient.OnPingResp := @OnPingResp;
  MQTTClient.OnPublish := @OnPublish;
  MQTTClient.OnSubAck := @OnSubAck;

  While true Do
    Begin
      Case state Of 
        STARTING :
                   Begin
                     // Connect to MQTT server
                     writeln('STARTING...');
                     pingCounter := 0;
                     pingTimer := 0;
                     If MQTTClient.Connect Then
                       Begin
                         // Make subscriptions
                         MQTTClient.Subscribe('/rsm.ie/#');
                         state := RUNNING;
                       End
                     Else
                       Begin
                         state := FAILING
                       End;
                   End;
        RUNNING :
                  Begin
                    // Publish stuff
                    If Not MQTTClient.Publish('/rsm.ie/fits/detectors', '0101000101000111') Then
                      Begin
                        state := FAILING;
                      End;

                    // Ping the MQTT server occasionally 
                    If (pingTimer Mod 10) = 0 Then
                      Begin
                        If Not MQTTClient.PingReq Then
                          Begin
                            state := FAILING;
                          End
                        Else
                          Begin
                            pingCounter := pingCounter + 1;
                          End;
                        // Check that pings are being answered
                        If pingCounter > 3 Then
                          Begin
                            writeln ('Pings unanswered');
                            state := FAILING;
                          End;
                      End;
                    pingTimer := pingTimer + 1;

                  End;
        FAILING :
                  Begin
                    writeln('FAILING...');
                    MQTTClient.ForceDisconnect;
                    state := STARTING;
                  End;
      End;

      // Synch with MQTT Reader Thread
      CheckSynchronize(0);

      // Yawn.
      sleep(1000);
    End;
End;


Var 
  app : TembeddedApp;

  // main
Begin
  app.run;
End.
