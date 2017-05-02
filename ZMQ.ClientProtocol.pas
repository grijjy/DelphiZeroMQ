unit ZMQ.ClientProtocol;
{ Base class for ZeroMQ client protocol }

{$I Grijjy.inc}

interface

uses
  PascalZMQ,
  System.SysUtils,
  System.Classes,
  ZMQ.Protocol,
  ZMQ.Shared;

type
  { This event is called whenever a new message is received by the client }
  TOnRecv = procedure(const AService: String; const AMsg: PZMessage) of object;

  { Client interface }
  TZMQClientProtocol = class(TZMQProtocol)
  private
    { Internal }
    FOnRecv: TOnRecv;
  protected
    { This method is called when recv is idle, so that the parent can
      perform other background tasks while connected }
    procedure DoIdle; override;

    { This method is called whenever a new message is received by the client }
    procedure DoRecv(const ACommand: TZMQCommand; var AMsg: PZMessage;
      var ASentFrom: PZFrame); override;
  public
    constructor Create;
    destructor Destroy; override;

    { Sends a message to the specified service }
    procedure Send(const AService: String; var AMsg: PZMessage); virtual;

    { This event is called whenever a new message is received by the client }
    property OnRecv: TOnRecv read FOnRecv write FOnRecv;
  end;

implementation

constructor TZMQClientProtocol.Create;
begin
  inherited Create;
end;

destructor TZMQClientProtocol.Destroy;
begin
  inherited;
end;

procedure TZMQClientProtocol.DoIdle;
begin
  inherited;
end;

procedure TZMQClientProtocol.DoRecv(const ACommand: TZMQCommand;
  var AMsg: PZMessage; var ASentFrom: PZFrame);
var
  Service: String;
begin
  inherited;
  Service := AMsg.PopString;
  if Assigned(FOnRecv) then
    FOnRecv(Service, AMsg);
end;

procedure TZMQClientProtocol.Send(const AService: String; var AMsg: PZMessage);
begin
  AMsg.PushString(AService);
  AMsg.PushEnum<TZMQCommand>(TZMQCommand.ClientMessage);
  inherited Send(AMsg);
end;

end.
