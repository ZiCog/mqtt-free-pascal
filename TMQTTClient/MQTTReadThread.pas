{
 -------------------------------------------------
  MQTTReadThread.pas -  Contains the socket receiving thread that is part of the
  TMQTTClient library (MQTT.pas).

  MIT License -  http://www.opensource.org/licenses/mit-license.php
  Copyright (c) 2009 Jamie Ingilby

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

unit MQTTReadThread;

interface


uses
  SysUtils, Classes, blcksock, BaseUnix;


type TBytes = array of Byte;

type
  TMQTTMessage = Record
    FixedHeader: Byte;
    RL: TBytes;
    Data: TBytes;
  End;

Type TRxStates = (RX_START, RX_FIXED_HEADER, RX_LENGTH, RX_DATA, RX_ERROR);


  PTCPBlockSocket = ^TTCPBlockSocket;

// NEW...
  //  Message type. 4 Bit unsigned.
  TMQTTMessageType = (
          Reserved0, //0    Reserved
          CONNECT, //   1   Client request to connect to Broker
          CONNACK, //   2   Connect Acknowledgment
          PUBLISH, //   3   Publish message
          PUBACK, //    4   Publish Acknowledgment
          PUBREC, //    5   Publish Received (assured delivery part 1)
          PUBREL, //    6   Publish Release (assured delivery part 2)
          PUBCOMP, //   7   Publish Complete (assured delivery part 3)
          SUBSCRIBE, // 8   Client Subscribe request
          SUBACK, //    9   Subscribe Acknowledgment
          UNSUBSCRIBE, // 10    Client Unsubscribe request
          UNSUBACK, // 11   Unsubscribe Acknowledgment
          PINGREQ, //   12  PING Request
          PINGRESP, //  13  PING Response
          DISCONNECT, // 14 Client is Disconnecting
          Reserved15 // 15
        );
  TRemainingLength = Array of Byte;

  TUTF8Text = Array of Byte;


// ...END NEW


  TConnAckEvent = procedure (Sender: TObject; ReturnCode: integer) of object;
  TPublishEvent = procedure (Sender: TObject; topic, payload: ansistring) of object;
  TPingRespEvent = procedure (Sender: TObject) of object;
  TSubAckEvent = procedure (Sender: TObject; MessageID: integer; GrantedQoS: integer) of object;
  TUnSubAckEvent = procedure (Sender: TObject; MessageID: integer) of object;

  TMQTTReadThread = class(TThread)
  private
    FClientID: ansistring;
    FPSocket: PTCPBlockSocket;
    CurrentMessage: TMQTTMessage;
    // Events
    FConnAckEvent: TConnAckEvent;
    FPublishEvent: TPublishEvent;
    FPingRespEvent: TPingRespEvent;
    FSubAckEvent: TSubAckEvent;
    FUnSubAckEvent: TUnSubAckEvent;
    // This takes a 1-4 Byte Remaining Length bytes as per the spec and returns the Length value it represents
    // Increases the size of the Dest array and Appends NewBytes to the end of DestArray 
    // Takes a 2 Byte Length array and returns the length of the ansistring it preceeds as per the spec.
    function BytesToStrLength(LengthBytes: TBytes): integer;
    // This is our data processing and event firing command. To be called via Synchronize.
    procedure HandleData;

// NEW...
    function FixedHeader(MessageType: TMQTTMessageType; Dup: Word; Qos: Word; Retain: Word): Byte;

    // Variable Header per command creation funcs
    function VariableHeaderConnect(KeepAlive: Word): TBytes;


    procedure AppendArray(var Dest: TUTF8Text; Source: Array of Byte);

    function StrToBytes(str: ansistring; perpendLength: boolean): TUTF8Text;

    function BuildCommand(FixedHead: Byte; RemainL: TRemainingLength; VariableHead: TBytes; Payload: Array of Byte): TBytes;


    procedure CopyIntoArray(var DestArray: Array of Byte; SourceArray: Array of Byte; StartIndex: integer);

    // Calculates the Remaining Length bytes of the FixedHeader as per the spec.
    function RemainingLength(MessageLength: Integer): TRemainingLength;

    function SocketWrite(Data: TBytes): boolean;

//..END NEW

  protected
    procedure Execute; override;
  public
    constructor Create(Socket: PTCPBlockSocket);
    property OnConnAck : TConnAckEvent read FConnAckEvent write FConnAckEvent;
    property OnPublish : TPublishEvent read FPublishEvent write FPublishEvent;
    property OnPingResp : TPingRespEvent read FPingRespEvent write FPingRespEvent;
    property OnSubAck : TSubAckEvent read FSubAckEvent write FSubAckEvent;
    property OnUnSubAck : TUnSubAckEvent read FUnSubAckEvent write FUnSubAckEvent;
  end;

implementation

uses
  MQTT;

{ TMQTTReadThread }

constructor TMQTTReadThread.Create(Socket: PTCPBlockSocket);
begin
  inherited Create(true);
  // Create a Default ClientID as a default. Can be overridden with TMQTTClient.ClientID any time before connection.
  FClientID := 'dMQTTClientx' + IntToStr(Random(1000) + 1);

  FPSocket := Socket;
  FreeOnTerminate := true;
end;

procedure TMQTTReadThread.Execute;
var
  rxState: TRxStates;
  remainingLengthx: integer;
  digit: integer;
  multiplier: integer;
  Data: TBytes;
  RL: TRemainingLength;
  VH: TBytes;
  FH: Byte;
  Payload: TUTF8Text;
begin
  rxState := RX_START;
  
  while not Terminated do
    begin
        case rxState of
// NEW...
        RX_START: begin
            //FPSocket^.Connect(Self.FHostname, IntToStr(Self.FPort);
            //FPSocket^.Connect('192.168.0.67', '1883');
            FPSocket^.Connect('localhost', '1883');

            //FPSocket^.Connect('test.mosquitto.org', '1883');
            writeln('Error 1: ', FPSocket^.LastError);
        
            //  Build CONNECT message
            FH := FixedHeader(MQTTReadThread.CONNECT, 0, 0, 0);
            VH := VariableHeaderConnect(40);
            SetLength(Payload, 0);
            AppendArray(Payload, StrToBytes(FClientID, true));
            AppendArray(Payload, StrToBytes('lwt', true));
            AppendArray(Payload, StrToBytes(FClientID + ' died', true));
            RL := RemainingLength(Length(VH) + Length(Payload));
            Data := BuildCommand(FH, RL, VH, Payload);

            // Send CONNECT message
            if SocketWrite(Data) then
              begin
                writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! YEAY !!!!!!!!!!!!!!!!!!!!!!!!');
                rxState := RX_FIXED_HEADER;
              end
            else
              begin
                writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! BOOO !!!!!!!!!!!!!!!!!!!!!!!!');
                rxState := RX_ERROR;
              end; 
            writeln('Error 2: ', FPSocket^.LastError);
            end;
// END NEW...
        RX_FIXED_HEADER: begin
                multiplier := 1;
                remainingLengthx := 0;
                CurrentMessage.Data := nil;
                CurrentMessage.FixedHeader := FPSocket^.RecvByte(1000);
                writeln('Error 3: ', FPSocket^.LastError);
                if (FPSocket^.LastError = ESysETIMEDOUT) then continue;
                if (FPSocket^.LastError <> 0) then
                  rxState := RX_ERROR
                else
                  rxState := RX_LENGTH;
            end;
        RX_LENGTH: begin
                digit := FPSocket^.RecvByte(1000);
                if (FPSocket^.LastError = ESysETIMEDOUT) then continue;
                if (FPSocket^.LastError <> 0) then
                  rxState := RX_ERROR
                else
                begin
                  remainingLengthx := remainingLengthx + (digit and 127) * multiplier;
                  if (digit and 128) > 0 then
                  begin
                    multiplier := multiplier * 128;
                    rxState := RX_LENGTH;
                  end
                  else
                    rxState := RX_DATA;
                end;
            end;
        RX_DATA: begin
                SetLength(CurrentMessage.Data, remainingLengthx);
                FPSocket^.RecvBufferEx(Pointer(CurrentMessage.Data), remainingLengthx, 1000);
                if (FPSocket^.LastError <> 0) then
                  rxState := RX_ERROR
                else
                begin
                  Synchronize(@HandleData);
                  rxState := RX_FIXED_HEADER;
                end;
            end;
        RX_ERROR: begin
                writeln('------------ RX ERROR ----------');
                // We hang up here. 
                sleep(1000);
            end;
        end;
    end;
    writeln ('*******************************************************************');
    writeln ('*******************************************************************');
    writeln ('*********************** TERMINATED ********************************');
    writeln ('*******************************************************************');
    writeln ('*******************************************************************');
end;

procedure TMQTTReadThread.HandleData;
var
  MessageType: Byte;
  DataLen: integer;
  QoS: integer;
  Topic: ansistring;
  Payload: ansistring;
  ResponseVH: TBytes;
  ConnectReturn: Integer;
begin
  if (CurrentMessage.FixedHeader <> 0) then
    begin
      MessageType := CurrentMessage.FixedHeader shr 4;

      if (MessageType = Ord(MQTT.CONNACK)) then
        begin
          // Check if we were given a Connect Return Code.
          ConnectReturn := 0;
          // Any return code except 0 is an Error
          if ((Length(CurrentMessage.Data) > 0) and (Length(CurrentMessage.Data) < 4)) then
            begin
              ConnectReturn := CurrentMessage.Data[1];
              Exception.Create('Connect Error Returned by the Broker. Error Code: ' + IntToStr(CurrentMessage.Data[1]));
            end;
          if Assigned(OnConnAck) then OnConnAck(Self, ConnectReturn);
        end
      else
      if (MessageType = Ord(MQTT.PUBLISH)) then
        begin
          // Read the Length Bytes
          DataLen := BytesToStrLength(Copy(CurrentMessage.Data, 0, 2));
          // Get the Topic
          SetString(Topic, PChar(@CurrentMessage.Data[2]), DataLen);
          // Get the Payload
          SetString(Payload, PChar(@CurrentMessage.Data[2 + DataLen]), (Length(CurrentMessage.Data) - 2 - DataLen));
          if Assigned(OnPublish) then OnPublish(Self, Topic, Payload);
        end
      else
      if (MessageType = Ord(MQTT.SUBACK)) then
        begin
          // Reading the Message ID
          ResponseVH := Copy(CurrentMessage.Data, 0, 2);
          DataLen := BytesToStrLength(ResponseVH);
          // Next Read the Granted QoS
          QoS := 0;
          if (Length(CurrentMessage.Data) - 2) > 0 then
            begin
              ResponseVH := Copy(CurrentMessage.Data, 2, 1);
              QoS := ResponseVH[0];
            end;
          if Assigned(OnSubAck) then OnSubAck(Self, DataLen, QoS);
        end
      else
      if (MessageType = Ord(MQTT.UNSUBACK)) then
        begin
          // Read the Message ID for the event handler
          ResponseVH := Copy(CurrentMessage.Data, 0, 2);
          DataLen := BytesToStrLength(ResponseVH);
          if Assigned(OnUnSubAck) then OnUnSubAck(Self, DataLen);
        end
      else
      if (MessageType = Ord(MQTT.PINGRESP)) then
        begin
          if Assigned(OnPingResp) then OnPingResp(Self);
        end;
    end;
end;

function TMQTTReadThread.BytesToStrLength(LengthBytes: TBytes): integer;
begin
  Assert(Length(LengthBytes) = 2, 'UTF-8 Length Bytes preceeding the text must be 2 Bytes in Legnth');

  Result := 0;
  Result := LengthBytes[0] shl 8;
  Result := Result + LengthBytes[1];
end;


// NEW...

function TMQTTReadThread.FixedHeader(MessageType: TMQTTMessageType; Dup, Qos, Retain: Word): Byte;
begin
  { Fixed Header Spec:
    bit    |7 6 5   4       | |3         | |2   1        |  |  0   |
    byte 1 |Message Type| |DUP flag| |QoS level|    |RETAIN| }
  Result := (Ord(MessageType) * 16) + (Dup * 8) + (Qos * 2) + (Retain * 1);
end;


function TMQTTReadThread.VariableHeaderConnect(KeepAlive: Word): TBytes;
const
  MQTT_PROTOCOL = 'MQIsdp';
  MQTT_VERSION = 3;
var
  Qos, Retain: word;
  iByteIndex: integer;
  ProtoBytes: TUTF8Text;
begin
  // Set the Length of our variable header array.
  SetLength(Result, 12);
  iByteIndex := 0;
  // Put out Protocol string in there.
  ProtoBytes := StrToBytes(MQTT_PROTOCOL, true);
  CopyIntoArray(Result, ProtoBytes, iByteIndex);
  Inc(iByteIndex, Length(ProtoBytes));
  // Version Number = 3
  Result[iByteIndex] := MQTT_VERSION;
  Inc(iByteIndex);
  // Connect Flags
  Qos := 0;
  Retain := 0;
  Result[iByteIndex] := 0;
  Result[iByteIndex] := (Retain * 32) + (Qos * 16) + (1 * 4) + (1 * 2);
  Inc(iByteIndex);
  Result[iByteIndex] := 0;
  Inc(iByteIndex);
  Result[iByteIndex] := KeepAlive;
end;

procedure TMQTTReadThread.AppendArray(var Dest: TUTF8Text; Source: Array of Byte);
var
  DestLen: Integer;
begin
  DestLen := Length(Dest);
  SetLength(Dest, DestLen + Length(Source));
  Move(Source, Dest[DestLen], Length(Source));
end;


function TMQTTReadThread.StrToBytes(str: ansistring; perpendLength: boolean): TUTF8Text;
var
  i, offset: integer;
begin
  { This is a UTF-8 hack to give 2 Bytes of Length followed by the string itself. }
  if perpendLength then
    begin
      SetLength(Result, Length(str) + 2);
      Result[0] := Length(str) div 256;
      Result[1] := Length(str) mod 256;
      offset := 1;
    end
  else
    begin
      SetLength(Result, Length(str));
      offset := -1;
    end;
  for I := 1 to Length(str) do
    Result[i + offset] := ord(str[i]);
end;

function TMQTTReadThread.BuildCommand(FixedHead: Byte; RemainL: TRemainingLength;
  VariableHead: TBytes; Payload: Array of Byte): TBytes;
var
  iNextIndex: integer;
begin
  // Attach Fixed Header (1 byte)
  iNextIndex := 0;
  SetLength(Result, 1);
  Result[iNextIndex] := FixedHead;

  // Attach RemainingLength (1-4 bytes)
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(RemainL));
  CopyIntoArray(Result, RemainL, iNextIndex);

  // Attach Variable Head
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(VariableHead));
  CopyIntoArray(Result, VariableHead, iNextIndex);

  // Attach Payload.
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(Payload));
  CopyIntoArray(Result, Payload, iNextIndex);
end;

procedure TMQTTReadThread.CopyIntoArray(var DestArray: Array of Byte; SourceArray: Array of Byte; StartIndex: integer);
begin
  Assert(StartIndex >= 0);

  Move(SourceArray[0], DestArray[StartIndex], Length(SourceArray));
end;


function TMQTTReadThread.RemainingLength(MessageLength: Integer): TRemainingLength;
var
  byteindex: integer;
  digit: integer;
begin
  SetLength(Result, 1);
  byteindex := 0;
  while (MessageLength > 0) do
   begin
      digit := MessageLength mod 128;
      MessageLength := MessageLength div 128;
      if MessageLength > 0 then
        begin
          digit := digit or $80;
        end;
      Result[byteindex] := digit;
      if MessageLength > 0 then
        begin
          inc(byteindex);
          SetLength(Result, Length(Result) + 1);
        end;
   end;
end;

function TMQTTReadThread.SocketWrite(Data: TBytes): boolean;
var
  sentData: integer;
begin
  Result := False;
  // Returns whether the Data was successfully written to the socket.
//  if isConnected then
//  begin
    sentData := FPSocket^.SendBuffer(Pointer(Data), Length(Data));
    if sentData = Length(Data) then Result := True else Result := False;
//  end;
end;

//...END NEW










end.
