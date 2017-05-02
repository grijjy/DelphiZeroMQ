program ExampleBroker;
{ Example broker using the ZMQ Broker Protocol class }

{$I Grijjy.inc}

{$APPTYPE CONSOLE}

uses
  Grijjy.Console,
  System.SysUtils,
  System.Messaging,
  ZMQ.Shared,
  ZMQ.BrokerProtocol,
  PascalZMQ;

type
  TExampleBroker = class(TZMQBrokerProtocol)
  private
    procedure LogMessageListener(const Sender: TObject; const M: TMessage);
  private
    { Receives a message from the Client }
    procedure DoRecvFromClient(const AService: String; const ASentFromId: String;
      const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction; var ASendToId: String); override;

    { Receives a message from the Worker }
    procedure DoRecvFromWorker(const AService: String; const ASentFromId: String;
      const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction); override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  Broker: TExampleBroker;

{ TExampleBroker }

constructor TExampleBroker.Create;
begin
  inherited;
  TMessageManager.DefaultManager.SubscribeToMessage(TZMQLogMessage, LogMessageListener);
end;

destructor TExampleBroker.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TZMQLogMessage, LogMessageListener);
  inherited;
end;

{ Out internal messages to the console }
procedure TExampleBroker.LogMessageListener(const Sender: TObject;
  const M: TMessage);
var
  LogMessage: TZMQLogMessage;
begin
  LogMessage := M as TZMQLogMessage;
  Writeln(LogMessage.Text);
end;

{ This event is fired whenever a new message is received from a client }
procedure TExampleBroker.DoRecvFromClient(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction; var ASendToId: String);
begin
  AAction := TZMQAction.Forward;
end;

{ This event is fired whenever a new message is received from a worker }
procedure TExampleBroker.DoRecvFromWorker(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction);
begin
  AAction := TZMQAction.Forward;
end;

begin
  try
    Broker := TExampleBroker.Create;
    try
      if Broker.Bind('tcp://*:1234') then
        WaitForCtrlC;
    finally
      Broker.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
