
program simple;

uses  cthreads, Classes, SysUtils, MQTT, MQTTReadThread;

type TSimpleStates = (
          STARTING,
          RUNNING,
          FAILING
        );
type
    { Define a simple class }
   TSimple = object
        MQTTClient: TMQTTClient;
        pingCounter : integer;
        pingTimer : integer;
        state : TSimpleStates;
        procedure run ();
        procedure OnConnAck(Sender: TObject; ReturnCode: longint);
        procedure OnPingResp(Sender: TObject);
        procedure OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
        procedure OnUnSubAck(Sender: TObject);
        procedure OnPublish(Sender: TObject; topic, payload: string);
end;

procedure TSimple.OnConnAck(Sender: TObject; ReturnCode: longint);
begin
  writeln ('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode))); 
end;

procedure TSimple.OnPublish(Sender: TObject; topic, payload: string);
begin
  writeln ('Publish Received. Topic: '+ topic + ' Payload: ' + payload);
end;

procedure TSimple.OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
begin
  writeln ('Sub Ack Received');
end;

procedure TSimple.OnUnSubAck(Sender: TObject);
begin
  writeln ('Unsubscribe Ack Received');
end;

procedure TSimple.OnPingResp(Sender: TObject);
begin
  writeln ('PING! PONG!');
  pingCounter := 0;
  write('Ping counter : ');
  writeln (pingCounter);
end;

procedure TSimple.run();
begin
    writeln ('Simple MQTT Client test.');
    state := STARTING;

    // MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);
    MQTTClient := TMQTTClient.Create('192.168.0.12', 1883);
    writeln ('mqtt created.');

    { Setup callback handlers }
    MQTTClient.OnConnAck := @OnConnAck;
    MQTTClient.OnPingResp := @OnPingResp;
    MQTTClient.OnPublish := @OnPublish;
    MQTTClient.OnSubAck := @OnSubAck;

    while true do
    begin
        case state of
            STARTING : begin
                    { Connect to MQTT server }
                    writeln('State: STARTING');
                    pingCounter := 0;
                    pingTimer := 0;
                    if MQTTClient.Connect then
                    begin
                        { Make subscriptions }
                        MQTTClient.Subscribe('/rsm.ie/#');
                        state := RUNNING;
                    end
                    else
                    begin
                        state := FAILING
                    end;
                end;
            RUNNING : begin
                    { Publish stuff }
                    writeln('State: RUNNING');
                    if not MQTTClient.Publish('/rsm.ie/fits/detectors', '0101000101000111') then
                    begin
                        state := FAILING; 
                    end;

                    // Ping the MQTT server occasionally 
                    if (pingTimer mod 10) = 0 then
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
            FAILING : begin
                    writeln('State: FAILING');
                    MQTTClient.ForceDisconnect;
                    state := STARTING;
                end;
        end;
 
        { Synch with threads }
        CheckSynchronize(0);

        { Yawn }
        sleep(1000);
   end;
end;


var
   s : TSimple;

(*MAIN*)
begin
    s.run;
end.



