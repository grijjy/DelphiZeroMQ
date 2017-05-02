unit ZMQ.API;
{ Interface unit for cross-platform ZeroMQ libaries }

interface

const
  {$IF Defined(MSWINDOWS)}
  ZMQ_LIB = 'libzmq.dll';
  {$ELSEIF Defined(LINUX)}
  ZMQ_LIB = 'libzmq.so';
  {$ELSEIF Defined(IOS)}
  ZMQ_LIB = 'libzmq.a';
  {$ELSEIF Defined(ANDROID)}
  ZMQ_LIB = 'libzmq.a';
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

  { ZeroMQ contexts }
  function zmq_ctx_new(): Pointer; cdecl; external ZMQ_LIB name 'zmq_ctx_new'
    {$IF Defined(CPUARM)}
      {$IF Defined(IOS)}
      dependency 'c++' dependency 'sodium'
      {$ELSEIF Defined(ANDROID)}
      dependency 'gnustl_static' dependency 'sodium'
      {$ENDIF}
    {$ENDIF};

  function zmq_ctx_term(context: Pointer): Integer; cdecl; external ZMQ_LIB name 'zmq_ctx_term';

  { ZeroMQ messages }
  function zmq_msg_init(msg: pzmq_msg_t): Integer; cdecl; external ZMQ_LIB name 'zmq_msg_init';
  function zmq_msg_init_size(msg: pzmq_msg_t; size: NativeUInt): Integer; cdecl; external ZMQ_LIB name 'zmq_msg_init_size';
  function zmq_msg_send(msg: pzmq_msg_t; socket: Pointer; flags: Integer): Integer; cdecl; external ZMQ_LIB name 'zmq_msg_send';
  function zmq_msg_recv(msg: pzmq_msg_t; socket: Pointer; flags: Integer): Integer; cdecl; external ZMQ_LIB name 'zmq_msg_recv';
  function zmq_msg_close(msg: pzmq_msg_t): Integer; cdecl; external ZMQ_LIB name 'zmq_msg_close';
  function zmq_msg_data(msg: pzmq_msg_t): Pointer; cdecl; external ZMQ_LIB name 'zmq_msg_data';
  function zmq_msg_size(msg: pzmq_msg_t): NativeUInt; cdecl; external ZMQ_LIB name 'zmq_msg_size';

  { ZeroMQ sockets }
  function zmq_socket(context: Pointer; _type: Integer): Pointer; cdecl; external ZMQ_LIB name 'zmq_socket';
  function zmq_close(socket: Pointer): Integer; cdecl; external ZMQ_LIB name 'zmq_close';
  function zmq_setsockopt(socket: Pointer; option_name: Integer; const option_value: Pointer; option_len: NativeUInt): Integer; cdecl; external ZMQ_LIB name 'zmq_setsockopt';
  function zmq_getsockopt (socket: Pointer; option_name: Integer; option_value: Pointer; option_len: PNativeUInt): Integer; cdecl; external ZMQ_LIB name 'zmq_getsockopt';
  function zmq_bind(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name 'zmq_bind';
  function zmq_connect(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name 'zmq_connect';
  function zmq_unbind(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name 'zmq_unbind';
  function zmq_disconnect(socket: Pointer; const endpoint: MarshaledAString): Integer; cdecl; external ZMQ_LIB name 'zmq_disconnect';
  function zmq_sendmsg(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl; external ZMQ_LIB name 'zmq_sendmsg';
  function zmq_recvmsg(socket: Pointer; msg: pzmq_msg_t; flags: Integer): Integer; cdecl; external ZMQ_LIB name 'zmq_recvmsg';

  { ZeroMQ polling }
  function zmq_poll(items: pzmq_pollitem_t; nitems: Integer; timeout: {$IFDEF POSIX}NativeInt{$ELSE}Integer{$ENDIF}): Integer; cdecl; external ZMQ_LIB name 'zmq_poll';

  { ZeroMQ Curve security }
  function zmq_z85_decode(dest: PByte; str: MarshaledAString): PByte; cdecl; external ZMQ_LIB name 'zmq_z85_decode';
  function zmq_curve_keypair(z85_public_key, z85_secret_key: MarshaledAString): Integer; cdecl; external ZMQ_LIB name 'zmq_curve_keypair';

implementation

end.