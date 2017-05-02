unit ZMQ.Shared;
{ Shared consts, types and helpers across all ZeroMQ classes }

{$I Grijjy.inc}

interface

uses
  System.SysUtils,
  System.Messaging,
  PascalZMQ;

const
  { Error codes }
  ERR_TIMEOUT = 1;
  ERR_RECV_INTERRUPTED = 2;
  ERR_POLL_INTERRUPTED = 3;
  ERR_CONTEXT_INTERRUPTED = 4;
  ERR_INVALID_PAYLOAD = 5;

type
  { Protocol state }
  TZMQState = (Idle, Bind, Connect, Connected, Disconnect, Disconnected, Shutdown);

  { Commands }
  TZMQCommand = (
    Ready = 1,
    Heartbeat = 2,
    Disconnect = 3,
    WorkerMessage = 4,
    ClientMessage = 5
    );

  { Actions }
  TZMQAction = (
    Discard = 1,
    Forward = 2,
    SendTo = 3
    );

  { Internal message }
  TZMQLogMessage = class(TMessage)
  private
    FText: String;
  public
    constructor Create(AText: String);
  public
    property Text: String read FText;
  end;

{ Command to string }
function ZMQCommandToString(const ACommand: TZMQCommand): String;

{ Log internal message }
procedure LogMessage(const AText: String);

implementation

{ TZMQLogMessage }

constructor TZMQLogMessage.Create(AText: String);
begin
  inherited Create;
  FText := AText;
end;

function ZMQCommandToString(const ACommand: TZMQCommand): String;
begin
  case ACommand of
    TZMQCommand.Ready: Result := 'READY';
    TZMQCommand.Heartbeat: Result := 'HEARTBEAT';
    TZMQCommand.Disconnect: Result := 'DISCONNECT';
    TZMQCommand.WorkerMessage: Result := 'WORKER_MESSAGE';
    TZMQCommand.ClientMessage: Result := 'CLIENT_MESSAGE';
  else
    Result := Ord(ACommand).ToString;
  end;
end;

procedure LogMessage(const AText: String);
var
  LogMessage: TZMQLogMessage;
begin
  LogMessage := TZMQLogMessage.Create(AText);
  TMessageManager.DefaultManager.SendMessage(nil, LogMessage);
end;

end.
