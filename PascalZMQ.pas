unit PascalZMQ;
{ Pascal version of the various CZMQ helpers }

{ Converting from ZMQ/CZMQ to PascalZMQ:

  ZMQ/CZMQ        -->         PascalZMQ
  -------------------------------------
  zctx_new                    TZContext.Create
  zctx_destroy                TZContext.Free

  zframe_new                  TZFrame.Initialize
  zframe_destroy              TZFrame.Free
  zframe_dup                  TZFrame.Clone
  zframe_size                 TZFrame.Size
  zframe_data                 TZFrame.Data
                              TZFrame.ToBytes
  zframe_eq                   TZFrame.Equals
  zframe_strhex               TZFrame.ToHexString

  zmsg_new                    TZMessage.Create
  zmsg_destroy                TZMessage.Free
  zmsg_dup                    TZMessage.Clone
  zmsg_size                   TZMessage.FrameCount
  zmsg_first                  TZMessage.First
                              TZMessage.Frames[0]
  zmsg_next                   TZMessage.Next
                              TZMessage.Frames[I]
  zmsg_prepend                TZMessage.Push
  (new)                       TZMessage.PushEmptyFrame
  zmsg_pushmem                TZMessage.PushInteger
                              TZMessage.PushSingle
                              TZMessage.PushDouble
                              TZMessage.PushEnum
                              TZMessage.PushString
                              TZMessage.PushBytes
                              TZMessage.PushProtocolBuffer
  zmsg_pop                    TZMessage.Pop
                              TZMessage.PopInteger
                              TZMessage.PopSingle
                              TZMessage.PopDouble
                              TZMessage.PopEnum
                              TZMessage.PopString
                              TZMessage.PopBytes
                              TZMessage.PopProtocolBuffer
  (new)                       TZMessage.Peek
                              TZMessage.PeekInteger
                              TZMessage.PeekSingle
                              TZMessage.PeekDouble
                              TZMessage.PeekEnum
                              TZMessage.PeekString
                              TZMessage.PeekBytes
                              TZMessage.PeekProtocolBuffer
  zmsg_unwrap                 TZMessage.Unwrap
  zmsg_send                   TZSocket.Send
  zmsg_receive                TZSocket.Receive

  zsocket_new                 TZSocket.Create
  zsocket_destroy             TZSocket.Free
  zsocket_bind                TZSocket.Bind
  zsocket_connect/zmq_connect TZSocket.Connect
  zmq_disconnect              TZSocket.Disconnect
  zmq_poll                    TZSocket.Poll
  zsocket_set_linger          TZSocket.Linger
  zsocket_set_curve_server    TZSocket.IsCurveServer
  zsocket_set_curve_serverkey TZSocket.CurveServerKey

  zcert_new                   TZCertificate.Create()
  zcert_load                  TZCertificate.Create(Filename)
  zcert_destroy               TZCertificate.Free
  zcert_save                  TZCertificate.Save
  zcert_apply                 TZCertificate.Apply
}

{$INCLUDE 'Grijjy.inc'}

interface

uses
  System.Types,
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  ZMQ.API;

type
  { Exception class for ZMQ errors }
  EZMQError = class(Exception);

type
  { Types of sockets }
  TZSocketType = (
    Pair   = ZMQ_PAIR,
    Pub    = ZMQ_PUB,
    Sub    = ZMQ_SUB,
    Req    = ZMQ_REQ,
    Rep    = ZMQ_REP,
    Dealer = ZMQ_DEALER,
    Router = ZMQ_ROUTER,
    Pull   = ZMQ_PULL,
    Push   = ZMQ_PUSH,
    XPub   = ZMQ_XPUB,
    XSub   = ZMQ_XSUB,
    Stream = ZMQ_STREAM);

type
  { Poll events }
  TZSocketPoll = (
    Input  = ZMQ_POLLIN,
    Output = ZMQ_POLLOUT);

type
  { Poll results }
  TZSocketPollResult = (Available, Timeout, Interrupted);

type
  { Type of public and secret keys for CURVE certificates }
  TZCurveKey = array [0..31] of Byte;

type
  { ZMQ context.
    Modeled after CZMQ zctx: wraps a ZMQ context and manages its sockets }
  TZContext = class(TObject)
  {$REGION 'Internal Declarations'}
  private const
    { TODO : Make these configurable? }
    SND_HWM  = 10000; { High Water Mark for outbound messages. 0=unlimited }
    RCV_HWM  = 10000; { High Water Mark for inbound messages. 0=unlimited }
    LINGER   = 0;
  private
    FContext: Pointer;
    FLock: TCriticalSection;
    FSockets: TList<Pointer>;
    FIsShadow: Boolean;
  private
    procedure CreateContext;
    function CreateSocket(const AType: TZSocketType): Pointer;
    procedure FreeSocket(const ASocket: Pointer);
  {$ENDREGION 'Internal Declarations'}
  public
    { Create a new context }
    constructor Create;

    { Free the context }
    destructor Destroy; override;

    { Creates a new shadow context based on this context }
    function Shadow: TZContext;
  end;

type
  PZFrame = ^TZFrame;

  { A single message frame in a multi-part TZMessage. }
  TZFrame = record
  {$REGION 'Internal Declarations'}
  private
    FMsg: zmq_msg_t;
    function GetSize: Integer; inline;
    function GetData: Pointer; inline;
  private
    function Send(const ASocketHandle: Pointer; const AMoreFollows: Boolean): Boolean;
    function Receive(const ASocketHandle: Pointer): Boolean; inline;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates an empty frame. }
    class function Create: PZFrame; overload; static;

    { Creates a frame with existing data.

      Parameters:
        AData: the data of the frame. The frame will create a copy of the data,
          so you can release the data afterwards.
        ASize: the data size for the frame. }
    class function Create(const AData; const ASize: Integer): PZFrame; overload; static;

    { Creates a frame with existing data.

      Parameters:
        AData: a byte array containing the data of the frame. The frame will
          create a copy of the data, so you can release the data afterwards. }
    class function Create(const AData: TBytes): PZFrame; overload; static; inline;

    { Destroys the frame (and any data it holds). Frames automatically get
      destroyed when you send them (see TZSocket.Send). }
    procedure Free;

    { Creates a copy of the frame.

      Returns:
        A newly allocated copy of the frame. You are responsible for freeing
        it by either calling Free explicitly or sending the copy. }
    function Clone: PZFrame;

    { Returns True if two frames have identical size and data }
    function Equals(const AOther: PZFrame): Boolean;

    { Copies the data in the frame to an array of bytes.

      Returns:
        A byte array with the copy of the data in the frame. }
    function ToBytes: TBytes;

    { Return the data encoded as a printable hex string. Useful for ZeroMQ
      UUIDs. }
    function ToHexString: String;

    { Returns the contents of the frame as a 4-byte integer value.

      Raises an exception if the frame does not contain a 4-byte value. }
    function AsInteger: Integer;

    { Returns the contents of the frame as a 4-byte single-precision
      floating-point value.

      Raises an exception if the frame does not contain a 4-byte value. }
    function AsSingle: Single;

    { Returns the contents of the frame as a 8-byte double-precision
      floating-point value.

      Raises an exception if the frame does not contain a 8-byte value. }
    function AsDouble: Double;

    { Returns the contents of the frame as a UTF-8 decoded Unicode string.

      Raises an exception if the frame does not contain valid UTF-8 data. }
    function AsString: String;

    { The size of the frame in bytes }
    property Size: Integer read GetSize;

    { Pointer to the data in the frame }
    property Data: Pointer read GetData;
  end;

type
  PZMessage = ^TZMessage;

  { A multi-part message. }
  TZMessage = record
  {$REGION 'Internal Declarations'}
  private const
    { Maximum number of frames that can be stored inside a message without
      having to dynamically allocate a list. Once this limit has been reached,
      we switch to a dynamic list. The vast majority of message will be below
      this limit, which gives a performance boost. The maximum number of frames
      in any message used by the unit tests is 8. }
    STATIC_FRAME_COUNT = 8;
  private type
    PPZFrame = ^PZFrame;
  private
    FStaticFrames: array [0..STATIC_FRAME_COUNT - 1] of PZFrame;
    FFrames: PPZFrame; { Points to either FStaticFrames, or is dynamically allocated }
    FCapacity: Integer;
    FCount: Integer;
    FCursor: Integer;
  private
    function GetFrame(const AIndex: Integer): PZFrame; inline;
  private
    function Send(const ASocketHandle: Pointer; const ASocketType: TZSocketType): Boolean;
    function Receive(const ASocketHandle: Pointer; const ASocketType: TZSocketType): Boolean;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a new empty message }
    class function Create: PZMessage; static;

    { Destroys the message (and any frames it owns). Messages automatically get
      destroyed when you send them (see TZSocket.Send). }
    procedure Free;

    { Creates a copy of the message.

      Returns:
        A newly allocated copy of the message. You are responsible for freeing
        it by either calling Free explicitly or sending the copy. }
    function Clone: PZMessage;

    { Returns the first frame in the message, or nil if there are no frames.
      Use in combination with Next to walk the frames in the message. }
    function First: PZFrame;

    { Returns the next frame in the message, or nil if there are no frames left.
      Use in combination with First to walk the frames in the message. }
    function Next: PZFrame;
  public
    { Pushing frames }

    { Pushes a frame to the @bold(front) of the message. The message becomes
      owner of the frame and will destroy it when the message is sent or
      destroyed.

      Parameters:
        AFrame: the frame to push onto the message. Cannot be nil.

      AFrame will be set to nil after this call }
    procedure Push(var AFrame: PZFrame);

    { Pushes an empty frame to the @bold(front) of the message. The message
      becomes owner of the frame and will destroy it when the message is sent or
      destroyed. Empty frames are used as delimiters by some topologies. }
    procedure PushEmptyFrame;

    { Pushes a new frame to the @bold(front) of the message, with a 4-byte
      integer value.

      Parameters:
        AValue: the value to push. }
    procedure PushInteger(const AValue: Integer); inline;

    { Pushes a new frame to the @bold(front) of the message, with a 4-byte
      single-precision floating-point value.

      Parameters:
        AValue: the value to push. }
    procedure PushSingle(const AValue: Single); inline;

    { Pushes a new frame to the @bold(front) of the message, with a 8-byte
      double-precision floating-point value.

      Parameters:
        AValue: the value to push. }
    procedure PushDouble(const AValue: Double); inline;

    { Pushes a new frame to the @bold(front) of the message, with an
      enumerated value.

      Parameters:
        AValue: the value to push. }
    procedure PushEnum<T: record>(const AValue: T); overload; inline;

    { Pushes a new frame to the @bold(front) of the message, with an
      enumerated value.

      Parameters:
        AEnumValue: the ordinal value of the enum to push. Use Ord() for this.
        AEnumSize: the size of the enumeration type. Use SizeOf() for this. }
    procedure PushEnum(const AEnumValue, AEnumSize: Integer); overload; inline;

    { Pushes a new frame to the @bold(front) of the message, with a Unicode
      string value. The string will be encoded in UTF-8 format.

      Parameters:
        AValue: the value to push. }
    procedure PushString(const AValue: String);

    { Pushes a new frame to the @bold(front) of the message, with a byte array.

      Parameters:
        AValue: the value to push. }
    procedure PushBytes(const AValue: TBytes); inline;

    { Pushes a new frame to the @bold(front) of the message, with a given
      memory buffer.

      Parameters:
        AValue: the memory buffer to push.
        ASize: the size of the memory buffer }
    procedure PushMemory(const AValue; const ASize: Integer); inline;

    { Pushes a new frame to the @bold(front) of the message, with a record in
      Google Protocol Buffer format. The record type must be attributed/
      registered for use with protocol buffers.

      Parameters:
        AValue: the value to push. }
    procedure PushProtocolBuffer<T: record>(const AValue: T); overload;
    procedure PushProtocolBuffer(const ARecordType: Pointer; const AValue); overload;
  public
    { Popping frames }

    { Pops a frame of the @bold(front) of the message. The caller owns the frame
      now and must destroy it when finished with it.

      Returns:
        The popped frame or nil if there are no frames left to pop. }
    function Pop: PZFrame;

    { Pops a frame of the @bold(front) of the message and converts it to a
      4-byte integer value. The popped frame will be destroyed.

      Returns:
        The integer value of the frame, or 0 if there are no frames left to pop.

      Raises an exception if the frame does not contain a 4-byte value. }
    function PopInteger: Integer;

    { Pops a frame of the @bold(front) of the message and converts it to a
      4-byte single-precision floating-point value. The popped frame will be
      destroyed.

      Returns:
        The floating-point value of the frame, or 0 if there are no frames left
        to pop.

      Raises an exception if the frame does not contain a 4-byte value. }
    function PopSingle: Single;

    { Pops a frame of the @bold(front) of the message and converts it to a
      8-byte double-precision floating-point value. The popped frame will be
      destroyed.

      Returns:
        The floating-point value of the frame, or 0 if there are no frames left
        to pop.

      Raises an exception if the frame does not contain a 8-byte value. }
    function PopDouble: Double;

    { Pops a frame of the @bold(front) of the message and converts it to an
      enumerated value. The popped frame will be destroyed.

      Returns:
        The enum value of the frame, or the enum with ordinal value 0 if there
        are no frames left to pop.

      Raises an exception if the frame does not contain a value the size of T. }
    function PopEnum<T: record>: T; overload;

    { Pops a frame of the @bold(front) of the message and converts it to an
      enumerated value. The popped frame will be destroyed.

      Parameters:
        AEnumSize: the size of the enumeration type. Use SizeOf() for this.

      Returns:
        The ordinal enum value of the frame, or 0 if there are no frames left.

      Raises an exception if the frame does not contain a value the size of
      AEnumSize. }
    function PopEnum(const AEnumSize: Integer): Integer; overload;

    { Pops a frame of the @bold(front) of the message and UTF-8 decodes it to a
      Unicode string. The popped frame will be destroyed.

      Returns:
        The string value of the frame, or an empty string if there are no frames
        left to pop.

      Raises an exception if the frame does not contain valid UTF-8 data. }
    function PopString: String;

    { Pops a frame of the @bold(front) of the message and returns its data as a
      byte array. The popped frame will be destroyed.

      Returns:
        A byte array with the data of the frame, or nil if there are no frames
        left to pop. }
    function PopBytes: TBytes;

    { Pops a frame of the @bold(front) of the message and deserializes it into a
      record in Google Protocol Buffer format. The record type must be
      attributed/registered for use with protocol buffers. The popped frame will
      be destroyed.

      Parameters:
        AValue: is filled with the deserialized protocol buffer.

      Returns:
        False if there were no frames left to pop, or True otherwise.

      Raises an exception if the data in the frame is not in valid protocol
      buffer format }
    function PopProtocolBuffer<T: record>(out AValue: T): Boolean; overload;
    function PopProtocolBuffer(const ARecordType: Pointer; out AValue): Boolean; overload;
  public
    { Peeking frames }

    { Peeks at the frame at the @bold(front) of the message. It will @bold(not)
      be removed from the message, and the message still owns it. So you should
      @bold(not) free the returned frame.

      Returns:
        The peeked frame or nil if there are no frames left. }
    function Peek: PZFrame; inline;

    { Peeks at the frame at the @bold(front) of the message and converts it to a
      4-byte integer value. The frame will @bold(not) be removed from the
      message.

      Returns:
        The integer value of the frame, or 0 if there are no frames left.

      Raises an exception if the frame does not contain a 4-byte value. }
    function PeekInteger: Integer;

    { Peeks at the frame at the @bold(front) of the message and converts it to a
      4-byte single-precision floating-point value. The frame will @bold(not) be
      removed from the message.

      Returns:
        The floating-point value of the frame, or 0 if there are no frames left.

      Raises an exception if the frame does not contain a 4-byte value. }
    function PeekSingle: Single;

    { Peeks at the frame at the @bold(front) of the message and converts it to a
      8-byte double-precision floating-point value. The frame will @bold(not) be
      removed from the message.

      Returns:
        The floating-point value of the frame, or 0 if there are no frames left
        to pop.

      Raises an exception if the frame does not contain a 8-byte value. }
    function PeekDouble: Double;

    { Peeks at the frame at the @bold(front) of the message and converts it to
      an enumerated value. The frame will @bold(not) be removed from the
      message.

      Returns:
        The enum value of the frame, or the enum with ordinal value 0 if there
        are no frames left.

      Raises an exception if the frame does not contain a value the size of T. }
    function PeekEnum<T: record>: T; overload;

    { Peeks at the frame at the @bold(front) of the message and converts it to
      an enumerated value. The frame will @bold(not) be removed from the
      message.

      Parameters:
        AEnumSize: the size of the enumeration type. Use SizeOf() for this.

      Returns:
        The ordinal enum value of the frame, or 0 if there are no frames left.

      Raises an exception if the frame does not contain a value the size of
      AEnumSize. }
    function PeekEnum(const AEnumSize: Integer): Integer; overload;

    { Peeks at the frame at the @bold(front) of the message and UTF-8 decodes it
      to a Unicode string. The frame will @bold(not) be removed from the
      message.

      Returns:
        The string value of the frame, or an empty string if there are no frames
        left.

      Raises an exception if the frame does not contain valid UTF-8 data. }
    function PeekString: String;

    { Peeks at the frame at the @bold(front) of the message and returns its data
      as a byte array. The frame will @bold(not) be removed from the message.

      Returns:
        A byte array with the data of the frame, or nil if there are no frames
        left. }
    function PeekBytes: TBytes;

    { Peeks at the frame at the @bold(front) of the message and deserializes it
      into a record in Google Protocol Buffer format. The record type must be
      attributed/registered for use with protocol buffers. The frame will
      @bold(not) be removed from the message.

      Parameters:
        AValue: is filled with the deserialized protocol buffer.

      Returns:
        False if there were no frames left, or True otherwise.

      Raises an exception if the data in the frame is not in valid protocol
      buffer format }
    function PeekProtocolBuffer<T: record>(out AValue: T): Boolean; overload;
    function PeekProtocolBuffer(const ARecordType: Pointer; out AValue): Boolean; overload;
  public
    { Misc }

    { Pops a frame of the @bold(front) of the message. The caller owns the frame
      now and must destroy it when finished with it.

      If the next frame is empty, then that frame is popped and destroyed.

      Returns:
        The top frame or nil if there are no frames. }
    function Unwrap: PZFrame;
  public
    { Properties }

    { The number of frames in the message }
    property FrameCount: Integer read FCount;

    { The frames in the message.

      Parameters:
        AIndex: the index of the frame to return. Use 0 for the first frame
          at the front of the message. No range checking is performed on the
          index. }
    property Frames[const AIndex: Integer]: PZFrame read GetFrame;
  end;

type
  { Ultra-thin (record) wrapper around ZMQ socket.
    Modeled after CZMQ socket }
  TZSocket = record
  {$REGION 'Internal Declarations'}
  private const
    DYN_PORT_START = $C000;
    DYN_PORT_END   = $FFFF;
  private
    FHandle: Pointer;
    FSocketType: TZSocketType;
    function GetLinger: Integer;
    procedure SetLinger(const Value: Integer);
    function GetIsCurveServer: Boolean;
    procedure SetIsCurveServer(const Value: Boolean);
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a socket.

      Parameters:
        AContext: the context to use to create the socket. Cannot be nil.
        AType: the type of socket to create.

      Raises an exception if the socket could not be created. }
    constructor Create(const AContext: TZContext; const AType: TZSocketType);

    { Destroys the socket.

      Parameters:
        AContext: the context to use to destroy the socket. Cannot be nil. }
    procedure Free(const AContext: TZContext); inline;

    { Binds the socket to an endpoint. For tcp:// endpoints, supports ephemeral
      ports, if you specify the port number as "*". In that case, it uses the
      IANA designated range from C000 (49152) to FFFF (65535).

      Parameters:
        AEndpoint: the endpoint to bind to.

      Examples:
      * tcp://127.0.0.1:5500        bind to port 5500
      * tcp://127.0.0.1:*           bind to first free port from C000 to FFFF

      Returns:
        On success, returns the actual port number used, for tcp:// endpoints,
        and 0 for other transports. On failure, returns -1. Note that when using
        ephemeral ports, a port may be reused by different services without
        clients being aware. Protocols that run on ephemeral ports should take
        this into account. }
    function Bind(const AEndpoint: String): Integer;

    { Unbinds a socket from an endpoint.

      Parameters:
        AEndpoint: the endpoint to unbind from.

      Returns:
        True on success, False on failure. }
    function Unbind(const AEndpoint: String): Boolean;

    { Connects the socket to an endpoint.

      Parameters:
        AEndpoint: the endpoint to connect to.

      Returns:
        True on success, False on error. }
    function Connect(const AEndpoint: String): Boolean;

    { Disconnects the socket from an endpoint.

      Parameters:
        AEndpoint: the endpoint to disconnect from.

      Returns:
        True on success, False on error. }
    function Disconnect(const AEndpoint: String): Boolean;

    { Polls the socket for input or output.

      Parameters:
        AEvent: the event to poll:
          * TZSocketPoll.Input: when the function returns
              TZSocketPollResult.Available, then at least one  message may be
              received from the socket without blocking.
          * TZSocketPoll.Output: when the function returns
              TZSocketPollResult.Available, then at least one message may be
              sent to the socket without blocking.
        ATimeout: the number of microseconds to wait for the event to occur. Set
          to 0 to return immediately. Set to -1 to wait indefinitely.

      Returns:
        * TZSocketPollResult.Available: the event has occurred within the
            timeout, and you can receive or send a message without blocking.
        * TZSocketPollResult.Timeout: the event did not occur within the timeout.
        * TZSocketPollResult.Interrupted: the operation was interrupted by
            delivery of a signal before any events were available. }
    function Poll(const AEvent: TZSocketPoll; const ATimeout: Integer): TZSocketPollResult;

    { Sends a message and frees it at some point.

      Parameters:
        AMessage: the message to send. Cannot be nil. Will be set to nil
          afterwards.

      Returns:
        True on success, False on error or when the message has no frames.

      The message may not be send immediately, but be queued. After it has been
      send, it will be destroyed automatically, so there is no need to call
      AMessage.Free. }
    function Send(var AMessage: PZMessage): Boolean;

    { Receives a message from a socket. This is a blocking operation.

      Parameters:
        ASocket: the socket used to receive the message.

      Returns:
        The received message or nil if an error occured (eg. the operation was
        interrupted).

      @bold(Note): this function returns a newly allocated message.
      You @bold(must) free it when you are done with it. }
    function Receive: PZMessage;

    { Linger timeout. Number of msecs to flush when closing socket. }
    property Linger: Integer read GetLinger write SetLinger;

    { Whether the socket will act as server for CURVE security. A value of True
      means the socket will act as CURVE server. A value of False means the
      socket will not act as CURVE server, and its security role then depends on
      other option settings. Setting this to False shall reset the socket
      security to nil. When you set this you must also set the server's secret
      key using CurveSecretKey. A server socket does not need to know its own
      public key. }
    property IsCurveServer: Boolean read GetIsCurveServer write SetIsCurveServer;

    { Sets the socket's long term public key. You must set this on CURVE client
      sockets. You provide the key as a 40-character string encoded in the Z85
      encoding format. The public key must always be used with the matching
      secret key.

      Parameters:
        AKey: the public key to set }
    procedure SetCurvePublicKey(const AKey: String); overload;

    { Sets the socket's long term public key. You must set this on CURVE client
      sockets. You provide the key as a 32-byte binary key. The public key must
      always be used with the matching secret key.

      Parameters:
        AKey: the public key to set }
    procedure SetCurvePublicKey(const AKey: TZCurveKey); overload;

    { Sets the socket's long term secret key. You must set this on both CURVE
      client and server sockets. You provide the key as a 40-character string
      encoded in the Z85 encoding format.

      Parameters:
        AKey: the public key to set }
    procedure SetCurveSecretKey(const AKey: String); overload;

    { Sets the socket's long term secret key. You must set this on both CURVE
      client and server sockets. You provide the key as a 32-byte binary key.

      Parameters:
        AKey: the public key to set }
    procedure SetCurveSecretKey(const AKey: TZCurveKey); overload;

    { Sets the socket's long term server key. You must set this on CURVE client
      sockets. You provide the key as a 40-character string encoded in the Z85
      encoding format. This key must have been generated together with the
      server's secret key.

      Parameters:
        AKey: the public key to set }
    procedure SetCurveServerKey(const AKey: String); overload;

    { Sets the socket's long term server key. You must set this on CURVE client
      sockets. You provide the key as a 32-byte binary key. This key must have
      been generated together with the server's secret key.

      Parameters:
        AKey: the public key to set }
    procedure SetCurveServerKey(const AKey: TZCurveKey); overload;
  end;

type
  { Security certificates for the ZMQ CURVE mechanism }
  TZCertificate = class(TObject)
  {$REGION 'Internal Declarations'}
  private const
    FORTY_ZEROES = '0000000000000000000000000000000000000000';
  private
    FPublicKey: TZCurveKey;
    FSecretKey: TZCurveKey;
    FPublicTxt: String;
    FSecretTxt: String;
  {$ENDREGION 'Internal Declarations'}
  public
    { Creates a new certificate with a newly generated random keypair }
    constructor Create; overload;

    { Loads a certificate from a (JSON) file.

      Parameters:
        AFilename: the name of the file to load the certificate from.

      If there is both a "public" as a "secret" certificate file, then the
      "secret" file (with a "_secret" suffix) will be used. }
    constructor Create(const AFilename: String); overload;

    { Saves the certificate to a "public" and "secret" file.

      Parameters:
        AFilename: the name of the "public" file to save the certificate to.

      The "public" file will only store the public key. This method also creates
      a "secret" file (with a "_secret" suffix) with both the public and secret
      key. The "secret" file should not be provided to others. }
    procedure Save(const AFilename: String);

    { Applies the certificate to a socket, for use with CURVE security on the
      socket. If the certificate was loaded from a "public" file, then the
      secret key will be undefined, and this certificate will not work
      successfully.

      Parameters:
        ASocket: the socket to apply the certificate to }
    procedure Apply(const ASocket: TZSocket);

    { The public key of the certificate }
    property PublicKey: TZCurveKey read FPublicKey;

    { The secret key of the certificate }
    property SecretKey: TZCurveKey read FSecretKey;

    { The public key as a 40-character Z85-encoded string }
    property PublicTxt: String read FPublicTxt;

    { The secret key as a 40-character Z85-encoded string }
    property SecretTxt: String read FSecretTxt;
  end;

resourcestring
  RS_ZMQ_ERROR_CREATING_SOCKET = 'Error creating ZMQ socket.';
  RS_ZMQ_UNEXPECTED_FRAME = 'Unexpected frame in ZMQ message.';
  RS_ZMQ_CANNOT_LOAD_CERTIFICATE = 'Unable to load certificate from file %s.';

implementation

{$IF Defined(WIN32) and Defined(DEBUG)}
  {.$DEFINE CUSTOM_MALLOC}
{$ENDIF}

uses
  {$IFDEF CUSTOM_MALLOC}
  Winapi.Windows,
  Winapi.ImageHlp,
  {$ENDIF}
  Grijjy.Hash,
  Grijjy.ProtocolBuffers,
  Grijjy.Bson;

{$POINTERMATH ON}

{$IFDEF CUSTOM_MALLOC}
var
  Finalized: Boolean = False;

function HookedMalloc(Size: Integer): Pointer; cdecl;
begin
  GetMem(Result, Size);
end;

function HookedRealloc(MemBlock: Pointer; Size: Integer): Pointer; cdecl;
begin
  ReallocMem(MemBlock, Size);
  Result := MemBlock;
end;

procedure HookedFree(MemBlock: Pointer); cdecl;
begin
  if (not Finalized) then
    FreeMem(MemBlock);
end;

procedure ZMQInitializeDebugMode;
var
  Process: THandle;
  Module: HModule;
  OrigMalloc, OrigRealloc, OrigFree, NewProc: Pointer;
  Proc: PPointer;
  IAT: PImageImportDescriptor;
  Thunk: PImageThunkData;
  C, OldProtect: Cardinal;
  U: NativeUInt;
  P: PAnsiChar;
  S: String;
begin
  { ZMQ uses malloc, realloc and free for managing memory. In DEBUG mode on
    Windows, we want to use Delphi's memory manager (or FastMM) instead to debug
    memory issues. We do this by hooking these routines. We can do this because
    libzmq.dll uses msvcr120.dll for these routines. The import address table
    (IAT) of libzmq.dll has a section for each DLL it imports. We look for the
    imports of msvcr120.dll. We replace the table entries for malloc, realloc
    and free with our own versions. (We are only interested in malloc calls from
    inside libzmq.dll, so we don't patch any other import tables).

    First, we need to get the addresses of the original functions in
    msvcr120.dll so we can look them up in the import table of libzmq.dll. }
  Module := GetModuleHandle('msvcr120.dll');
  if (Module = 0) then
    Exit;

  OrigMalloc := GetProcAddress(Module, 'malloc');
  OrigRealloc := GetProcAddress(Module, 'realloc');
  OrigFree := GetProcAddress(Module, 'free');
  if (OrigMalloc = nil) or (OrigRealloc = nil) or (OrigFree = nil) then
    Exit;

  { Now, load the import address table of libzmq.dll }
  Module := GetModuleHandle('libzmq.dll');
  if (Module = 0) then
    Exit;

  IAT := ImageDirectoryEntryToData(Pointer(Module), True,
    IMAGE_DIRECTORY_ENTRY_IMPORT, C);
  if (IAT = nil) then
    Exit;

  Process := GetCurrentProcess;

  { Enumerate all modules in the IAT until we find msvcr120.dll }
  while (IAT.Name <> 0) do
  begin
    P := PAnsiChar(PByte(Module) + IAT.Name);
    S := String(AnsiString(P));
    if SameText(S, 'msvcr120.dll') then
    begin
      { Now enumerate all functions in the IAT until we find one of the
        functions we want to hook }
      Thunk := PImageThunkData(PByte(Module) + IAT.FirstThunk);
      while (Thunk._Function <> 0) do
      begin
        Proc := @Thunk._Function;
        if (Proc^ = OrigMalloc) then
        begin
          NewProc := @HookedMalloc;
          OrigMalloc := nil;
        end
        else if (Proc^ = OrigRealloc) then
        begin
          NewProc := @HookedRealloc;
          OrigRealloc := nil;
        end
        else if (Proc^ = OrigFree) then
        begin
          NewProc := @HookedFree;
          OrigFree := nil;
        end
        else
          NewProc := nil;

        { Hook the function }
        if Assigned(NewProc) then
        begin
          if (not WriteProcessMemory(Process, Proc, @NewProc, SizeOf(NewProc), U))
            and (GetLastError = ERROR_NOACCESS) then
          begin
            if (VirtualProtect(Proc, SizeOf(NewProc), PAGE_WRITECOPY, OldProtect)) then
            begin
              WriteProcessMemory(GetCurrentProcess, Proc, @NewProc, SizeOf(NewProc), U);
              VirtualProtect(Proc, SizeOf(NewProc), OldProtect, OldProtect);
            end;
          end;
        end;

        Inc(Thunk);
      end;

      Break;
    end;
    Inc(IAT);
  end;

  { All 3 functions should be hooked now, and the original functions should be
    set to nil }
  Assert((OrigMalloc = nil) and (OrigRealloc = nil) and (OrigFree = nil));
end;

procedure ZMQFinalizeDebugMode;
begin
  Finalized := True;
end;
{$ELSE}
procedure ZMQInitializeDebugMode;
begin
  { Nothing }
end;

procedure ZMQFinalizeDebugMode;
begin
  { Nothing }
end;
{$ENDIF}

{ TZContext }

constructor TZContext.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSockets := TList<Pointer>.Create;
end;

procedure TZContext.CreateContext;
begin
  FLock.Enter;
  try
    if (FContext = nil) then
      FContext := zmq_ctx_new;
  finally
    FLock.Leave;
  end;
end;

function TZContext.CreateSocket(const AType: TZSocketType): Pointer;
var
  Hwm: Integer;
begin
  if (FContext = nil) then
  begin
    CreateContext;
    if (FContext = nil) then
      Exit(nil);
  end;

  Result := zmq_socket(FContext, Ord(AType));
  if (Result = nil) then
    Exit;

  Hwm := SND_HWM;
  zmq_setsockopt(Result, ZMQ_SNDHWM, @Hwm, SizeOf(Hwm));

  Hwm := RCV_HWM;
  zmq_setsockopt(Result, ZMQ_RCVHWM, @Hwm, SizeOf(Hwm));

  {$IFNDEF ANDROID}
  { TODO : the ZMQ version we uses crashes on Android when IPv6 is enabled.
    Maybe the latest ZMQ version fixes this. }
  Hwm := 1; { Enable IPv6 }
  zmq_setsockopt(Result, ZMQ_IPV6, @Hwm, SizeOf(Hwm));
  {$ENDIF}

  FLock.Enter;
  try
    FSockets.Add(Result);
  finally
    FLock.Leave;
  end;
end;

destructor TZContext.Destroy;
var
  I: Integer;
begin
  if Assigned(FSockets) then
  begin
    for I := FSockets.Count - 1 downto 0 do
      FreeSocket(FSockets[I]);
  end;

  FSockets.Free;
  FLock.Free;

  if (FContext <> nil) and (not FIsShadow) then
    zmq_ctx_term(FContext);

  inherited;
end;

procedure TZContext.FreeSocket(const ASocket: Pointer);
var
  Linger: Integer;
begin
  Assert(Assigned(ASocket));
  Linger := TZContext.LINGER;
  zmq_setsockopt(ASocket, ZMQ_LINGER, @Linger, SizeOf(Linger));
  zmq_close(ASocket);

  FLock.Enter;
  try
    FSockets.Remove(ASocket);
  finally
    FLock.Leave;
  end;
end;

function TZContext.Shadow: TZContext;
begin
  if (FContext = nil) then
  begin
    CreateContext;
    if (FContext = nil) then
      Exit(nil);
  end;

  Result := TZContext.Create;
  Result.FContext := FContext;
  Result.FIsShadow := True;
end;

{ TZFrame }

function TZFrame.AsDouble: Double;
begin
  if (GetSize <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := PDouble(GetData)^;
end;

function TZFrame.AsInteger: Integer;
begin
  if (GetSize > SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := 0;
  Move(GetData^, Result, GetSize);
end;

function TZFrame.AsSingle: Single;
begin
  if (GetSize <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := PSingle(GetData)^;
end;

function TZFrame.AsString: String;
begin
  Result := TEncoding.UTF8.GetString(ToBytes);
end;

function TZFrame.Clone: PZFrame;
begin
  Result := TZFrame.Create(GetData^, GetSize);
end;

class function TZFrame.Create: PZFrame;
begin
  GetMem(Result, SizeOf(TZFrame) {$IFDEF TRACK_MEMORY}, '_PZFrame'{$ENDIF});
  FillChar(Result^, SizeOf(TZFrame), 0);
  zmq_msg_init(@Result.FMsg);
end;

class function TZFrame.Create(const AData; const ASize: Integer): PZFrame;
begin
  GetMem(Result, SizeOf(TZFrame) {$IFDEF TRACK_MEMORY}, '_PZFrame'{$ENDIF});
  FillChar(Result^, SizeOf(TZFrame), 0);
  if (ASize > 0) then
  begin
    zmq_msg_init_size(@Result.FMsg, ASize);
    move(AData, zmq_msg_data(@Result.FMsg)^, ASize);
  end
  else
    zmq_msg_init(@Result.FMsg);
end;

class function TZFrame.Create(const AData: TBytes): PZFrame;
begin
  Result := Create(AData[0], Length(AData));
end;

function TZFrame.Equals(const AOther: PZFrame): Boolean;
begin
  if (@Self = nil) or (AOther = nil) then
    Exit(False);

  if (Size <> AOther.Size) then
    Exit(False);

  Result := CompareMem(Data, AOther.Data, Size);
end;

procedure TZFrame.Free;
begin
  if (@Self <> nil) then
  begin
    zmq_msg_close(@FMsg);
    FreeMem(@Self {$IFDEF TRACK_MEMORY}, '_PZFrame'{$ENDIF});
  end;
end;

function TZFrame.GetData: Pointer;
begin
  Result := zmq_msg_data(@FMsg);
end;

function TZFrame.GetSize: Integer;
begin
  Result := zmq_msg_size(@FMsg);
end;

function TZFrame.Receive(const ASocketHandle: Pointer): Boolean;
begin
  Assert(Assigned(ASocketHandle));
  Result := (zmq_recvmsg(ASocketHandle, @FMsg, 0) >= 0);
end;

function TZFrame.Send(const ASocketHandle: Pointer;
  const AMoreFollows: Boolean): Boolean;
var
  Flags: Integer;
begin
  Assert(Assigned(ASocketHandle));
  if (AMoreFollows) then
    Flags := ZMQ_SNDMORE
  else
    Flags := 0;

  if (zmq_sendmsg(ASocketHandle, @FMsg, Flags) < 0) then
    Exit(False);

  { Sending the frame already destroyed it. However, we still need to free the
    memory used by the frame itself. }
  Free;
  Result := True;
end;

function TZFrame.ToBytes: TBytes;
var
  Size: Integer;
begin
  Size := GetSize;
  SetLength(Result, Size);
  if (Size > 0) then
    Move(GetData^, Result[0], Size);
end;

function TZFrame.ToHexString: String;
const
  HEX_CHARS: array [0..15] of Char = '0123456789ABCDEF';
var
  I, Index, Size: Integer;
  Data: PByte;
  B: Byte;
begin
  Size := GetSize;
  Data := GetData;
  if (Size = 0) or (Data = nil) then
    Exit;

  SetLength(Result, Size * 2);
  Index := Low(String);
  for I := 0 to Size - 1 do
  begin
    B := Data[I];
    Result[Index] := HEX_CHARS[B shr 4];
    Inc(Index);
    Result[Index] := HEX_CHARS[B and $0F];
    Inc(Index);
  end;
end;

{ TZMessage }

function TZMessage.Clone: PZMessage;
var
  I: Integer;
begin
  Result := Create;
  Result.FCount := FCount;
  if (FCount <= STATIC_FRAME_COUNT) then
  begin
    Result.FCapacity := STATIC_FRAME_COUNT;
    Result.FFrames := @Result.FStaticFrames[0]
  end
  else
  begin
    Result.FCapacity := FCount;
    GetMem(Result.FFrames, FCount * SizeOf(PZFrame));
  end;
  for I := 0 to FCount - 1 do
    Result.FFrames[I] := FFrames[I].Clone;
end;

class function TZMessage.Create: PZMessage;
begin
  GetMem(Result, SizeOf(TZMessage) {$IFDEF TRACK_MEMORY}, '_PZMessage'{$ENDIF});
  FillChar(Result^, SizeOf(TZMessage), 0);
  Result.FCursor := -1;
  Result.FFrames := @Result.FStaticFrames[0];
  Result.FCapacity := STATIC_FRAME_COUNT;
end;

function TZMessage.First: PZFrame;
begin
  FCursor := 0;
  if (FCursor >= FCount) then
    Result := nil
  else
    Result := FFrames[FCount - 1 - FCursor];
end;

procedure TZMessage.Free;
var
  I: Integer;
begin
  if (@Self <> nil) then
  begin
    for I := 0 to FCount - 1 do
      FFrames[I].Free;
    if (FFrames <> @FStaticFrames[0]) then
      FreeMem(FFrames);
    FreeMem(@Self {$IFDEF TRACK_MEMORY}, '_PZMessage'{$ENDIF});
  end;
end;

function TZMessage.GetFrame(const AIndex: Integer): PZFrame;
begin
  { Frames are stored in reverse order for efficiency }
  Result := FFrames[FCount - AIndex - 1];
end;

function TZMessage.Next: PZFrame;
begin
  if (FCursor < 0) then
    FCursor := 0
  else
    Inc(FCursor);

  if (FCursor >= FCount) then
    Result := nil
  else
    Result := FFrames[FCount - 1 - FCursor];
end;

function TZMessage.Peek: PZFrame;
begin
  if (FCount = 0) then
    Result := nil
  else
    Result := FFrames[FCount - 1];
end;

function TZMessage.PeekBytes: TBytes;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit(nil);

  Result := Frame.ToBytes;
end;

function TZMessage.PeekDouble: Double;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Peek;
  if (Frame = nil) then
    Exit;

  if (Frame.Size <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := PDouble(Frame.Data)^;
end;

function TZMessage.PeekEnum<T>: T;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit(Default(T));

  if (Frame.Size <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Move(Frame.Data^, Result, SizeOf(Result));
end;

function TZMessage.PeekEnum(const AEnumSize: Integer): Integer;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit(0);

  if (Frame.Size <> AEnumSize) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);

  Result := 0;
  Move(Frame.Data^, Result, AEnumSize);
end;

function TZMessage.PeekInteger: Integer;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Peek;
  if (Frame = nil) then
    Exit;

  if (Frame.Size <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := PInteger(Frame.Data)^;
end;

function TZMessage.PeekProtocolBuffer(const ARecordType: Pointer; out AValue): Boolean;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit(False);

  TgoProtocolBuffer.Deserialize(ARecordType, AValue, Frame.Data, Frame.Size);
  Result := True;
end;

function TZMessage.PeekProtocolBuffer<T>(out AValue: T): Boolean;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit(False);

  TgoProtocolBuffer.Deserialize<T>(AValue, Frame.Data, Frame.Size);
  Result := True;
end;

function TZMessage.PeekSingle: Single;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Peek;
  if (Frame = nil) then
    Exit;

  if (Frame.Size <> SizeOf(Result)) then
    raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
  Result := PSingle(Frame.Data)^;
end;

function TZMessage.PeekString: String;
var
  Frame: PZFrame;
begin
  Frame := Peek;
  if (Frame = nil) then
    Exit('');

  Result := TEncoding.UTF8.GetString(Frame.ToBytes);
end;

function TZMessage.Pop: PZFrame;
begin
  if (FCount = 0) then
    Exit(nil);

  { Even though conceptually we pop frames from the FRONT of the message, the
    front frame is actually stored at the BACK. }

  Dec(FCount);
  Result := FFrames[FCount];
  FCursor := -1;
end;

function TZMessage.PopBytes: TBytes;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit(nil);

  try
    Result := Frame.ToBytes;
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopDouble: Double;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Pop;
  if (Frame = nil) then
    Exit;

  try
    if (Frame.Size <> SizeOf(Result)) then
      raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
    Result := PDouble(Frame.Data)^;
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopEnum<T>: T;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit(Default(T));

  try
    if (Frame.Size <> SizeOf(Result)) then
      raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
    Move(Frame.Data^, Result, SizeOf(Result));
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopEnum(const AEnumSize: Integer): Integer;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit(0);

  try
    if (Frame.Size <> AEnumSize) then
      raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);

    Result := 0;
    Move(Frame.Data^, Result, AEnumSize);
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopInteger: Integer;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Pop;
  if (Frame = nil) then
    Exit;

  try
    if (Frame.Size <> SizeOf(Result)) then
      raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
    Result := PInteger(Frame.Data)^;
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopProtocolBuffer(const ARecordType: Pointer; out AValue): Boolean;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit(False);

  try
    TgoProtocolBuffer.Deserialize(ARecordType, AValue, Frame.Data, Frame.Size);
  finally
    Frame.Free;
  end;
  Result := True;
end;

function TZMessage.PopProtocolBuffer<T>(out AValue: T): Boolean;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit(False);

  try
    TgoProtocolBuffer.Deserialize<T>(AValue, Frame.Data, Frame.Size);
  finally
    Frame.Free;
  end;
  Result := True;
end;

function TZMessage.PopSingle: Single;
var
  Frame: PZFrame;
begin
  Result := 0;
  Frame := Pop;
  if (Frame = nil) then
    Exit;

  try
    if (Frame.Size <> SizeOf(Result)) then
      raise EZMQError.Create(RS_ZMQ_UNEXPECTED_FRAME);
    Result := PSingle(Frame.Data)^;
  finally
    Frame.Free;
  end;
end;

function TZMessage.PopString: String;
var
  Frame: PZFrame;
begin
  Frame := Pop;
  if (Frame = nil) then
    Exit('');

  try
    Result := TEncoding.UTF8.GetString(Frame.ToBytes);
  finally
    Frame.Free;
  end;
end;

procedure TZMessage.Push(var AFrame: PZFrame);
var
  NewFrames: PPZFrame;
begin
  { Even though conceptually we push to the FRONT of the message, it is much
    more efficient to add the frame to the BACK. }
  Assert(Assigned(AFrame));
  if (FCount = STATIC_FRAME_COUNT) then
  begin
    { We need to switch to a dynamic list }
    FCapacity := STATIC_FRAME_COUNT + 4;
    GetMem(NewFrames, FCapacity * SizeOf(PZFrame));
    Move(FFrames[0], NewFrames[0], STATIC_FRAME_COUNT * SizeOf(PZFrame));
    FFrames := NewFrames;
  end
  else if (FCount >= FCapacity) then
  begin
    FCapacity := FCount + 4;
    ReallocMem(FFrames, FCapacity * SizeOf(PZFrame));
  end;
  FFrames[FCount] := AFrame;
  Inc(FCount);
  FCursor := -1;
  AFrame := nil;
end;

procedure TZMessage.PushBytes(const AValue: TBytes);
begin
  PushMemory(AValue[0], Length(AValue));
end;

procedure TZMessage.PushDouble(const AValue: Double);
begin
  PushMemory(AValue, SizeOf(AValue));
end;

procedure TZMessage.PushEmptyFrame;
var
  Frame: PZFrame;
begin
  Frame := TZFrame.Create;
  Push(Frame);
end;

procedure TZMessage.PushEnum<T>(const AValue: T);
begin
  Assert(GetTypeKind(T) = tkEnumeration);
  PushMemory(AValue, SizeOf(AValue));
end;

procedure TZMessage.PushEnum(const AEnumValue, AEnumSize: Integer);
begin
  PushMemory(AEnumValue, AEnumSize);
end;

procedure TZMessage.PushInteger(const AValue: Integer);
begin
  PushMemory(AValue, SizeOf(AValue));
end;

procedure TZMessage.PushMemory(const AValue; const ASize: Integer);
var
  Frame: PZFrame;
begin
  Frame := TZFrame.Create(AValue, ASize);
  Push(Frame);
end;

procedure TZMessage.PushProtocolBuffer(const ARecordType: Pointer;
  const AValue);
var
  Bytes: TBytes;
begin
  Bytes := TgoProtocolBuffer.Serialize(ARecordType, AValue);
  PushMemory(Bytes[0], Length(Bytes));
end;

procedure TZMessage.PushProtocolBuffer<T>(const AValue: T);
var
  Bytes: TBytes;
begin
  Bytes := TgoProtocolBuffer.Serialize<T>(AValue);
  PushMemory(Bytes[0], Length(Bytes));
end;

procedure TZMessage.PushSingle(const AValue: Single);
begin
  PushMemory(AValue, SizeOf(AValue));
end;

procedure TZMessage.PushString(const AValue: String);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AValue);
  PushMemory(Bytes[0], Length(Bytes));
end;

function TZMessage.Receive(const ASocketHandle: Pointer;
  const ASocketType: TZSocketType): Boolean;
var
  Frame: PZFrame;
  Frames: array of PZFrame;
  Count, I, J, StartFrame: Integer;
  RcvMore, RcvMoreSize: NativeInt;
  ExpectedHashValue, ActualHashValue: Cardinal;
  Hash: TgoHashMurmur2;
begin
  Assert(Assigned(ASocketHandle));
  Assert(FCount = 0);

  RcvMore := 0;
  RcvMoreSize := SizeOf(RcvMore);
  Count := 0;
  while True do
  begin
    Frame := TZFrame.Create;
    if (Frame = nil) then
      Exit(False);

    if (not Frame.Receive(ASocketHandle)) then
    begin
      Frame.Free;
      Exit(False);
    end;

    { Messages are stored with the top frame at the BACK. So we need to add the
      frames to temporary array, so we can easily reverse the order for the
      final list. }
    if (Count >= Length({%H-}Frames)) then
      SetLength(Frames, Count + 4);
    Frames[Count] := Frame;
    Inc(Count);

    zmq_getsockopt(ASocketHandle, ZMQ_RCVMORE, @RcvMore, @RcvMoreSize);
    if (RcvMore = 0) then
      Break;
  end;

  { The last frame contains the hash value of the previous frames }
  Result := (Count > 0);
  if (Result) then
  begin
    Frame := Frames[Count - 1];
    Dec(Count);

    Result := (Frame.Size = 4);
    if (Result) then
    begin
      ExpectedHashValue := PCardinal(Frame.Data)^;

      { Calculate hash of frames }
      Hash.Reset;

      if (ASocketType = TZSocketType.Router) and (Count > 1) then
        { Messages from router sockets start with routing frames added by ZMQ.
          Exclude these from the hash. }
        StartFrame := 1
      else
        StartFrame := 0;

      for I := StartFrame to Count - 1 do
        Hash.Update(Frames[I].Data^, Frames[I].Size);
      ActualHashValue := Hash.Finish;

      { Check hash and returns False if it doesn't match (in that case
        TZSocket.Receive will return nil. }
      Result := (ActualHashValue = ExpectedHashValue);
    end;

    { Free and remove hash frame }
    Frame.Free;
  end;

  FCount := Count;
  if (Count <= STATIC_FRAME_COUNT) then
  begin
    FCapacity := STATIC_FRAME_COUNT;
    FFrames := @FStaticFrames[0];
  end
  else
  begin
    FCapacity := Count;
    GetMem(FFrames, Count * SizeOf(PZFrame));
  end;

  J := Count - 1;
  for I := 0 to Count - 1 do
  begin
    FFrames[J] := Frames[I];
    Dec(J);
  end;
  Assert(J = -1);
end;

function TZMessage.Send(const ASocketHandle: Pointer;
  const ASocketType: TZSocketType): Boolean;
var
  I: Integer;
  Frame: PZFrame;
  Hash: TgoHashMurmur2;
  HashValue: Cardinal;
  StartFrame: Integer;
begin
  Assert(Assigned(ASocketHandle));
  try
    if (FCount = 0) then
      Exit(False);

    { We create an incremental hash value for all frames. }
    Hash.Reset;

    { Messages are stored with the top frame at the BACK. So we need to send in
      reverse order }
    if (ASocketType = TZSocketType.Router) and (FCount > 1) then
      StartFrame := FCount - 2
    else
      StartFrame := FCount - 1;

    for I := StartFrame downto 0 do
    begin
      Frame := FFrames[I];
      Hash.Update(Frame.Data^, Frame.Size);
    end;

    for I := FCount - 1 downto 0 do
    begin
      Frame := FFrames[I];
      if (not Frame.Send(ASocketHandle, True)) then
        Exit(False);

      { Sending a frame will destroy it }
      Dec(FCount);
    end;

    { Send additional frame with hash }
    HashValue := Hash.Finish;
    Frame := TZFrame.Create(HashValue, 4);
    if (not Frame.Send(ASocketHandle, False)) then
      Exit(False);

    Assert(FCount = 0);
    Result := True;
  finally
    { Sending will destroy the message. Each frame has already been destroyed,
      but we still need to free the memory used by the message itself. }
    Free;
  end;
end;

function TZMessage.Unwrap: PZFrame;
var
  Empty: PZFrame;
begin
  Result := Pop;
  if Assigned(Result) then
  begin
    Empty := Peek;
    if (Empty.Size = 0) then
    begin
      Empty := Pop;
      Empty.Free;
    end;
  end;
end;

{ TZSocket }

function TZSocket.Bind(const AEndpoint: String): Integer;
var
  BaseEndpoint, TestEndPoint: String;
  I: Integer;
begin
  I := Length(AEndPoint);
  if (I > 2) and (AEndPoint[Low(String) + I - 2] = ':') and (AEndPoint[Low(String) + I - 1] = '*') then
  begin
    BaseEndpoint := AEndpoint;
    SetLength(BaseEndpoint, Length(BaseEndpoint) - 1);
    for Result := DYN_PORT_START to DYN_PORT_END do
    begin
      TestEndPoint := BaseEndpoint + IntToStr(Result);
      if (zmq_bind(FHandle, MarshaledAString(TMarshal.AsAnsi(TestEndpoint))) = 0) then
        Exit;
    end;
    Exit(-1);
  end;

  Result := zmq_bind(FHandle, MarshaledAString(TMarshal.AsAnsi(AEndpoint)));
  if (Result = 0) then
  begin
    for I := Length(AEndPoint) + Low(String) - 1 downto Low(String) do
    begin
      if (AEndPoint[I] = ':') then
      begin
        Result := StrToIntDef(Copy(AEndPoint, I + 1, MaxInt), 0);
        Break;
      end;
    end;
  end
  else
    Result := -1;
end;

function TZSocket.Connect(const AEndpoint: String): Boolean;
begin
  Result := (zmq_connect(FHandle, MarshaledAString(TMarshal.AsAnsi(AEndpoint))) = 0);
end;

constructor TZSocket.Create(const AContext: TZContext;
  const AType: TZSocketType);
begin
  Assert(Assigned(AContext));
  FSocketType := AType;
  FHandle := AContext.CreateSocket(AType);
  if (FHandle = nil) then
    raise EZMQError.Create(RS_ZMQ_ERROR_CREATING_SOCKET);
end;

function TZSocket.Disconnect(const AEndpoint: String): Boolean;
begin
  Result := Assigned(FHandle) and (zmq_disconnect(FHandle, MarshaledAString(TMarshal.AsAnsi(AEndpoint))) = 0);
end;

procedure TZSocket.Free(const AContext: TZContext);
begin
  Assert(Assigned(AContext));
  if (Assigned(FHandle)) then
  begin
    AContext.FreeSocket(FHandle);
    FHandle := nil;
  end;
end;

function TZSocket.GetIsCurveServer: Boolean;
var
  Len, Val: Integer;
begin
  Len := SizeOf(Val);
  zmq_getsockopt(FHandle, ZMQ_CURVE_SERVER, @Val, @Len);
  Result := (Val = 1);
end;

function TZSocket.GetLinger: Integer;
var
  Len: Integer;
begin
  Len := SizeOf(Result);
  zmq_getsockopt(FHandle, ZMQ_LINGER, @Result, @Len);
end;

function TZSocket.Poll(const AEvent: TZSocketPoll;
  const ATimeout: Integer): TZSocketPollResult;
var
  Item: zmq_pollitem_t;
begin
  Assert(Assigned(FHandle));
  Item.socket := FHandle;
  Item.fd := 0;
  Item.events := Ord(AEvent);
  Item.revents := 0;

  if (zmq_poll(@Item, 1, ATimeout) < 0) then
    Result := TZSocketPollResult.Interrupted
  else if ((Item.revents and Ord(AEvent)) <> 0) then
    Result := TZSocketPollResult.Available
  else
    Result := TZSocketPollResult.Timeout;
end;

function TZSocket.Receive: PZMessage;
begin
  Assert(Assigned(FHandle));
  Result := TZMessage.Create;
  if (not Result.Receive(FHandle, FSocketType)) then
  begin
    Result.Free;
    Result := nil;
  end;
end;

function TZSocket.Send(var AMessage: PZMessage): Boolean;
begin
  Assert(Assigned(FHandle));
  Assert(Assigned(AMessage));
  Result := AMessage.Send(FHandle, FSocketType);
  AMessage := nil;
end;

procedure TZSocket.SetCurvePublicKey(const AKey: String);
var
  AnsiValue: MarshaledAString;
begin
  Assert(Length(AKey) = 40);
  AnsiValue := MarshaledAString(TMarshal.AsAnsi(AKey));
  zmq_setsockopt(FHandle, ZMQ_CURVE_PUBLICKEY, AnsiValue, Length(AKey));
end;

procedure TZSocket.SetCurvePublicKey(const AKey: TZCurveKey);
begin
  zmq_setsockopt(FHandle, ZMQ_CURVE_PUBLICKEY, @AKey[0], Length(AKey));
end;

procedure TZSocket.SetCurveSecretKey(const AKey: String);
var
  AnsiValue: MarshaledAString;
begin
  Assert(Length(AKey) = 40);
  AnsiValue := MarshaledAString(TMarshal.AsAnsi(AKey));
  zmq_setsockopt(FHandle, ZMQ_CURVE_SECRETKEY, AnsiValue, Length(AKey));
end;

procedure TZSocket.SetCurveSecretKey(const AKey: TZCurveKey);
begin
  zmq_setsockopt(FHandle, ZMQ_CURVE_SECRETKEY, @AKey[0], Length(AKey));
end;

procedure TZSocket.SetCurveServerKey(const AKey: String);
var
  AnsiValue: MarshaledAString;
begin
  Assert(Length(AKey) = 40);
  AnsiValue := MarshaledAString(TMarshal.AsAnsi(AKey));
  zmq_setsockopt(FHandle, ZMQ_CURVE_SERVERKEY, AnsiValue, Length(AKey));
end;

procedure TZSocket.SetCurveServerKey(const AKey: TZCurveKey);
begin
  zmq_setsockopt(FHandle, ZMQ_CURVE_SERVERKEY, @AKey[0], Length(AKey));
end;

procedure TZSocket.SetIsCurveServer(const Value: Boolean);
var
  Val: Integer;
begin
  Val := Ord(Value);
  zmq_setsockopt(FHandle, ZMQ_CURVE_SERVER, @Val, SizeOf(Val));
end;

procedure TZSocket.SetLinger(const Value: Integer);
begin
  zmq_setsockopt(FHandle, ZMQ_LINGER, @Value, SizeOf(Value));
end;

function TZSocket.Unbind(const AEndpoint: String): Boolean;
begin
  Result := (zmq_unbind(FHandle, MarshaledAString(TMarshal.AsAnsi(AEndpoint))) = 0);
end;

{ TZCertificate }

procedure TZCertificate.Apply(const ASocket: TZSocket);
begin
  ASocket.SetCurveSecretKey(FSecretKey);
  ASocket.SetCurvePublicKey(FPublicKey);
end;

constructor TZCertificate.Create;
var
  PublicKey, SecretKey: TBytes;
begin
  inherited Create;
  SetLength(PublicKey, 41);
  SetLength(SecretKey, 41);
  if (zmq_curve_keypair(@PublicKey[0], @SecretKey[0]) = 0) then
  begin
    FPublicTxt := TEncoding.ANSI.GetString(PublicKey, 0, 40);
    FSecretTxt := TEncoding.ANSI.GetString(SecretKey, 0, 40);
    zmq_z85_decode(@FPublicKey[0], @PublicKey[0]);
    zmq_z85_decode(@FSecretKey[0], @SecretKey[0]);
  end
  else
  begin
    FPublicTxt := FORTY_ZEROES;
    FSecretTxt := FORTY_ZEROES;
  end;
end;

constructor TZCertificate.Create(const AFilename: String);
var
  SecretFilename: String;
  Doc, SubDoc: TgoBsonDocument;
  Value: TgoBsonValue;
  Bytes: TBytes;
begin
  inherited Create;
  try
    try
      SecretFilename := AFilename + '_secret';
      if FileExists(SecretFilename) then
        Doc := TgoBsonDocument.LoadFromJsonFile(SecretFilename)
      else if FileExists(AFilename) then
        Doc := TgoBsonDocument.LoadFromJsonFile(AFilename)
      else
        Exit;

      if Doc.TryGetValue('curve', Value) and (Value.IsBsonDocument) then
      begin
        SubDoc := Value.AsBsonDocument;
        FPublicTxt := SubDoc['public-key'];
        FSecretTxt := SubDoc['secret-key'];
      end;

      if (Length(FPublicTxt) <> 40) then
      begin
        FPublicTxt := '';
        Exit;
      end;

      Bytes := TEncoding.ANSI.GetBytes(FPublicTxt + #0);
      zmq_z85_decode(@FPublicKey[0], @Bytes[0]);

      if (Length(FSecretTxt) = 40) then
      begin
        Bytes := TEncoding.ANSI.GetBytes(FSecretTxt + #0);
        zmq_z85_decode(@FSecretKey[0], @Bytes[0]);
      end
      else
        FSecretTxt := FORTY_ZEROES;
    except
      { Will raise exception below }
    end;
  finally
    if (FPublicTxt = '') then
      raise EZMQError.CreateFmt(RS_ZMQ_CANNOT_LOAD_CERTIFICATE, [AFilename]);
  end;
end;

procedure TZCertificate.Save(const AFilename: String);
var
  Doc, SubDoc: TgoBsonDocument;
begin
  Doc := TgoBsonDocument.Create;
  SubDoc := TgoBsonDocument.Create;
  Doc.Add('curve', SubDoc);

  SubDoc['public-key'] := FPublicTxt;
  Doc.SaveToJsonFile(AFilename, TgoJsonWriterSettings.Pretty);

  SubDoc['secret-key'] := FSecretTxt;
  Doc.SaveToJsonFile(AFilename + '_secret', TgoJsonWriterSettings.Pretty);
end;

initialization
  ZMQInitializeDebugMode;

finalization
  ZMQFinalizeDebugMode;

end.