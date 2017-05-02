unit ZMQ.WorkerProtocol;
{ Base class for ZeroMQ workers }

{$I Grijjy.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  System.DateUtils,
  {$IFDEF LINUX}
  Posix.Base,
  Posix.Fcntl,
  {$ENDIF}
  PascalZMQ,
  ZMQ.Protocol,
  ZMQ.Shared;

type
  { Load average calculation thread }
  TLoadAvg = class(TThread)
  protected
    { Internal }
    FLoadAvg: String;
    function _LoadAvg: String;
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    { Returns the latest load average information on Linux or Windows }
    property LoadAvg: String read FLoadAvg;
  end;

  { This event is called whenever a new message is received }
  TOnRecv = procedure(const AMsg: PZMessage; var ARoutingFrame: PZFrame) of object;

  { Worker interface }
  TZMQWorkerProtocol = class(TZMQProtocol)
  private
    { Internal }
    FOnRecv: TOnRecv;
    FLoadAvg: TLoadAvg;

    { Name of the service }
    FService: String;
  protected
    { Send heartbeat }
    procedure SendHeartbeat;

    { Send ready }
    procedure SendReady;

    { This method is called whenever a new message is received by the worker }
    procedure DoRecv(const ACommand: TZMQCommand;
      var AMsg: PZMessage; var ASentFrom: PZFrame); override;

    { This method is called when a connection is established }
    procedure DoConnected; override;

    { This method is called when a heartbeat needs to be sent }
    procedure DoHeartbeat; override;
  public
    constructor Create(const AHeartbeats: Boolean = False;
          const AExpectReplyRoutingFrames: Boolean = False;
          const AUseThreadPool: Boolean = False;
          const APollThreads: Integer = 0);
    destructor Destroy; override;

    { Connect to broker }
    function Connect(const ABrokerAddress: String;
      const ABrokerPublicKey: String = '';
      const ASocketType: TZSocketType = TZSocketType.Dealer;
      const AService: String = ''): Boolean; reintroduce;

    { Send message to Broker }
    procedure Send(var AMsg: PZMessage; var ARoutingFrame: PZFrame); reintroduce;

    { This event is called whenever a new message is received }
    property OnRecv: TOnRecv read FOnRecv write FOnRecv;
  end;

{$IFDEF LINUX}
{ popen, pclose - pipe stream to or from a process }
function popen(const command: MarshaledAString; const _type: MarshaledAString): Pointer; cdecl; external libc name _PU + 'popen';
function pclose(_file: Pointer): Int32; cdecl; external libc name _PU + 'pclose';

{ fgets() reads in at most one less than size characters from stream and stores them into the buffer pointed to by s }
function fgets(s: Pointer; n: Int32; Stream: Pointer): Pointer; cdecl; external libc name _PU + 'fgets';
{$ENDIF}

implementation

{ TLoadAvg }

constructor TLoadAvg.Create;
begin
  inherited Create;
  FLoadAvg := '';
end;

destructor TLoadAvg.Destroy;
begin
  inherited;
end;

{$IF Defined(LINUX)}
function TLoadAvg._LoadAvg: String;
var
  Handle: Pointer;
  S: RawByteString;
begin
  SetLength(S, 1024);
  Handle := popen('/bin/cat /proc/loadavg','r');
  try
    while fgets(@S[1], Length(S), Handle) <> nil do
      Result := Result + String(S);
  finally
    pclose(Handle);
  end;
end;
{$ELSEIF Defined(MSWINDOWS)}
function TLoadAvg._LoadAvg: String;
var
  SystemTimes: TSystemTimes;
  Usage: Single;
begin
  Usage := TThread.GetCPUUsage(SystemTimes) * 0.01;
  Result := Format('%.2f', [Usage]);
end;
{$ELSE}
function TLoadAvg._LoadAvg: String;
begin
  Assert(False, 'Implement for this OS');
end;
{$ENDIF}

procedure TLoadAvg.Execute;
var
  Start: TDateTime;
begin
  while not Terminated do
  begin
    FLoadAvg := _LoadAvg;
    Start := Now;
    while (not Terminated) and
      (SecondsBetween(Now, Start) < 10) do
      Sleep(10);
  end;
end;

{ TZMQWorkerProtocol }

constructor TZMQWorkerProtocol.Create(const AHeartbeats: Boolean;
      const AExpectReplyRoutingFrames: Boolean;
      const AUseThreadPool: Boolean;
      const APollThreads: Integer);
begin
  inherited;

  { initialize }
  FLoadAvg := TLoadAvg.Create;
end;

destructor TZMQWorkerProtocol.Destroy;
begin
  FLoadAvg.Free;
  inherited;
end;

{ Connect to broker }
function TZMQWorkerProtocol.Connect(const ABrokerAddress: String;
  const ABrokerPublicKey: String; const ASocketType: TZSocketType;
  const AService: String): Boolean;
begin
  FService := AService;
  Result := inherited Connect(ABrokerAddress, ABrokerPublicKey, ASocketType);
end;

{ Send message to Broker }
procedure TZMQWorkerProtocol.Send(var AMsg: PZMessage; var ARoutingFrame: PZFrame);
begin
  AMsg.Push(ARoutingFrame);
  AMsg.PushString(FService);
  AMsg.PushEnum<TZMQCommand>(TZMQCommand.WorkerMessage);
  inherited Send(AMsg);
end;

{ Send heartbeat }
procedure TZMQWorkerProtocol.SendHeartbeat;
var
  Msg: PZMessage;
begin
  Msg := TZMessage.Create;
  Msg.PushString(FLoadAvg.LoadAvg);
  Msg.PushString(FService);
  Msg.PushEnum<TZMQCommand>(TZMQCommand.Heartbeat);
  inherited Send(Msg);
end;

{ Send ready }
procedure TZMQWorkerProtocol.SendReady;
var
  Msg: PZMessage;
begin
  Msg := TZMessage.Create;
  Msg.PushString(FService);
  Msg.PushEnum<TZMQCommand>(TZMQCommand.Ready);
  inherited Send(Msg);
end;

{ This method is called whenever a new message is received by the worker }
procedure TZMQWorkerProtocol.DoRecv(const ACommand: TZMQCommand;
  var AMsg: PZMessage; var ASentFrom: PZFrame);
begin
  inherited;
  if Assigned(FOnRecv) then
    FOnRecv(AMsg, ASentFrom);
end;

{ This method is called when a connection is established }
procedure TZMQWorkerProtocol.DoConnected;
begin
  SendReady;
end;

{ This method is called when a heartbeat needs to be sent }
procedure TZMQWorkerProtocol.DoHeartbeat;
begin
  SendHeartbeat;
end;

end.
