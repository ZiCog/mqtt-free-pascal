{$mode objfpc} 

unit MQTTUtils;

Interface

	
// UTILS



function SocketWrite(Data: TBytes): boolean;


Implementation



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

end.


