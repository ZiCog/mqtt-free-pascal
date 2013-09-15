
{$mode delphi}

program simple;

uses  cthreads, Classes, SysUtils, MQTT, MQTTReadThread;

type
    { Define a simple class }
    TSimple = class(TObject)
        procedure OnConnAck(Sender: TObject; ReturnCode: Integer);
        procedure OnPingResp(Sender: TObject);
        procedure OnSubAck(Sender: TObject; MessageID : Integer; GrantedQoS : Integer);
        procedure OnUnSubAck(Sender: TObject);
        procedure OnPublish(Sender: TObject; topic, payload: string);
 end;

procedure TSimple.OnConnAck(Sender: TObject; ReturnCode: Integer);
begin
//  writeln ('Connection Acknowledged, Return Code: ');  {   + IntToStr(Ord(ReturnCode))); }
end;

procedure TSimple.OnPublish(Sender: TObject; topic, payload: string);
begin
  writeln ('Publish Received. Topic: '+ topic + ' Payload: ' + payload);
end;

procedure TSimple.OnSubAck(Sender: TObject; MessageID : Integer; GrantedQoS : Integer);
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
   simple : TSimple;
   MQTTClient: TMQTTClient;
  
(*MAIN*)
begin
    simple.Create;

    MQTTClient := TMQTTClient.Create('test.mosquitto.org', 1883);
    writeln ('mqtt created.');

    MQTTClient.OnConnAck := simple.OnConnAck;
    MQTTClient.OnPingResp := simple.OnPingResp;
    MQTTClient.OnPublish := simple.OnPublish;
    MQTTClient.OnSubAck := simple.OnSubAck;

    writeln (MQTTClient.Connect);

    MQTTClient.Subscribe('/rsm.ie/#');

    while True do
    begin
        MQTTClient.Publish('/rsm.ie/fits/detectors', '0101000101000111');
        CheckSynchronize(0);
        sleep(1000);
    end;
end.



