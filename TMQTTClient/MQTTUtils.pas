{$mode objfpc} 

unit MQTTUtils;

Interface

type TBytes = array of Byte;
type TUTF8Text = Array of Byte;
type TRemainingLength = Array of Byte;

//  Message type. 4 Bit unsigned.
type
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

// UTILS

// Message Component Build helpers
function FixedHeader(MessageType: TMQTTMessageType; Dup: Word; Qos: Word; Retain: Word): Byte;

// Variable Header per command creation funcs
function VariableHeaderConnect(KeepAlive: Word): TBytes;


procedure AppendArray(var Dest: TUTF8Text; Source: Array of Byte);

function StrToBytes(str: ansistring; perpendLength: boolean): TUTF8Text;

function BuildCommand(FixedHead: Byte; RemainL: TRemainingLength; VariableHead: TBytes; Payload: Array of Byte): TBytes;


procedure CopyIntoArray(var DestArray: Array of Byte; SourceArray: Array of Byte; StartIndex: integer);

// Calculates the Remaining Length bytes of the FixedHeader as per the spec.
function RemainingLength(MessageLength: Integer): TRemainingLength;

{
function SocketWrite(Data: TBytes): boolean;
}

Implementation


function FixedHeader(MessageType: TMQTTMessageType; Dup, Qos, Retain: Word): Byte;
begin
  { Fixed Header Spec:
    bit    |7 6 5   4       | |3         | |2   1        |  |  0   |
    byte 1 |Message Type| |DUP flag| |QoS level|    |RETAIN| }
  Result := (Ord(MessageType) * 16) + (Dup * 8) + (Qos * 2) + (Retain * 1);
end;


function VariableHeaderConnect(KeepAlive: Word): TBytes;
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

procedure AppendArray(var Dest: TUTF8Text; Source: Array of Byte);
var
  DestLen: Integer;
begin
  DestLen := Length(Dest);
  SetLength(Dest, DestLen + Length(Source));
  Move(Source, Dest[DestLen], Length(Source));
end;


function StrToBytes(str: ansistring; perpendLength: boolean): TUTF8Text;
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

function BuildCommand(FixedHead: Byte; RemainL: TRemainingLength;
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

procedure CopyIntoArray(var DestArray: Array of Byte; SourceArray: Array of Byte; StartIndex: integer);
begin
  Assert(StartIndex >= 0);

  Move(SourceArray[0], DestArray[StartIndex], Length(SourceArray));
end;

function RemainingLength(MessageLength: Integer): TRemainingLength;
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

{
function SocketWrite(Data: TBytes): boolean;
var
  sentData: integer;
begin
  Result := False;
  // Returns whether the Data was successfully written to the socket.
  if isConnected then
  begin
    sentData := FSocket.SendBuffer(Pointer(Data), Length(Data));
    if sentData = Length(Data) then Result := True else Result := False;
  end;
end;
}

end.


