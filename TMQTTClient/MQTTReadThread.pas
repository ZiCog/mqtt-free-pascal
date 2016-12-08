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
  TMQTTMessage = record
    FixedHeader: Byte;
    RL: TBytes;
    Data: TBytes;
  end;

type TRxStates = (RX_START, RX_FIXED_HEADER, RX_LENGTH, RX_DATA, RX_ERROR);

  PTCPBlockSocket = ^TTCPBlockSocket;

  TRemainingLength = Array of Byte;

  TUTF8Text = Array of Byte;

  TConnAckEvent = procedure (Sender: TObject; ReturnCode: integer) of object;
  TPublishEvent = procedure (Sender: TObject; topic, payload: ansistring) of object;
  TPingRespEvent = procedure (Sender: TObject) of object;
  TSubAckEvent = procedure (Sender: TObject; MessageID: integer; GrantedQoS: integer) of object;
  TUnSubAckEvent = procedure (Sender: TObject; MessageID: integer) of object;

  TMQTTReadThread = class(TThread)
    private 
      FClientID: ansistring;
      FHostname: ansistring;
      FPort: integer;
      FPSocket: PTCPBlockSocket;
      CurrentMessage: TMQTTMessage;
      // Events
      FConnAckEvent: TConnAckEvent;
      FPublishEvent: TPublishEvent;
      FPingRespEvent: TPingRespEvent;
      FSubAckEvent: TSubAckEvent;
      FUnSubAckEvent: TUnSubAckEvent;




// Takes a 2 Byte Length array and returns the length of the ansistring it preceeds as per the spec.
      function BytesToStrLength(LengthBytes: TBytes): integer;

      // This is our data processing and event firing command.
      procedure HandleData;

      function SocketWrite(Data: TBytes): boolean;

    protected 
      procedure Execute;
      override;
    public 
      constructor Create(Socket: PTCPBlockSocket; Hostname: ansistring; Port: integer);
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

    constructor TMQTTReadThread.Create(Socket: PTCPBlockSocket; HostName: ansistring; Port: integer)
    ;
    begin
      inherited Create(true);




// Create a Default ClientID as a default. Can be overridden with TMQTTClient.ClientID any time before connection.
      FClientID := 'dMQTTClientx' + IntToStr(Random(1000) + 1);
      FPSocket := Socket;
      FHostname := Hostname;
      FPort := Port;
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
      error: integer;
    begin
      rxState := RX_START;

      while not self.Terminated do
        begin
          case rxState of 
            RX_START:
                      begin
                        // Make the socket connection
                        FPSocket^.Connect(FHostname, IntToStr(FPort));

                        //  Build CONNECT message
                        FH := FixedHeader(MQTT.CONNECT, 0, 0, 0);
                        VH := VariableHeaderConnect(40);
                        SetLength(Payload, 0);
                        AppendArray(Payload, StrToBytes(FClientID, true));
                        AppendArray(Payload, StrToBytes('lwt', true));
                        AppendArray(Payload, StrToBytes(FClientID + ' died', true));
                        RL := RemainingLength(Length(VH) + Length(Payload));
                        Data := BuildCommand(FH, RL, VH, Payload);

                        writeln('RX_START: ', FPSocket^.LastErrorDesc);
                        writeln('RX_START: ', FPSocket^.LastError);

                        //sleep(1);

                        // Send CONNECT message
                        while true do
                        begin
                          writeln('loop...');
                          SocketWrite(Data);
                          error := FPSocket^.LastError;
                          writeln('RX_START: ', FPSocket^.LastErrorDesc);
                          writeln('RX_START: ', error);
                          if error = 0 then
                            begin
                              rxState := RX_FIXED_HEADER;
                              break;
                            end
                          else
                            begin
                              if error = 110 then
                              begin
                                continue;
                              end;
                              rxState := RX_ERROR;
                              break;
                            end;
                        end;
                      end;
            RX_FIXED_HEADER:
                             begin
                               multiplier := 1;
                               remainingLengthx := 0;
                               CurrentMessage.Data := nil;

                               CurrentMessage.FixedHeader := FPSocket^.RecvByte(1000);
                               if (FPSocket^.LastError = ESysETIMEDOUT) then continue;
                               if (FPSocket^.LastError <> 0) then
                                 rxState := RX_ERROR
                               else
                                 rxState := RX_LENGTH;
                             end;
            RX_LENGTH:
                       begin
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
            RX_DATA:
                     begin
                       SetLength(CurrentMessage.Data, remainingLengthx);
                       FPSocket^.RecvBufferEx(Pointer(CurrentMessage.Data), remainingLengthx, 1000);
                       if (FPSocket^.LastError <> 0) then
                         rxState := RX_ERROR
                       else
                         begin
                           HandleData;
                           rxState := RX_FIXED_HEADER;
                         end;
                     end;
            RX_ERROR:
                      begin
                        // Quit the loop, terminating the thread. 
                        break;
                      end;
          end;
        end;
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
              // Any return code except 0 is an Error
              if ((Length(CurrentMessage.Data) > 0) and (Length(CurrentMessage.Data) < 4)) then
                begin
                  ConnectReturn := CurrentMessage.Data[1];
                  if Assigned(OnConnAck) then OnConnAck(Self, ConnectReturn);
                end;
            end
          else
            if (MessageType = Ord(MQTT.PUBLISH)) then
              begin
                // Read the Length Bytes
                DataLen := BytesToStrLength(Copy(CurrentMessage.Data, 0, 2));
                // Get the Topic
                SetString(Topic, PChar(@CurrentMessage.Data[2]), DataLen);
                // Get the Payload
                SetString(Payload, PChar(@CurrentMessage.Data[2 + DataLen]),
                (Length(CurrentMessage.Data) - 2 - DataLen));
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
      Assert(Length(LengthBytes) = 2,



                 'TMQTTReadThread: UTF-8 Length Bytes preceeding the text must be 2 Bytes in Legnth'
                                   );

      Result := 0;
      Result := LengthBytes[0] shl 8;
      Result := Result + LengthBytes[1];
    end;

    function TMQTTReadThread.SocketWrite(Data: TBytes): boolean;

    var 
      sentData: integer;
    begin
      Result := False;
      // Returns whether the Data was successfully written to the socket.

      while not FPSocket^.CanWrite(0) do
      begin
        sleep(100);
      end;

      sentData := FPSocket^.SendBuffer(Pointer(Data), Length(Data));
      if sentData = Length(Data) then
        Result := True
    end;
  end.
