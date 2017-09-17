unit ZMQ.Protocol;
{ Base class for ZeroMQ protocol }

{$I Grijjy.inc}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  PascalZMQ,
  ZMQ.Shared;

const
  { The millisecond interval for heartbeats to the broker }
  HEARTBEAT_INTERVAL = 2500;

  { The millisecond elapsed expiration time for the broker heartbeat }
  HEARTBEAT_EXPIRES = 5000;

  { The millisecond recv timeout while waiting on incoming messages }
  POLLING_INTERVAL = 5;

  { The millisecond delay for reconnecting to the broker }
  RECONNECT_DELAY = 500;

  { Timeout connect }
  TIMEOUT_CONNECT = 5000;

  { Timeout bind }
  TIMEOUT_BIND = 5000;

type
  TZMQProtocol = class;

  { Polling thread }
  TZMQPollThread = class(TThread)
  private
    FParent: TZMQProtocol;

    { ZeroMQ socket for thread pool PULL }
    FSocket: TZSocket;

    { ZeroMQ context of parent PUSH socket }
    FContext: TZContext;
  protected
    procedure DoTerminate; override;
    procedure Execute; override;
  public
    constructor Create(const AParent: TZMQProtocol; const AContext: TZContext);
    destructor Destroy; override;
  end;

  { Protocol interface }
  TZMQProtocol = class(TThread)
  private
    { Internal }
    FState: TZMQState;

    { ZeroMQ context }
    FContext: TZContext;

    { ZeroMQ socket }
    FSocket: TZSocket;

    { ZeroMQ socket type }
    FSocketType: TZSocketType;

    { Broker IP/Hostname }
    FBrokerAddress: String;

    { Broker public key }
    FBrokerPublicKey: String;

    { ZeroMQ routing id }
    FSelfId: String;

    { Using heartbeats, if applicable }
    FHeartbeats: Boolean;

    { Last time a heartbeat was sent to the broker }
    FLastHeartbeatSent: TDateTime;

    { Last time a heartbeat was received from the broker }
    FLastHeartbeatRecv: TDateTime;

    { Last error generated }
    FLastError: Integer;

    { Use ZMQ built in curve encryption }
    FCurveZMQ: Boolean;

    { Authentication and certificate }
    FCertificate: TZCertificate;

    { Send queue for messages }
    FMessageQueue: TQueue<PZMessage>;
    FMessageQueueLock: TCriticalSection;

    { Received messages contain reply routing frames }
    FExpectReplyRoutingFrames: Boolean;

    { Use thread pool }
    FUseThreadPool: Boolean;

    { Polling threads PUSH context }
    FPollThreadsContext: TZContext;

    { Polling threads PUSH socket }
    FPollThreadsSocket: TZSocket;

    { Polling threads for load balancing }
    FPollThreads: array of TZMQPollThread;

    [volatile] FMessageId: Integer;

    { Handle exception for a specific poll thread }
    procedure HandleException(const APollThread: TZMQPollThread);
  private
    { Get thread safe MessageId }
    function GetNextMessageId: Integer;
  protected
    { Internal bind broker address }
    function _Bind: Boolean;

    { This method is called when the connection is established }
    procedure DoConnected; virtual;

    { Internal connect to broker }
    function _Connect: Boolean;

    { Internal disconnect from broker }
    procedure _Disconnect;

    { Internal reconnect to broker }
    procedure _Reconnect;

    { This method is called when a heartbeat needs to be sent }
    procedure DoHeartbeat; virtual;

    { This method is called when recv is idle, so that the parent can
      perform other background tasks while connected }
    procedure DoIdle; virtual;

    { This method is called whenever a new message is received.  ASentFrom
      is provided only when the socket type is ZMQ_ROUTER otherwise it is
      NIL. The message can be handled asynchronously or synchronously by calling
      the Send() method in response. }
    procedure DoRecv(const ACommand: TZMQCommand;
      var AMsg: PZMessage; var ASentFrom: PZFrame); virtual;

    { This method is called whenever a new message may need to be unwrapped
      because it was originated from by a ZMQ_DEALER socket }
    procedure _DoRecv(const ACommand: TZMQCommand;
      var AMsg: PZMessage);

    { Receives a message from the socket, timeout or error. Caller is responsible
      for calling zmsg_destroy() to destroy AMsg.  Recv() failing multiple
      times with LastError = ERR_TIMEOUT is an indicator that communications
      may have failed and the client should all Connect() to establish
      communications again. }
    function _Recv(out AMsg: PZMessage): Boolean;

    { Sends any queued messages to the socket
      ZeroMQ sockets are not thread safe so we must perform all socket related IO
      operations from inside the same thread.  To insure that sends that are
      generated from multiple threads are serialized and sent by the thread that
      owns the socket, we use a queue }
    procedure _Send;

    { Helps us capture exceptions }
    procedure DoTerminate; override;

    { Run process loop }
    procedure Execute; override;
  public
    constructor Create(const AHeartbeats: Boolean = False;
      const AExpectReplyRoutingFrames: Boolean = False;
      const AUseThreadPool: Boolean = False;
      const APollThreads: Integer = 0);
    destructor Destroy; override;

    { This method binds the broker instance to an endpoint. Note that the protocol
      uses a single socket for both clients and workers }
    function Bind(const ABrokerAddress: String;
      ASocketType: TZSocketType = TZSocketType.Router; const ACurveZMQ: Boolean = False): Boolean;

    { Connect to broker
      ASocketType could be ZMQ_REQ for synchronous communications
      or ZMQ_DEALER for asychronous communications }
    function Connect(const ABrokerAddress: String;
      const ABrokerPublicKey: String = '';
      const ASocketType: TZSocketType = TZSocketType.Dealer): Boolean; virtual;

    { Disconnect }
    procedure Disconnect;

    { Send message }
    procedure Send(var AMsg: PZMessage); overload;

    { Send message to a specific target with the supplied routing frame.
      This method is used by the broker to send messages to a specific worker
      or a specific client }
    procedure Send(var AMsg: PZMessage; var ARoutingFrame: PZFrame); overload;

    { Last error reported from class }
    property LastError: Integer read FLastError;

    { Heartbeats }
    property Heartbeats: Boolean read FHeartbeats write FHeartbeats;

    { State }
    property State: TZMQState read FState;

    { Routing id }
    property SelfId: String read FSelfId;

    { Thread safe message id }
    property NextMessageId: Integer read GetNextMessageId;
  end;

implementation

{ TZMQProtocol }

constructor TZMQProtocol.Create(const AHeartbeats: Boolean;
  const AExpectReplyRoutingFrames: Boolean;
  const AUseThreadPool: Boolean;
  const APollThreads: Integer);
var
  I: Integer;
  PollThreads: Integer;
begin
  inherited Create;
  { initialize }
  FLastError := 0;
  FHeartbeats := AHeartbeats;
  FExpectReplyRoutingFrames := AExpectReplyRoutingFrames;
  FUseThreadPool := AUseThreadPool;
  FCurveZMQ := False;
  FState := TZMQState.Idle;
  FContext := TZContext.Create;
  FMessageQueue := TQueue<PZMessage>.Create;
  FMessageQueueLock := TCriticalSection.Create;
  FMessageId := 0;

  { initialize thread pool }
  if FUseThreadPool then
  begin
    FPollThreadsContext := TZContext.Create;
    FPollThreadsSocket := TZSocket.Create(FPollThreadsContext, TZSocketType.Push);
    FPollThreadsSocket.Bind('inproc://workers');
    if APollThreads = 0 then
      PollThreads := CPUCount
    else
      PollThreads := APollThreads;
    if PollThreads < 2 then
      PollThreads := 2; { minimum number of workers }
    SetLength(FPollThreads, PollThreads);
    for I := 0 to Length(FPollThreads) - 1 do
      FPollThreads[I] := TZMQPollThread.Create(Self, FPollThreadsContext);
  end;
end;

destructor TZMQProtocol.Destroy;
var
  I: Integer;
  Msg: PZMessage;
begin
  inherited;
  if FUseThreadPool then
  begin
    for I := 0 to Length(FPollThreads) - 1 do
    begin
      FPollThreads[I].Terminate;
      FPollThreads[I].Free;
    end;
    FPollThreadsSocket.Free(FPollThreadsContext);
    FreeAndNil(FPollThreadsContext);
  end;
  FreeAndNil(FContext);
  FCertificate.Free;
  FMessageQueueLock.Enter;
  try
    { Destroy any messages that may have been left in the queue }
    if Assigned(FMessageQueue) then
    begin
      while (FMessageQueue.Count > 0) do
      begin
        Msg := FMessageQueue.Dequeue;
        Msg.Free;
      end;
    end;
    FMessageQueue.Free;
  finally
    FMessageQueueLock.Leave;
  end;
  FMessageQueueLock.Free;
end;

{ This method binds the broker instance to an endpoint. Note that the protocol
  uses a single socket for both clients and workers }
function TZMQProtocol.Bind(const ABrokerAddress: String;
  ASocketType: TZSocketType; const ACurveZMQ: Boolean): Boolean;
var
  Start: TDateTime;
begin
  FBrokerAddress := ABrokerAddress;
  FSocketType := ASocketType;
  FCurveZMQ := ACurveZMQ;
  FState := TZMQState.Bind;

  { wait for bind to complete }
  Start := Now;
  while (MilliSecondsBetween(Now, Start) < TIMEOUT_BIND) and
    (FState <> TZMQState.Idle) and
    (FState <> TZMQState.Connected) do
    Sleep(5);
  Result := FState = TZMQState.Connected;
end;

{ Internal bind broker address }
function TZMQProtocol._Bind: Boolean;
begin
  FSocket := TZSocket.Create(FContext, FSocketType);

  if FCurveZMQ then
  begin
    { Load our persistent certificate from disk }
    if FileExists(ExtractFilePath(ParamStr(0)) + 'cert') then
      FCertificate := TZCertificate.Create('cert')
    else
    begin
      { Create and save the certificate }
      FCertificate := TZCertificate.Create;
      FCertificate.Save(ExtractFilePath(ParamStr(0)) + 'cert');
      LogMessage('Certificate created');
    end;

    { Apply certificate to the socket and use full encryption }
    FCertificate.Apply(FSocket);
    FSocket.IsCurveServer := True;
  end;

  { Bind the socket }
  Result := (FSocket.Bind(FBrokerAddress{%H-}) <> -1);
  if Result then
    LogMessage('Broker is active at ' + FBrokerAddress)
  else
    LogMessage('Error! Unable to start broker at ' + FBrokerAddress);
end;

{ Connect to broker
  ASocketType could be ZMQ_REQ for synchronous communications
  or ZMQ_DEALER for asychronous communications }
function TZMQProtocol.Connect(const ABrokerAddress: String;
  const ABrokerPublicKey: String; const ASocketType: TZSocketType): Boolean;
var
  Start: TDateTime;
begin
  FBrokerAddress := ABrokerAddress;
  FBrokerPublicKey := ABrokerPublicKey;
  FSocketType := ASocketType;
  FState := TZMQState.Connect;

  { wait for connection to complete }
  Start := Now;
  while (MilliSecondsBetween(Now, Start) < TIMEOUT_CONNECT) and
    (FState <> TZMQState.Idle) and
    (FState <> TZMQState.Connected) do
    Sleep(5);
  Result := FState = TZMQState.Connected;
end;

procedure TZMQProtocol.Disconnect;
begin
  _Disconnect;
end;

{ This method is called when the connection is established }
procedure TZMQProtocol.DoConnected;
begin
  inherited;
end;

{ Internal connect to broker }
function TZMQProtocol._Connect: Boolean;
begin
  { start by disconnecting, if applicable }
  _Disconnect;

  { create socket }
  FSocket := TZSocket.Create(FContext, FSocketType);

  { prevent linger of messages after disconnect }
  FSocket.Linger := 0;

  { apply the server public certificate and configure it to use full encryption }
  if FBrokerPublicKey <> '' then
  begin
    FCertificate := TZCertificate.Create;
    FCertificate.Apply(FSocket);

    { Apply broker public key to the socket }
    FSocket.SetCurveServerKey(FBrokerPublicKey{%H-});
  end;

  { connect }
  LogMessage('Connecting to broker at ' + FBrokerAddress);
  Result := FSocket.Connect(FBrokerAddress{%H-});
  if Result then
    LogMessage('Connected to broker at ' + FBrokerAddress)
  else
    LogMessage('Error! Unable to connect to broker at ' + FBrokerAddress);

  { initial heartbeat }
  if FHeartbeats then
  begin
    FLastHeartbeatSent := Now;
    FLastHeartbeatRecv := Now;
  end;
end;

{ Internal disconnect from broker }
procedure TZMQProtocol._Disconnect;
begin
  FSocket.Disconnect(FBrokerAddress{%H-});
  FSocket.Free(FContext);
  FreeAndNil(FCertificate);
end;

{ Internal reconnect to broker }
procedure TZMQProtocol._Reconnect;
begin
  Connect(FBrokerAddress, FBrokerPublicKey, FSocketType);
end;

{ This method is called when a heartbeat needs to be sent }
procedure TZMQProtocol.DoHeartbeat;
begin
  inherited;
end;

{ This method is called when recv is idle, so that the parent can
  perform other background tasks while connected }
procedure TZMQProtocol.DoIdle;
begin
  inherited;
end;

{ Send message }
procedure TZMQProtocol.Send(var AMsg: PZMessage);
//var
//  Command: TZMQCommand;
begin
  if AMsg.FrameCount = 0 then Exit;
//  Command := TZMQCommand(AMsg.Frames[0].AsInteger);

  if (FSocketType in [TZSocketType.Dealer, TZSocketType.Router])then
    { empty frame, for ZMQ_DEALER emulation }
    AMsg.PushEmptyFrame;

//  if (Command <> TZMQCommand.ClientMessage) and
//    (Command <> TZMQCommand.WorkerMessage) then
//    _Log.Send(Self, Command, AMsg);

  FMessageQueueLock.Enter;
  try
    FMessageQueue.Enqueue(AMsg);
  finally
    FMessageQueueLock.Leave;
  end;
  { the zmsg_send will automatically destroy the message, so we need to
   prevent the destruction of the object by our own method }
  AMsg := nil;
end;

{ Send message to a specific target with the supplied routing frame.
  This method is used by the broker to send messages to a specific worker
  or a specific client }
procedure TZMQProtocol.Send(var AMsg: PZMessage; var ARoutingFrame: PZFrame);
//var
//  Command: TZMQCommand;
begin
  if AMsg.FrameCount = 0 then Exit;
//  Command := TZMQCommand(AMsg.Frames[0].AsInteger);

  if (FSocketType in [TZSocketType.Dealer, TZSocketType.Router]) then
    { empty frame, for ZMQ_DEALER emulation }
    AMsg.PushEmptyFrame;

//  if (Command <> TZMQCommand.ClientMessage) and
//    (Command <> TZMQCommand.WorkerMessage) then
//    _Log.Send(Self, ARoutingFrame, Command, AMsg);

  AMsg.Push(ARoutingFrame);
  FMessageQueueLock.Enter;
  try
    FMessageQueue.Enqueue(AMsg);
  finally
    FMessageQueueLock.Leave;
  end;
  { the zmsg_send will automatically destroy the message, so we need to
   prevent the destruction of the object by our own method }
  AMsg := nil;
end;

{ This method is called whenever a new message is received.  ASentFrom
  is provided only when the socket type is ZMQ_ROUTER otherwise it is
  NIL. The message can be handled asynchronously or synchronously by calling
  the Send() method in response. }
procedure TZMQProtocol.DoRecv(const ACommand: TZMQCommand;
  var AMsg: PZMessage; var ASentFrom: PZFrame);
begin
  inherited;
end;

{ This method is called whenever a new message may need to be unwrapped
  because it was originated from by a ZMQ_DEALER socket }
procedure TZMQProtocol._DoRecv(const ACommand: TZMQCommand;
  var AMsg: PZMessage);
var
  SentFrom: PZFrame;
begin
  { for dealer sockets, the message may contain an optional reply
    routing frame so we unpack the frame if required.  Only service
    modules actually include the reply routing frame currently }
  if FExpectReplyRoutingFrames then
  begin
    if (AMsg.FrameCount >= 2) then
    begin
      SentFrom := AMsg.Unwrap;
      try
        DoRecv(ACommand, AMsg, SentFrom);
      finally
        SentFrom.Free;
      end;
    end;
  end
  else
  begin
    SentFrom := nil;
    DoRecv(ACommand, AMsg, SentFrom);
  end;
end;

{ Receives a message from the socket, timeout or error. Caller is responsible
  for calling zmsg_destroy() to destroy AMsg.  Recv() failing multiple
  times with LastError = ERR_TIMEOUT is an indicator that communications
  may have failed and the client should all Connect() to establish
  communications again. }
function TZMQProtocol._Recv(out AMsg: PZMessage): Boolean;
begin
  Result := False;
  { wait for an item, timeout or error }
  { the poll method for zmq creates a sleep, so it is not necessary to also
    do this inside the thread }
  case FSocket.Poll(TZSocketPoll.Input, POLLING_INTERVAL) of
    TZSocketPollResult.Available:
      begin
        AMsg := FSocket.Receive;
        if (AMsg <> nil) then
          Result := True
        else
          FLastError := ERR_RECV_INTERRUPTED;
      end;

    TZSocketPollResult.Timeout:
      FLastError := ERR_TIMEOUT;
  else
    FLastError := ERR_POLL_INTERRUPTED;
  end;
end;

{ Sends any queued messages to the socket }
procedure TZMQProtocol._Send;
var
  Msg: PZMessage;
begin
  FMessageQueueLock.Enter;
  try
    while FMessageQueue.Count > 0 do
    begin
      Msg := FMessageQueue.Dequeue;
      FSocket.Send(Msg);
    end;
  finally
    FMessageQueueLock.Leave;
  end;
end;

procedure TZMQProtocol.DoTerminate;
var
  E: TObject;
begin
  E := FatalException;
  if Assigned(E) then
  begin
  begin
    PPointer(@FatalException)^ := nil;
    LogMessage(Format('Error! Exception [%s]', [Exception(E).Message]));
  end;
  end;
  inherited;
end;

{ Run process loop }
procedure TZMQProtocol.Execute;
var
  Msg: PZMessage;
  SentFrom: PZFrame;
  Command: TZMQCommand;
begin
  {$IFDEF DEBUG}
  NameThreadForDebugging('TZMQProtocol');
  {$ENDIF}
  while not Terminated do
  begin
    case FState of
      TZMQState.Idle: Sleep(5);
      TZMQState.Bind:
      begin
        if _Bind then
        begin
          FState := TZMQState.Connected;
        end
        else
          FState := TZMQState.Idle;
      end;
      TZMQState.Connect:
      begin
        if _Connect then
        begin
          DoConnected;
          FState := TZMQState.Connected;
        end
        else
          FState := TZMQState.Idle;
      end;
      TZMQState.Connected:
      begin
        try
          if _Recv(Msg) then
          begin
            try
              SentFrom := nil;
              if (FSocketType = TZSocketType.Router) and (Msg.FrameCount >= 3) then
              begin
                { routing frame for identifying the sender for replies }
                SentFrom := Msg.Pop;
                try
                  { empty frame, for ZMQ_DEALER emulation }
                  Msg.PopBytes;
                  Command := Msg.PopEnum<TZMQCommand>;
//                  if (Command <> TZMQCommand.ClientMessage) and
//                    (Command <> TZMQCommand.WorkerMessage) then
//                    _Log.Recv(Self, SentFrom, Command, Msg);
                  DoRecv(Command, Msg, SentFrom);
                finally
                  SentFrom.Free;
                end;
              end
              else
              if (FSocketType = TZSocketType.Dealer) and (Msg.FrameCount >= 2) then
              begin
                { empty frame, for ZMQ_DEALER emulation }
                Msg.PopBytes;
                Command := Msg.PopEnum<TZMQCommand>;
//                if (Command <> TZMQCommand.ClientMessage) and
//                  (Command <> TZMQCommand.WorkerMessage) then
//                  _Log.Recv(Self, TZMQCommand(Command), Msg);

                { for dealer sockets we handle the internal commands directly }
                case Command of
                  TZMQCommand.Ready: FSelfId := Msg.PopString;
                  TZMQCommand.Heartbeat: FLastHeartbeatRecv := Now;
                  TZMQCommand.Disconnect: FState := TZMQState.Disconnect;
                else
                  begin
                    if FUseThreadPool then
                    begin
                      { add the command back to the message }
                      Msg.PushEnum<TZMQCommand>(Command);
                      { push the message to the PUSH/PULL thread pool }
                      FPollThreadsSocket.Send(Msg);
                    end
                    else
                      _DoRecv(Command, Msg);
                  end;
                end;
              end
              else
                FLastError := ERR_INVALID_PAYLOAD;
            finally
              { zmq automatically destroys messages when they are sent, so if the
                message was generated and received internally and is never going
                to be sent or forwarded, then we must destroy it ourselves }
              Msg.Free;
            end;
          end
          else
          begin
            if (FLastError = ERR_RECV_INTERRUPTED) then
              LogMessage('Error! Recv error')
            else
            if (FLastError = ERR_POLL_INTERRUPTED) then
            begin
              LogMessage('Error! Poll interrupted, shutting down');
              Terminate;
            end
            else
            if FLastError = ERR_TIMEOUT then
            begin
              { do nothing }
            end;
          end;
        except
          on e: EZMQError do
          begin
            LogMessage(Format('Error! Recv exception [%s]', [e.Message]));
          end
          else
            raise;
        end;

        { send all pending queued messages }
        _Send;

        { are we sending heartbeats internally? }
        if FHeartbeats then
        begin
          { send heartbeat to broker }
          if MillisecondsBetween(Now, FLastHeartbeatSent) > HEARTBEAT_INTERVAL then
          begin
            DoHeartbeat;
            FLastHeartbeatSent := Now;
          end;

          { check for broker expired heartbeat }
          if MillisecondsBetween(Now, FLastHeartbeatRecv) > HEARTBEAT_EXPIRES then
          begin
            LogMessage('Error! Disconnected from broker - retrying');
            { attempt to reconnect }
            Sleep(RECONNECT_DELAY);
            _Reconnect;
          end;
        end;

        { This method is called when recv is idle, so that the parent can
          perform other background tasks while connected }
        DoIdle;
      end;
      TZMQState.Disconnect:
      begin
        _Disconnect;
        FState := TZMQState.Disconnected;
      end;
      TZMQState.Disconnected:
      begin
        { attempt to reconnect }
        Sleep(RECONNECT_DELAY);
        _Reconnect;
      end;
    end;
  end;
  FState := TZMQState.Shutdown;
end;

function TZMQProtocol.GetNextMessageId: Integer;
begin
  Result := TInterlocked.Increment(FMessageId);
end;

procedure TZMQProtocol.HandleException(const APollThread: TZMQPollThread);
var
  I: Integer;
begin
  { restart the poll thread }
  for I := 0 to Length(FPollThreads) - 1 do
    if FPollThreads[I] = APollThread then
    begin
      FPollThreads[I] := TZMQPollThread.Create(Self, FPollThreadsContext);
      Break;
    end;
end;

{ TZMQPollThread }

constructor TZMQPollThread.Create(const AParent: TZMQProtocol; const AContext: TZContext);
begin
  FParent := AParent;
  FContext := AContext;
  inherited Create;
end;

destructor TZMQPollThread.Destroy;
begin
  inherited;
  FSocket.Free(FContext);
end;

procedure TZMQPollThread.DoTerminate;
var
  E: TObject;
begin
  E := FatalException;
  if Assigned(E) then
  begin
    FSocket.Unbind('inproc://workers'); { stop process worker tasks }
    FParent.HandleException(Self);
    PPointer(@FatalException)^ := nil;
    LogMessage(Format('Error! Exception [%s]', [Exception(E).Message]));
  end;
  inherited;
end;

procedure TZMQPollThread.Execute;
var
  Msg: PZMessage;
  Command: TZMQCommand;
begin
  {$IFDEF DEBUG}
  NameThreadForDebugging('TZMQPollThread');
  {$ENDIF}

  { connect to parent zmq context to recv tasks }
  FSocket := TZSocket.Create(FContext, TZSocketType.Pull);
  FSocket.Connect('inproc://workers');

  while not Terminated do
  begin
    { wait for an item, timeout or error }
    { the poll method for zmq creates a sleep, so it is not necessary to also
      do this inside the thread }
    case FSocket.Poll(TZSocketPoll.Input, POLLING_INTERVAL) of
      TZSocketPollResult.Available:
        begin
          { pull from the thread pool socket }
          Msg := FSocket.Receive;
          if (Msg <> nil) then
          begin
            try
              Command := Msg.PopEnum<TZMQCommand>;
              FParent._DoRecv(Command, Msg);
            finally
              Msg.Free;
            end;
          end
          else
          begin
            { recv interrupted }
            LogMessage('Error! Recv error');
          end;
        end;

      TZSocketPollResult.Interrupted:
        begin
          { poll interrupted }
          LogMessage('Error! Poll interrupted, shutting down');
          Terminate;
        end;

//      TZSocketPollResult.Timeout: Do nothing
    end;
  end;
end;

end.
