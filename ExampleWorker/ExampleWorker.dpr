program ExampleWorker;
{ Example Worker service module using the ZMQ Worker Protocol class }

{$I Grijjy.inc}

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Messaging,
  Grijjy.Console,
  PascalZMQ,
  ZMQ.Shared,
  ZMQ.WorkerProtocol;

const
  SERVICE_NAME = 'MyService';

type
  TExampleWorker = class(TZMQWorkerProtocol)
  protected
    { Receives a message from the Broker }
    procedure DoRecv(const ACommand: TZMQCommand;
      var AMsg: PZMessage; var ASentFrom: PZFrame); override;
  private
    procedure LogMessageListener(const Sender: TObject; const M: TMessage);
  public
    constructor Create;
    destructor Destroy; override;

    { Sends a command to the Broker }
    procedure Send(const AData: TBytes; var ARoutingFrame: PZFrame;
      const ADestroyRoutingFrame: Boolean = True); overload;
    procedure Send(const AData: Pointer; const ASize: Integer;
      var ARoutingFrame: PZFrame; const ADestroyRoutingFrame: Boolean = True); overload;
  end;

var
  Worker: TExampleWorker;

{ TExampleWorker }

constructor TExampleWorker.Create;
begin
  TMessageManager.DefaultManager.SubscribeToMessage(TZMQLogMessage, LogMessageListener);
  inherited Create(
    True,   // use heartbeats
    True,   // expect reply routing frames
    True);  // use thread pool
end;

destructor TExampleWorker.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TZMQLogMessage, LogMessageListener);
  inherited;
end;

{ Out internal messages to the console }
procedure TExampleWorker.LogMessageListener(const Sender: TObject;
  const M: TMessage);
var
  LogMessage: TZMQLogMessage;
begin
  LogMessage := M as TZMQLogMessage;
  Writeln(LogMessage.Text);
end;

procedure TExampleWorker.Send(const AData: TBytes; var ARoutingFrame: PZFrame;
  const ADestroyRoutingFrame: Boolean = True);
var
  Msg: PZMessage;
  RoutingFrame: PZFrame;
begin
  Msg := TZMessage.Create;
  Msg.PushBytes(AData);
  if ADestroyRoutingFrame then
    inherited Send(Msg, ARoutingFrame)
  else
  begin
    RoutingFrame := ARoutingFrame.Clone;
    inherited Send(Msg, RoutingFrame)
  end;
end;

procedure TExampleWorker.Send(const AData: Pointer; const ASize: Integer;
var ARoutingFrame: PZFrame; const ADestroyRoutingFrame: Boolean = True);
var
  Msg: PZMessage;
  RoutingFrame: PZFrame;
begin
  Msg := TZMessage.Create;
  Msg.PushMemory(AData^, ASize);
  if ADestroyRoutingFrame then
    inherited Send(Msg, ARoutingFrame)
  else
  begin
    RoutingFrame := ARoutingFrame.Clone;
    inherited Send(Msg, RoutingFrame)
  end;
end;

{ Receives a command from the Broker }
procedure TExampleWorker.DoRecv(const ACommand: TZMQCommand; var AMsg: PZMessage;
  var ASentFrom: PZFrame);
var
  Request, Response: TBytes;
begin
  Request := AMsg.PopBytes;

  { Write to console... }
  Writeln(StringOf(Request));

  { We would analyze the request here and build a response to send back to the client }
  Send(Response, ASentFrom);
end;

begin
  Worker := TExampleWorker.Create;
  try
    if Worker.Connect('tcp://localhost:1234', '', TZSocketType.Dealer, SERVICE_NAME) then
      WaitForCtrlC;
  finally
    Worker.Free;
  end;
end.
