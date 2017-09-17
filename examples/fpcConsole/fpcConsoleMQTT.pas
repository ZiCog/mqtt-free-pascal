program fpcConsoleMQTT;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp { you can add units after this },
  //old: CRT,
  MQTT,
  syncobjs, // TCriticalSection
  fptimer;

const
  MQTT_Server = 'orangepi.lan';

type
  { TMQTTGate }

  TMQTTGate = class(TCustomApplication)
  protected
    MQTTClient: TMQTTClient;

    SyncCode:   TCriticalSection;
    TimerTick: TFPTimer;
    cnt:      integer;

    // Unsafe events! Called from MQTT thread (TMQTTReadThread)
    procedure OnConnAck(Sender: TObject; ReturnCode: integer);
    procedure OnPingResp(Sender: TObject);
    procedure OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
    procedure OnUnSubAck(Sender: TObject);
    procedure OnPublish(Sender: TObject; topic, payload: ansistring; isRetain: boolean);

    procedure OnTimerTick(Sender: TObject);
    procedure DoRun; override;
  public
    procedure WriteHelp; virtual;
  end;

{old: const
  { ^C }
  //ContrBreakSIG = ^C; // yes, its valid string! (OMG!)
  //ContrBreakSIG = #$03;
}

function NewTimer(Intr: integer; Proc: TNotifyEvent; AEnable: boolean = false): TFPTimer;
begin
  Result := TFPTimer.Create(nil);
  Result.UseTimerThread:=false;
  Result.Interval := Intr;
  Result.OnTimer := Proc;
  Result.Enabled := AEnable;
end;

{ TMQTTGate }

procedure TMQTTGate.OnConnAck(Sender: TObject; ReturnCode: integer);
begin
  SyncCode.Enter;
  writeln('ConnAck');
  SyncCode.Leave;
end;

procedure TMQTTGate.OnPingResp(Sender: TObject);
begin
  SyncCode.Enter;
  writeln('PingResp');
  SyncCode.Leave;
end;

procedure TMQTTGate.OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
begin
  SyncCode.Enter;
  writeln('SubAck');
  SyncCode.Leave;
end;

procedure TMQTTGate.OnUnSubAck(Sender: TObject);
begin
  SyncCode.Enter;
  writeln('UnSubAck');
  SyncCode.Leave;
end;

procedure TMQTTGate.OnPublish(Sender: TObject; topic, payload: ansistring;
  isRetain: boolean);
begin
  SyncCode.Enter;
  writeln('Publish', ' topic=', topic, ' payload=', payload);
  SyncCode.Leave;
end;

procedure TMQTTGate.OnTimerTick(Sender: TObject);
begin
  SyncCode.Enter;
  cnt := cnt + 1;
  writeln('Tick. N='+IntToStr(cnt));
  MQTTClient.PingReq;
  MQTTClient.Publish('test', IntToStr(cnt));
  SyncCode.Leave;
end;

procedure TMQTTGate.DoRun;
var
  ErrorMsg: string;
begin
  StopOnException := True;
  SyncCode := TCriticalSection.Create();

  // quick check parameters
  ErrorMsg := CheckOptions('h', 'help');
  if ErrorMsg <> '' then
  begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then
  begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  // begin main program
  MQTTClient := TMQTTClient.Create(MQTT_Server, 1883);
  MQTTClient.OnConnAck := @OnConnAck;
  MQTTClient.OnPingResp := @OnPingResp;
  MQTTClient.OnPublish := @OnPublish;
  MQTTClient.OnSubAck := @OnSubAck;
  MQTTClient.Connect();

  //todo: wait 'OnConnAck'
  Sleep(1000);
  if not MQTTClient.isConnected then
  begin
    writeln('connect FAIL');
    exit;
  end;

  // mqtt subscribe to all topics
  MQTTClient.Subscribe('#');

  cnt := 0;
  TimerTick := NewTimer(5000, @OnTimerTick, true);
  try
    while (not Terminated) and (MQTTClient.isConnected) do
    begin
      // wait other thread
      CheckSynchronize(1000);

      //old: Check for ctrl-c
      {if KeyPressed then          //  <--- CRT function to test key press
        if ReadKey = ContrBreakSIG then      // read the key pressed
        begin
          writeln('Ctrl-C pressed.');
          Terminate;
        end;}
    end;

    MQTTClient.Unsubscribe('#');
    MQTTClient.Disconnect;
    Sleep(100);
    MQTTClient.ForceDisconnect;
  finally
    FreeAndNil(TimerTick);
    FreeAndNil(MQTTClient);
    FreeAndNil(SyncCode);
    Sleep(2000); // wait thread dies
  end;
  // stop program loop
  Terminate;
end;

procedure TMQTTGate.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TMQTTGate;

function MyCtrlBreakHandler(CtrlBr: boolean): boolean;
begin
  writeln('CtrlBreak pressed. Terminating.');
  Application.Terminate;
  Result := true;
end;

begin
  SysSetCtrlBreakHandler(@MyCtrlBreakHandler);
  Application := TMQTTGate.Create(nil);
  Application.Run;
  Application.Free;
end.

