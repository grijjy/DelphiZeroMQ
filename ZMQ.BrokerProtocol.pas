unit ZMQ.BrokerProtocol;
{ Base class for ZeroMQ brokers }

{$I Grijjy.inc}

interface

uses
  Grijjy.Collections,
  System.Generics.Collections,
  System.Types,
  System.SysUtils,
  System.StrUtils,
  System.DateUtils,
  PascalZMQ,
  ZMQ.Protocol,
  ZMQ.Shared;

const
  { The millisecond interval for removing expired workers }
  CLEANUP_INTERVAL = 5000;

type
  TZMQBrokerProtocol = class;
  TServices = class;
  TService = class;
  TWorkers = class;

  { Worker instance  }
  TWorker = class(TObject)
  protected
    FParent: TWorkers;

    { Hash id string for worker }
    FWorkerId: String;

    { Routing frame for sending messages to worker }
    FRoutingFrame: PZFrame;

    { Name of the service associated with this worker }
    FService: String;

    { Last time a heartbeat was sent to this worker }
    FLastHeartbeatSent: TDateTime;

    { Last time data was received from this worker }
    FLastHeartbeatRecv: TDateTime;

    { Current system load of the worker }
    FLoadAvg: Single;
  private
    { Sends a message to the worker }
    procedure Send(const ACommand: TZMQCommand; var AMsg: PZMessage);

    { Sends a heartbeat to the worker }
    procedure SendHeartbeat;

    { Receives a heartbeat and the current load average of the worker
      Load average represents the Unix /proc/loadavg result from the
      shell which averages the current system load over a period of time.
      We simulate this result on Windows since the primary platform for the
      Worker will be Unix. }
    procedure Heartbeat(const ALoadAvg: String);

    { Notifies the worker that the Broker is tracking the worker }
    procedure SendReady;

    { Hash id string for worker }
    property WorkerId: String read FWorkerId;

    { Name of the service associated with this worker }
    property Service: String read FService write FService;

    { Last time a heartbeat was sent to this worker }
    property LastHeartbeatSent: TDateTime read FLastHeartbeatSent write FLastHeartbeatSent;

    { Last time data was received from this worker }
    property LastHeartbeatRecv: TDateTime read FLastHeartbeatRecv write FLastHeartbeatRecv;

    { Current system load of the worker }
    property LoadAvg: Single read FLoadAvg;
  public
    constructor Create(const AParent: TWorkers; const AWorkerId: String;
      const ARoutingFrame: PZFrame);
    destructor Destroy; override;
  end;

  { Workers class }
  TWorkers = class(TObject)
  protected
    { Internal }
    FBroker: TZMQBrokerProtocol;

    { List of all active workers }
    FWorkers: TObjectDictionary<String, TWorker>;
  private
    { Adds a new worker to the active worker list along with the worker routing frame
      and associates a service with the worker }
    function Add(const AWorkerId: String; const ARoutingFrame: PZFrame;
      const AService: String): TWorker;

    { Deletes a worker from the active worker list }
    procedure Delete(const AWorkerId: String);

    { Sends a message to a worker }
    procedure Send(const AWorkerId: String; const ACommand: TZMQCommand;
      var AMsg: PZMessage);

    { Checks for heartbeat intervals and sends the heartbeat messages }
    procedure SendHeartbeats;

    { Updates the load average statistics }
    procedure Heartbeat(const AWorkerId: String; const ALoadAvg: String = '');

    { Called when a worker gracefully disconnects }
    procedure Disconnect(const AWorkerId: String);

    { Returns the load average of the worker }
    function LoadAvg(const AWorkerId: String): Single;

    { Notifies the worker that the Broker is tracking the worker }
    procedure SendReady(const AWorkerId: String);

    { Protocol }
    property Broker: TZMQBrokerProtocol read FBroker;
  public
    constructor Create(const ABroker: TZMQBrokerProtocol);
    destructor Destroy; override;
  end;

  { Service instance }
  TService = class(TObject)
  protected
    FParent: TServices;

    { Name of the service }
    FName: String;

    { List of workers for this service }
    FWorkerIds: TgoSet<String>;
  private
    { Adds a worker to the service }
    procedure AddWorker(const AWorkerId: String);

    { Removes a worker from the service }
    procedure DeleteWorker(const AWorkerId: String);

    { Finds the least used worker by load balancing }
    function FindWorker: String;

    { Sends a message to the service.  The service determines the appropriate worker
      to service the message }
    function Send(const ACommand: TZMQCommand; var AMsg: PZMessage;
      const ASendToId: String = ''): Boolean;
  public
    constructor Create(const AParent: TServices; const AName: String);
    destructor Destroy; override;
  end;

  { Services class }
  TServices = class(TObject)
  protected
    { Internal }
    FBroker: TZMQBrokerProtocol;

    { List of active services }
    FServices: TObjectDictionary<String, TService>;
  private
    { Adds a new service }
    function Add(const AName: String): TService;

    { Adds a new worker to the service }
    function AddWorker(const AName: String; const AWorkerId: String): Boolean;

    { Removes a worker from the service }
    function DeleteWorker(const AName: String; const AWorkerId: String): Boolean;

    { Finds a worker in the service }
    function FindWorker(const AName: String; out AWorkerId: String): Boolean;

    { Sends a message to the service.  The service determines the appropriate worker
      to service the message }
    procedure Send(const AService: String; const ACommand: TZMQCommand;
      var AMsg: PZMessage; const ASendToId: String = '');

    { Forwards message from a client to a worker without modification }
    procedure ForwardClientMessageToWorker(const AService: String;
      const ASentFrom: PZFrame; var AMsg: PZMessage; const ASendToId: String = '');

    property Broker: TZMQBrokerProtocol read FBroker;
  public
    constructor Create(const ABroker: TZMQBrokerProtocol);
    destructor Destroy; override;
  end;

  { Broker interface }
  TZMQBrokerProtocol = class(TZMQProtocol)
  private
    { Services class }
    FServices: TServices;

    { Workers class }
    FWorkers: TWorkers;

    { Internal }
    FLastCleanup: TDateTime;
  protected
    procedure DoIdle; override;

    { This method is called whenever a new message is received by the broker. }
    procedure DoRecv(const ACommand: TZMQCommand; var AMsg: PZMessage;
      var ASentFrom: PZFrame); override;

    { This event is fired whenever a new message is received from a client }
    procedure DoRecvFromClient(const AService: String; const ASentFromId: String;
      const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction; var ASendToId: String); virtual;

    { This event is fired whenever a new message is received from a worker }
    procedure DoRecvFromWorker(const AService: String; const ASentFromId: String;
      const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction); virtual;

    { This event is fired whenever a worker is deleted from a service }
    procedure DoDeleteWorker(const AService: String; const AWorkerId: String); virtual;
  public
    constructor Create;
    destructor Destroy; override;

    { Forward worker message to client }
    procedure ForwardWorkerMessageToClient(const AService: String;
      var AMsg: PZMessage);

    { Removes dead workers and cleans up related services }
    procedure Cleanup;

    { Allocates a worker and returns the worker id }
    function FindWorker(const AService: String; out AWorkerId: String): Boolean;
  end;

implementation

{ TWorker }

constructor TWorker.Create(const AParent: TWorkers; const AWorkerId: String;
  const ARoutingFrame: PZFrame);
begin
  inherited Create;

  FParent := AParent;
  FWorkerId := AWorkerId;
  FLastHeartbeatSent := Now;
  FLastHeartbeatRecv := Now;
  FLoadAvg := 0;

  { we make a copy of the routing frame for the worker because it is
    destroyed automatically }
  FRoutingFrame := ARoutingFrame.Clone;
end;

destructor TWorker.Destroy;
begin
  FRoutingFrame.Free;
  inherited;
end;

{ Sends a message to the worker }
procedure TWorker.Send(const ACommand: TZMQCommand;
 var AMsg: PZMessage);
var
  RoutingFrame: PZFrame;
begin
  AMsg.PushEnum<TZMQCommand>(ACommand);
  { since we are sending the message to the worker, we must make a copy of the
    workers routing frame because it will be destroyed along with the message
    when the message is sent and we will need to use it again for subsequent
    sends to the worker. }
  RoutingFrame := FRoutingFrame.Clone;
  FParent.Broker.Send(AMsg, RoutingFrame);
end;

{ Sends a heartbeat to the worker }
procedure TWorker.SendHeartbeat;
var
  Msg: PZMessage;
begin
  Msg := TZMessage.Create;
  Send(TZMQCommand.Heartbeat, Msg);
  FLastHeartbeatSent := Now;
end;

{ Receives a heartbeat and the current load average of the worker
  Load average represents the Unix /proc/loadavg result from the
  shell which averages the current system load over a period of time.
  We simulate this result on Windows since the primary platform for the
  Worker will be Unix. }
procedure TWorker.Heartbeat(const ALoadAvg: String);
var
  StrArray: TStringDynArray;
begin
  FLastHeartbeatRecv := Now;

  if ALoadAvg <> '' then
  begin
    { Load average over the recent past }
    StrArray := SplitString(ALoadAvg, #32);
    if Length(StrArray) > 0 then
      FLoadAvg := StrToFloatDef(StrArray[0], -1);
  end;
end;

{ Notifies the worker that the Broker is tracking the worker }
procedure TWorker.SendReady;
var
  Msg: PZMessage;
begin
  Msg := TZMessage.Create;
  Msg.PushString(FWorkerId);
  Send(TZMQCommand.Ready, Msg);
end;

{ TWorkers }

constructor TWorkers.Create(const ABroker: TZMQBrokerProtocol);
begin
  inherited Create;
  FBroker := ABroker;
  FWorkers := TObjectDictionary<String, TWorker>.Create([doOwnsValues]);
end;

destructor TWorkers.Destroy;
begin
  FWorkers.Free;
  inherited;
end;

{ Adds a new worker to the active worker list along with the worker routing frame
  and associates a service with the worker }
function TWorkers.Add(const AWorkerId: String; const ARoutingFrame: PZFrame;
  const AService: String): TWorker;
begin
  { add worker if not already existing }
  if not FWorkers.TryGetValue(AWorkerId, Result) then
  begin
    Result := TWorker.Create(Self, AWorkerId, ARoutingFrame);
    FWorkers.Add(AWorkerId, Result);
    Writeln(Format('Added worker %s', [AWorkerId]));
  end;

  { keep track of service name }
  Result.Service := AService;
end;

{ Deletes a worker from the active worker list }
procedure TWorkers.Delete(const AWorkerId: String);
begin
  FWorkers.Remove(AWorkerId);
end;

{ Sends a message to a worker }
procedure TWorkers.Send(const AWorkerId: String; const ACommand: TZMQCommand;
  var AMsg: PZMessage);
var
  Worker: TWorker;
begin
  if FWorkers.TryGetValue(AWorkerId, Worker) then
    Worker.Send(ACommand, AMsg);
end;

{ Checks for heartbeat intervals and sends the heartbeat messages }
procedure TWorkers.SendHeartbeats;
var
  Worker: TWorker;
begin
  for Worker in FWorkers.Values do
  begin
    if MillisecondsBetween(Now, Worker.LastHeartbeatSent) > HEARTBEAT_INTERVAL then
      Worker.SendHeartbeat;
  end;
end;

{ Updates the last heartbeat received time from a worker }
procedure TWorkers.Heartbeat(const AWorkerId: String; const ALoadAvg: String);
var
  Worker: TWorker;
begin
  if FWorkers.TryGetValue(AWorkerId, Worker) then
    Worker.Heartbeat(ALoadAvg);
end;

{ Called when a worker gracefully disconnects }
procedure TWorkers.Disconnect(const AWorkerId: String);
begin
  { nothing to do }
end;

{ Returns the load average of the worker }
function TWorkers.LoadAvg(const AWorkerId: String): Single;
var
  Worker: TWorker;
begin
  if FWorkers.TryGetValue(AWorkerId, Worker) then
    Result := Worker.LoadAvg
  else
    Result := -1;
end;

{ Notifies the worker that the Broker is tracking the worker }
procedure TWorkers.SendReady(const AWorkerId: String);
var
  Worker: TWorker;
begin
  if FWorkers.TryGetValue(AWorkerId, Worker) then
    Worker.SendReady;
end;

{ TService }

constructor TService.Create(const AParent: TServices; const AName: String);
begin
  inherited Create;
  FParent := AParent;
  FName := AName;
  FWorkerIds := TgoSet<String>.Create;
end;

destructor TService.Destroy;
begin
  FWorkerIds.Free;
  inherited;
end;

{ Adds a worker to the service }
procedure TService.AddWorker(const AWorkerId: String);
begin
  FWorkerIds.AddOrSet(AWorkerId);
end;

{ Removes a worker from the service }
procedure TService.DeleteWorker(const AWorkerId: String);
begin
  FWorkerIds.Remove(AWorkerId);
end;

{ Finds the least used worker by load balancing }
function TService.FindWorker: String;
var
  WorkerId: String;
  LoadAvg, LeastAvg: Single;
begin
  LeastAvg := 999;
  Result := '';
  for WorkerId in FWorkerIds do
  begin
    LoadAvg := FParent.Broker.FWorkers.LoadAvg(WorkerId);
    if LoadAvg >= 0 then
      if LoadAvg < LeastAvg then
      begin
        LeastAvg := LoadAvg;
        Result := WorkerId;
      end
      else
      { if more than one worker is equally least busy, then randomly select one }
      if LoadAvg = LeastAvg then
      begin
        if (Random(2) = 1) then
        begin
          LeastAvg := LoadAvg;
          Result := WorkerId;
        end;
      end
  end;
end;

{ Sends a message to the service.  The service determines the appropriate worker
  to service the message }
function TService.Send(const ACommand: TZMQCommand; var AMsg: PZMessage;
  const ASendToId: String = ''): Boolean;
var
  WorkerId: String;
begin
  Result := False;
  if (FWorkerIds.Count > 0) then
  begin
    { use specified worker, or find the least used worker }
    if ASendToId = '' then
      WorkerId := FindWorker
    else
      WorkerId := ASendToId;

    { send the message to the worker }
    FParent.Broker.FWorkers.Send(WorkerId, ACommand, AMsg);
    Result := True;
  end;
end;

{ TServices }

constructor TServices.Create(const ABroker: TZMQBrokerProtocol);
begin
  inherited Create;
  FBroker := ABroker;
  FServices := TObjectDictionary<String, TService>.Create([doOwnsValues]);
end;

destructor TServices.Destroy;
begin
  FServices.Free;
  inherited;
end;

{ Adds a new service }
function TServices.Add(const AName: String): TService;
begin
  { add service if not already existing }
  if not FServices.TryGetValue(AName, Result) then
  begin
    Result := TService.Create(Self, AName);
    FServices.Add(AName, Result);
    Writeln(Format('Added service %s', [AName]));
  end;
end;

{ Adds a new worker to the service }
function TServices.AddWorker(const AName: String; const AWorkerId: String): Boolean;
var
  Service: TService;
begin
  Result := False;
  if FServices.TryGetValue(AName, Service) then
  begin
    if AWorkerId <> '' then
    begin
      Service.AddWorker(AWorkerId);
      Result := True;
      Writeln(Format('Added worker to service %s - %s', [AName, AWorkerId]));
    end;
  end;
end;

{ Removes a worker from the service }
function TServices.DeleteWorker(const AName: String; const AWorkerId: String): Boolean;
var
  Service: TService;
begin
  Result := False;
  if FServices.TryGetValue(AName, Service) then
  begin
    if AWorkerId <> '' then
    begin
      Service.DeleteWorker(AWorkerId);
      Result := True;
      Writeln(Format('Deleted worker from service %s - %s', [AName, AWorkerId]));
    end;
  end;
end;

{ Finds a worker in the service }
function TServices.FindWorker(const AName: String; out AWorkerId: String): Boolean;
var
  Service: TService;
begin
  if FServices.TryGetValue(AName, Service) then
  begin
    AWorkerId := Service.FindWorker;
    if AWorkerId <> '' then
      Result := True
    else
      Result := False;
  end
  else
    Result := False;
end;

{ Sends a message to the service.  The service determines the appropriate worker
  to service the message }
procedure TServices.Send(const AService: String; const ACommand: TZMQCommand;
  var AMsg: PZMessage; const ASendToId: String = '');
var
  Service: TService;
begin
  { add the service if it doesn't exist }
  Service := Add(AService);

  { send the message to the service }
  if Service <> nil then
  begin
    Service.Send(ACommand, AMsg, ASendToId);
  end;
end;

{ Forwards message from a client to a worker without modification }
procedure TServices.ForwardClientMessageToWorker(const AService: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; const ASendToId: String = '');
var
  RoutingFrame: PZFrame;
begin
  { add the client reply routing frame, so the worker replies to
    the correct client }
  AMsg.PushEmptyFrame;
  RoutingFrame := ASentFrom.Clone;
  AMsg.Push(RoutingFrame);

  { send the message that was received from the client to a worker
    that handles this service }
  Send(AService, TZMQCommand.ClientMessage, AMsg, ASendToId);
end;

{ TZMQBrokerProtocol }

constructor TZMQBrokerProtocol.Create;
begin
  inherited Create; { broker object is not thread safe, so do not use the zmq thread pool! }

  { Initialize }
  FServices := TServices.Create(Self);
  FWorkers := TWorkers.Create(Self);
  FLastCleanup := Now;
end;

destructor TZMQBrokerProtocol.Destroy;
begin
  inherited;
  FWorkers.Free;
  FServices.Free;
end;

{ Forward worker message to client }
procedure TZMQBrokerProtocol.ForwardWorkerMessageToClient(const AService: String;
  var AMsg: PZMessage);
var
  RoutingFrame: PZFrame;
begin
  { the client routing frame is embedded into the message as it is sent from the
    broker to the worker and back.   We extract it here and use it to direct
    the message to the correct client }
  RoutingFrame := AMsg.Unwrap;
  try
    AMsg.PushString(AService);
    AMsg.PushEnum<TZMQCommand>(TZMQCommand.ClientMessage);
    Send(AMsg, RoutingFrame);
  finally
    RoutingFrame.Free;
  end;
end;

{ This method is called when recv is idle, so that the parent can
  perform other background tasks while connected }
procedure TZMQBrokerProtocol.DoIdle;
begin
  { send heartbeat to workers }
  FWorkers.SendHeartbeats;

  { remove expired workers }
  if MillisecondsBetween(Now, FLastCleanup) > CLEANUP_INTERVAL then
    Cleanup;
end;

{ This event is fired whenever a new message is received by the broker. }
procedure TZMQBrokerProtocol.DoRecv(const ACommand: TZMQCommand; var AMsg: PZMessage;
  var ASentFrom: PZFrame);
var
  SentFromId: String;
  Service: String;
  LoadAvg: String;
  SendToId: String;
  Action: TZMQAction;
begin
  inherited;
  SentFromId := ASentFrom.ToHexString;
  Service := AMsg.PopString;
  case ACommand of
    TZMQCommand.Ready:
    begin
      { add worker }
      FWorkers.Add(
        SentFromId,
        ASentFrom,  // worker routing frame
        Service);

      { add service }
      FServices.Add(Service);

      { add worker to the service }
      FServices.AddWorker(Service, SentFromId);

      { notify the worker }
      FWorkers.SendReady(SentFromId);
    end;
    TZMQCommand.Heartbeat:
    begin
      LoadAvg := AMsg.PopString;
      FWorkers.Heartbeat(SentFromId, LoadAvg);
    end;
    TZMQCommand.Disconnect:
    begin
      FWorkers.Disconnect(SentFromId);
    end;
    TZMQCommand.ClientMessage:
    begin
      Action := TZMQAction.Discard;
      DoRecvFromClient(Service, SentFromId, ASentFrom, AMsg, Action, SendToId);
      case Action of
        TZMQAction.Discard: ;
        TZMQAction.Forward: FServices.ForwardClientMessageToWorker(Service, ASentFrom, AMsg);
        TZMQAction.SendTo: FServices.ForwardClientMessageToWorker(Service, ASentFrom, AMsg, SendToId);
      end;
    end;
    TZMQCommand.WorkerMessage:
    begin
      FWorkers.Heartbeat(SentFromId); { any data recv }
      Action := TZMQAction.Discard;
      DoRecvFromWorker(Service, SentFromId, ASentFrom, AMsg, Action);
      case Action of
        TZMQAction.Discard: ;
        TZMQAction.Forward: ForwardWorkerMessageToClient(Service, AMsg);
      end;
    end;
  end;
end;

procedure TZMQBrokerProtocol.DoRecvFromClient(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction; var ASendToId: String);
begin
  inherited;
end;

procedure TZMQBrokerProtocol.DoRecvFromWorker(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction);
begin
  inherited;
end;

procedure TZMQBrokerProtocol.DoDeleteWorker(const AService: String; const AWorkerId: String);
begin
  inherited;
end;

function TZMQBrokerProtocol.FindWorker(const AService: String; out AWorkerId: String): Boolean;
begin
  Result := FServices.FindWorker(AService, AWorkerId);
end;

{ Removes dead workers and cleans up related services }
procedure TZMQBrokerProtocol.Cleanup;
var
  Worker: TWorker;
  WorkerId: String;
  Service: String;
begin
  for Worker in FWorkers.FWorkers.Values.ToArray do
    if MillisecondsBetween(Now, Worker.LastHeartbeatRecv) > HEARTBEAT_EXPIRES then
    begin
      WorkerId := Worker.WorkerId;
      Service := Worker.Service;

      { remove worker from service }
      FServices.DeleteWorker(Service, WorkerId);

      { remove from workers list }
      FWorkers.Delete(WorkerId);

      { raise an event to indicate that we have lost a worker }
      DoDeleteWorker(Service, WorkerId);
    end;
  FLastCleanup := Now;
end;

end.
