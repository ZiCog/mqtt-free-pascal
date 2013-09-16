


program simple;

uses  cthreads, Classes, SysUtils, MQTT, MQTTReadThread;

type
    { Define a simple class }
   //TSimple = class(TObject)
   TSimple = object
        procedure OnConnAck(Sender: TObject; ReturnCode: longint);
        procedure OnPingResp(Sender: TObject);
        procedure OnSubAck(Sender: TObject; MessageID : longint; GrantedQoS : longint);
        procedure OnUnSubAck(Sender: TObject);
        procedure OnPublish(Sender: TObject; topic, payload: string);
 end;

procedure TSimple.OnConnAck(Sender: TObject; ReturnCode: longint);
begin
//  writeln ('Connection Acknowledged, Return Code: ');  {   + IntToStr(Ord(ReturnCode))); }
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
end;


var
   s : TSimple;
   MQTTClient: TMQTTClient;
  
(*MAIN*)
begin
    //s.Create;

    MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);
    writeln ('mqtt created.');

    MQTTClient.OnConnAck := @s.OnConnAck;
    MQTTClient.OnPingResp := @s.OnPingResp;
    MQTTClient.OnPublish := @s.OnPublish;
    MQTTClient.OnSubAck := @s.OnSubAck;

    writeln (MQTTClient.Connect);

    MQTTClient.Subscribe('/rsm.ie/#');

    while True do
    begin
        MQTTClient.Publish('/rsm.ie/fits/detectors', '0101000101000111');
        CheckSynchronize(0);
        sleep(1000);
    end;
end.



