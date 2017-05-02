unit FMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.TypInfo,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Edit,
  PascalZMQ,
  ZMQ.Shared,
  ZMQ.ClientProtocol;

const
  SERVICE_NAME = 'MyService';

type
  { Example Client using the ZMQ Client Protocol class }
  TExampleClient = class(TZMQClientProtocol)
  private
    { Sends a message to the specified service, with optional data }
    procedure Send(const AService: String; const AData: TBytes); reintroduce;
  protected
    { Implements the DoRecv from the client protocol class }
    procedure DoRecv(const ACommand: TZMQCommand;
      var AMsg: PZMessage; var ASentFrom: PZFrame); override;
  public
    constructor Create;
    destructor Destroy; override;
  public
    procedure Connect(const ABrokerAddress: String); reintroduce;
  end;

type
  TFormMain = class(TForm)
    SendRequest: TButton;
    EditBroker: TEdit;
    LabelBroker: TLabel;
    ButtonApply: TButton;
    procedure SendRequestClick(Sender: TObject);
    procedure ButtonApplyClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

var
  Client: TExampleClient;

{ TExampleClient }

constructor TExampleClient.Create;
begin
  inherited Create;
end;

destructor TExampleClient.Destroy;
begin
  inherited;
end;

procedure TExampleClient.Connect(const ABrokerAddress: String);
begin
  inherited Connect(ABrokerAddress, '', TZSocketType.Dealer);
end;

procedure TExampleClient.Send(const AService: String; const AData: TBytes);
var
  Msg: PZMessage;
begin
  Msg := TZMessage.Create;
  try
    Msg.PushBytes(AData);
    inherited Send(AService, Msg);
  finally
    Msg.Free;
  end;
end;

procedure TExampleClient.DoRecv(const ACommand: TZMQCommand;
  var AMsg: PZMessage; var ASentFrom: PZFrame);
var
  Service: String;
  Response: TBytes;
begin
  { Responding service name }
  Service := AMsg.PopString;

  { Response bytes }
  Response := AMsg.PopBytes;
end;

procedure TFormMain.ButtonApplyClick(Sender: TObject);
begin
  Client.Connect(EditBroker.Text);
end;

procedure TFormMain.SendRequestClick(Sender: TObject);
var
  Bytes: TBytes;
begin
  { Connect, if needed }
  Client.Connect(EditBroker.Text);

  { Send some data }
  Bytes := BytesOf('ABCDEFGHIJ');
  Client.Send(SERVICE_NAME, Bytes);
end;

initialization
  Client := TExampleClient.Create;

finalization
  Client.Free;

end.
