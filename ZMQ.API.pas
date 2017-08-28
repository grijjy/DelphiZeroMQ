unit ZMQ.API;
{ Interface unit for cross-platform ZeroMQ libaries }

interface

{$IF Defined(ANDROID) or Defined(IOS)}
  {$DEFINE STATIC_BINDING}
{$ELSE}
  {$DEFINE DYNAMIC_BINDING}
{$ENDIF}

const
  {$IF Defined(MSWINDOWS)}
    {$IFDEF WIN64}
    ZMQ_LIB = 'libzmq-win64.dll';
    _PU = '';
    {$ELSE}
    ZMQ_LIB = 'libzmq-win32.dll';
    _PU = '';
    {$ENDIF}
  {$ELSEIF Defined(LINUX)}
  ZMQ_LIB = 'libzmq-linux64.so';
  _PU = '';
  {$ELSEIF Defined(MACOS)}
    {$IFDEF IOS}
      {$IFDEF CPUARM}
      ZMQ_LIB = 'libzmq-ios.a';
      _PU = '';
      {$ELSE}
      ZMQ_LIB = 'libzmq-iossim.dylib'; { not supported }
      _PU = '';
      {$ENDIF}
    {$ELSE}
      {$IFDEF MACOS64}
      ZMQ_LIB = 'libzmq-osx64.dylib';
      _PU = '';
      {$ELSE}
      ZMQ_LIB = 'libzmq-osx32.dylib';
      _PU = '_';
      {$ENDIF}
    {$ENDIF}
  {$ELSEIF Defined(ANDROID)}
  ZMQ_LIB = 'libzmq-android.a';
  _PU = '';
  {$ENDIF}

const
  ZMQ_PAIR = 0;
  ZMQ_PUB = 1;
  ZMQ_SUB = 2;
  ZMQ_REQ = 3;
  ZMQ_REP = 4;
  ZMQ_DEALER = 5;
  ZMQ_ROUTER = 6;
  ZMQ_PULL = 7;
  ZMQ_PUSH = 8;
  ZMQ_XPUB = 9;
  ZMQ_XSUB = 10;
  ZMQ_STREAM = 11;

  ZMQ_SNDMORE = 2;
  ZMQ_RCVMORE = 13;
  ZMQ_LINGER = 17;
  ZMQ_SNDHWM = 23;
  ZMQ_RCVHWM = 24;
  ZMQ_IPV6 = 42;
  ZMQ_CURVE_SERVER = 47;
  ZMQ_CURVE_PUBLICKEY = 48;
  ZMQ_CURVE_SECRETKEY = 49;
  ZMQ_CURVE_SERVERKEY = 50;

  ZMQ_POLLIN  = 1;
  ZMQ_POLLOUT = 2;

type
  zmq_msg_t = record
    opaque: array[0..63] of Byte;
  end;
  pzmq_msg_t = ^zmq_msg_t;

  zmq_pollitem_t = record
    socket: Pointer;
    {$IFDEF MSWINDOWS}
    fd: NativeInt;
    {$ELSE}
    fd: Integer;
    {$ENDIF}
    events: SmallInt;
    revents: SmallInt;
  end;
  pzmq_pollitem_t = ^zmq_pollitem_t;

{$IFDEF STATIC_BINDING}
  { ZeroMQ contexts }
  function zmq_ctx_new(): Pointer; cdecl; external ZMQ_LIB name _PU + 'zmq_ctx_new'
    {$IF Defined(CPUARM)}
      {$IF Defined(IOS)}
      dependency 'c++'
      {$ELSEIF Defined(ANDROID)}
      dependency 'gnustl_static'
      {$ENDIF}
    {$ENDIF};

  function zmq_ctx_term(context: Pointer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_ctx_term';

  { ZeroMQ messages }
  function zmq_msg_init(msg: pzmq_msg_t): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_init';
  function zmq_msg_init_size(msg: pzmq_msg_t; size: NativeUInt): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_init_size';
  function zmq_msg_send(msg: pzmq_msg_t; socket: Pointer; flags: Integer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_send';
  function zmq_msg_recv(msg: pzmq_msg_t; socket: Pointer; flags: Integer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_recv';
  function zmq_msg_close(msg: pzmq_msg_t): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_close';
  function zmq_msg_data(msg: pzmq_msg_t): Pointer; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_data';
  function zmq_msg_size(msg: pzmq_msg_t): NativeUInt; cdecl; external ZMQ_LIB name _PU + 'zmq_msg_size';

  { ZeroMQ sockets }
  function zmq_socket(context: Pointer; _type: Integer): Pointer; cdecl; external ZMQ_LIB name _PU + 'zmq_socket';
  function zmq_close(socket: Pointer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_close';
  function zmq_setsockopt(socket: Pointer; option_name: Integer; const option_value: Pointer; option_len: NativeUInt): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_setsockopt';
  function zmq_getsockopt (socket: Pointer; option_name: Integer; option_value: Pointer; option_len: PNativeUInt): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_getsockopt';
  function zmq_bind(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_bind';
  function zmq_connect(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_connect';
  function zmq_unbind(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_unbind';
  function zmq_disconnect(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_disconnect';
  function zmq_sendmsg(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_sendmsg';
  function zmq_recvmsg(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_recvmsg';

  { ZeroMQ polling }
  function zmq_poll(items: pzmq_pollitem_t; nitems: Integer; timeout: {$IFDEF POSIX}NativeInt{$ELSE}Integer{$ENDIF}): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_poll';

  { ZeroMQ Curve security }
  function zmq_z85_decode(dest: PByte; str: MarshaledAString): PByte; cdecl; external ZMQ_LIB name _PU + 'zmq_z85_decode';
  function zmq_curve_keypair(z85_public_key, z85_secret_key: MarshaledAString): Integer; cdecl; external ZMQ_LIB name _PU + 'zmq_curve_keypair';
{$ENDIF}

{$IFDEF DYNAMIC_BINDING}
var
  { ZeroMQ contexts }
  zmq_ctx_new: function: Pointer; cdecl = nil;
  zmq_ctx_term: function(context: Pointer): Integer; cdecl = nil;

  { ZeroMQ messages }
  zmq_msg_init: function(msg: pzmq_msg_t): Integer; cdecl = nil;
  zmq_msg_init_size: function(msg: pzmq_msg_t; size: NativeUInt): Integer; cdecl = nil;
  zmq_msg_send: procedure(msg: pzmq_msg_t; socket: Pointer; flags: Integer); cdecl = nil;
  zmq_msg_recv: procedure(msg: pzmq_msg_t; socket: Pointer; flags: Integer); cdecl = nil;
  zmq_msg_close: function(msg: pzmq_msg_t): Integer; cdecl = nil;
  zmq_msg_data: function(msg: pzmq_msg_t): Pointer; cdecl = nil;
  zmq_msg_size: function(msg: pzmq_msg_t): NativeUInt; cdecl = nil;

  { ZeroMQ sockets }
  zmq_socket: function(context: Pointer; _type: Integer): Pointer; cdecl = nil;
  zmq_close: function(socket: Pointer): Integer; cdecl = nil;
  zmq_setsockopt: function(socket: Pointer; option_name: Integer; const option_value: Pointer; option_len: NativeUInt): Integer; cdecl = nil;
  zmq_getsockopt: function(socket: Pointer; option_name: Integer; option_value: Pointer; option_len: PNativeUInt): Integer; cdecl = nil;
  zmq_bind: function(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl = nil;
  zmq_connect: function(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl = nil;
  zmq_unbind: function(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl = nil;
  zmq_disconnect: function(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl = nil;
  zmq_sendmsg: function(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl = nil;
  zmq_recvmsg: function(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl = nil;

  { ZeroMQ polling }
  zmq_poll: function(items: pzmq_pollitem_t; nitems: Integer; timeout: {$IFDEF POSIX}NativeInt{$ELSE}Integer{$ENDIF}): Integer; cdecl = nil;

  { ZeroMQ Curve security }
  zmq_z85_decode: function(dest: PByte; str: MarshaledAString): PByte; cdecl = nil;
  zmq_curve_keypair: function(z85_public_key, z85_secret_key: MarshaledAString): Integer; cdecl = nil;
{$ENDIF}

implementation

uses
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  System.SysUtils;

{$IFDEF DYNAMIC_BINDING}
var
  ZeroMQHandle: HMODULE;

{ Library }

function LoadLib(const ALibFile: String): HMODULE;
begin
  Result := LoadLibrary(PChar(ALibFile));
  if (Result = 0) then
    raise Exception.CreateFmt('load %s failed', [ALibFile]);
end;

function FreeLib(ALibModule: HMODULE): Boolean;
begin
  Result := FreeLibrary(ALibModule);
end;

function GetProc(AModule: HMODULE; const AProcName: String): Pointer;
begin
  {$IFDEF MACOS}
  Result := GetProcAddress(AModule, PChar('_' + AProcName));
  {$ELSE}
  Result := GetProcAddress(AModule, PChar(AProcName));
  {$ENDIF}
  if (Result = nil) then
    raise Exception.CreateFmt('%s is not found', [AProcName]);
end;

procedure LoadZeroMQ;
begin
  if (ZeroMQHandle <> 0) then Exit;
  ZeroMQHandle := LoadLib(ZMQ_LIB);
  if (ZeroMQHandle = 0) then
  begin
    raise Exception.CreateFmt('Load %s failed', [ZMQ_LIB]);
    Exit;
  end;

  { ZeroMQ contexts }
  zmq_ctx_new := GetProc(ZeroMQHandle, 'zmq_ctx_new');
  zmq_ctx_term := GetProc(ZeroMQHandle, 'zmq_ctx_term');

  { ZeroMQ messages }
  zmq_msg_init := GetProc(ZeroMQHandle, 'zmq_msg_init');
  zmq_msg_init_size := GetProc(ZeroMQHandle, 'zmq_msg_init_size');
  zmq_msg_send := GetProc(ZeroMQHandle, 'zmq_msg_send');
  zmq_msg_recv := GetProc(ZeroMQHandle, 'zmq_msg_recv');
  zmq_msg_close := GetProc(ZeroMQHandle, 'zmq_msg_close');
  zmq_msg_data := GetProc(ZeroMQHandle, 'zmq_msg_data');
  zmq_msg_size := GetProc(ZeroMQHandle, 'zmq_msg_size');

  { ZeroMQ sockets }
  zmq_socket := GetProc(ZeroMQHandle, 'zmq_socket');
  zmq_close := GetProc(ZeroMQHandle, 'zmq_close');
  zmq_setsockopt := GetProc(ZeroMQHandle, 'zmq_setsockopt');
  zmq_getsockopt := GetProc(ZeroMQHandle, 'zmq_getsockopt');
  zmq_bind := GetProc(ZeroMQHandle, 'zmq_bind');
  zmq_connect := GetProc(ZeroMQHandle, 'zmq_connect');
  zmq_unbind := GetProc(ZeroMQHandle, 'zmq_unbind');
  zmq_disconnect := GetProc(ZeroMQHandle, 'zmq_disconnect');
  zmq_sendmsg := GetProc(ZeroMQHandle, 'zmq_sendmsg');
  zmq_recvmsg := GetProc(ZeroMQHandle, 'zmq_recvmsg');

  { ZeroMQ polling }
  zmq_poll := GetProc(ZeroMQHandle, 'zmq_poll');

  { ZeroMQ Curve security }
  zmq_z85_decode := GetProc(ZeroMQHandle, 'zmq_z85_decode');
  zmq_curve_keypair := GetProc(ZeroMQHandle, 'zmq_curve_keypair');
end;

procedure UnloadZeroMQ;
begin
  if (ZeroMQHandle = 0) then Exit;
  FreeLib(ZeroMQHandle);
  ZeroMQHandle := 0;
end;

initialization
  LoadZeroMQ;

finalization
  UnloadZeroMQ;
{$ENDIF}

end.
