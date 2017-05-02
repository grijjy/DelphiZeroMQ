# Roll your own lightweight, scalable backend using ZeroMQ
[ZeroMQ](http://zeromq.org/) is high-speed, distributed messaging library for building scalable communication apps using smart patterns like pub-sub, push-pull, and router-dealer.  In this article we will be demonstrating a Delphi version of the [ZeroMQ Majordomo Protocol specification](https://rfc.zeromq.org/spec:7/MDP/) which is lightweight distributed communication framework for creating service daemons running on Windows and Linux (with Tokyo 10.2) and client apps running on Windows, Linux, iOS and Android.  We will also be demonstrating a Delphi version of the [CZMQ high-level binding for ZeroMQ](http://czmq.zeromq.org/) that we call PascalZMQ.  

ZeroMQ and the Majordomo protocol fit nicely into existing cloud based, distributed models running on cloud services such as Google Compute and Amazon's Web Services. It is very well matched to mobile apps and IoT apps where bandwidth is limited, connections are not always reliable and your backend services need to be dynamically scalable. 

The Majordomo protocol for ZeroMQ uses a network of Workers modules performing various services and Brokers that efficiently route activity.  Clients also interconnect to Brokers using the ZeroMQ protocol and send messages.  Communications in ZeroMQ's Majordomo protocol flow bidirectionally between all endpoints.  This allows you to create a distributed BAAS where requests can be tied to immediate responses or actions that produce results that arrive at a later time.

There are some other ZeroMQ implementations available for Delphi.  However, to the best of our knowledge, there has not been an exhaustive look at the Majordomo protocol in Delphi or a complete translation for the CZMQ library which we will also discuss in this article.  These will be the primary topic areas of our discussion and implementation.

## A replacement for IP sockets
At its most basic level, ZeroMQ provides a cross-platform transport that you can use instead of TCP sockets or HTTP request/response.  It is built for efficiency and it doesn't have the overhead of http, socket.io or WebSockets.  It is an excellent choice for situations where bandwidth is limited such as mobile apps or IoT apps and performance is paramount.  

It manages all the complexities of creating and managing connections and disconnections and queuing data over unreliable connections.  It takes care of routing data between nodes internally so communications are bi-directional and it focuses on keeping the payload overhead efficient.

You can create servers that use scalable communication models such as EPOLL or KQueue on Linux and your communication patterns can be over TCP, inter-process, inter-thread and so much more.  The beauty of ZeroMQ is that these complexities are abstracted and you can change transport models and OS platforms at any time without changing the logic in your code.

With ZeroMQ you can write your communication code once and run everywhere that Delphi can target such as Android, iOS, Windows and Linux.

## PUB/SUB, Dealer/Router, Push/Pull and more
However, describing ZeroMQ as a replacement for socket communications is really not doing it justice.  ZeroMQ is capable of many different data routing models including Publisher/Subscriber, Push/Pull and Dealer/Router.   With these models it is possible to build many different communication solutions.  

There are so many different solutions that could be created we could not possibly describe them all.  Many of the interfaces are implemented in our ZeroMQ classes but discussing them in detail is well beyond the scope of this article.  For a complete discussion of these topics, see the [excellent documentation on ZeroMQ's site](http://zguide.zeromq.org/page:all).

## Majordomo Protocol
ZeroMQ offers a distributed messaging model they refer to as the [Majordomo protocol](https://rfc.zeromq.org/spec:7/MDP/).  Here at Grijjy we implemented the ZeroMQ Majordomo protocol entirely in Delphi so we could build a large scale backend of Workers and services.

The Majordomo protocol has several components that typically operate on different nodes.  The client is usually operating on a desktop OS or mobile device (Windows, Linux, iOS or Android).  The Broker is on one or more nodes in the cloud and handles routing and load balancing.  The Worker is a node which handles one or more services.  In the Majordomo model you can have a virtually unlimited number of not only Brokers but Workers performing various services.

The model is designed to be stateless so that any Broker or Worker can handle work on behalf of any client.  ZeroMQ internally handles the routing between Workers, Brokers and clients so you can establish communication patterns that suit your implementation.  For example, you are not limited to a single response for a single request.  Arbitrary communication can flow in all directions at anytime with ZeroMQ.

## PascalZMQ
ZeroMQ's base library is very low level, so in order to provide a message and framing transport, they created the [CZMQ library](http://czmq.zeromq.org/).  This library is a higher level implementation around the lower-level base ZeroMQ API designed to allow you to include your own data in a ZeroMQ multi-part message which is used for data encapsulation.

Here at Grijjy we use this messaging and framing model, but for performance and memory management considerations we developed our own conversion that we call [PascalZMQ](https://github.com/grijjy/DelphiZeroMQ/blob/master/PascalZMQ.pas).  Is it essentially the same as the C version but wrapped in an easily consumable Delphi object model and enhanced for efficiency and performance.

Included in this implementation we added our implementation of [Google Protocol Buffers](https://blog.grijjy.com/2017/04/25/binary-serialization-with-google-protocol-buffers/).  Google Protocol Buffers is an excellent choice when you are bandwidth limited.  Our implementation allows you to serialize any given Delphi record into a binary object that is provided to ZeroMQ's transport.   This methodology makes the movement of Delphi related types in a cross-platform manner both easy and efficient.  See the Google Protocol Buffer section below for more information on this topic. 

## Building ZeroMQ
In order to use ZeroMQ you will need a library for each platform.  Additionally you need to build another library called [libSodium](https://libsodium.org/) which is used for encryption.  While you don't have to use libSodium and encryption with ZeroMQ, we will discuss the process nonetheless in the event you choose to add it.

For our example, we have pre-built the library binaries for Windows, iOS and Android for you.  If you want to build them yourself you need to download the latest sources from http://zeromq.org/ and http://libsodium.org.  In the case of libSodium the source files are located at https://download.libsodium.org/libsodium/releases/  

Windows requires the libzmq.dll.  In our pre-built binary, libSodium is included and linked into the finalized libzmq.dll.

Linux requires both the libzmq.so and libsodium.so on your Linux development server (where you are running the PAServer).  You build libsodium using the typical pattern,
```shell
./configure
make install
ldconfig
```

However, when you build libzmq you must include a reference to the libsodium library such as,
```shell
./configure --with-libsodium=..\libsodium... folder
make install
ldconfig
```

Building the libraries for iOS and Android is rather complicated.  We have developed our own scripts for each platform to ease the process.  It would require a full article just to cover those topics individually so we are simply[ including the already built binary libraries](https://github.com/grijjy/DelphiZeroMQ/Lib/).  Those libraries need to be included in your Delphi project path so the linker can include them during the build process.

## Broker
The Broker in the Majordomo protocol connects a given set of clients, to a single Broker and a pool of Workers.  Clients connect to the Broker, but so do the Workers.  As best described in the RFC,

"Clients and workers do not see each other, and both can come and go arbitrarily. The broker MAY open two sockets (ports), one front-end for clients, and one back-end for workers. However MDP (Majordomo protocol) is also designed to work over a single broker socket.

We define 'client' applications as those issuing requests, and 'worker' applications as those processing them."

"The Majordomo broker handles a set of shared request queues, one per service. Each queue has multiple writers (clients) and multiple readers (workers). The broker SHOULD serve clients on a fair basis and MAY deliver requests to workers on any basis, including round robin and least-recently used."

The role of the Broker is to quickly route your requests to Workers who perform services on your client's behalf, but also to easily handle network issues with Workers that may come and go for various reasons.


The minimal Broker example only requires 2 methods, one method for handling messages from Clients and one method for messages from Workers.  Consider the following example...
```Delphi
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
```
In this example we only need to implement the DoRecvFromClient and DoRecvFromWorker methods as follows,

```Delphi
procedure TExampleBroker.DoRecvFromClient(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction; var ASendToId: String);
begin
  AAction := TZMQAction.Forward;
end;

procedure TExampleBroker.DoRecvFromWorker(const AService: String; const ASentFromId: String;
  const ASentFrom: PZFrame; var AMsg: PZMessage; var AAction: TZMQAction);
begin
  AAction := TZMQAction.Forward;
end;
```
In both cases we specify the TZMQAction.Forward which tells the ZeroMQ stack to simply route the message to the intended target.  However we could make many other decisions here including changing the target destination for the message to another Client or Worker.  We could also discard the message entirely.  We could also examine the contents of the message if we needed. 

> Typically the Broker processes and forwards messages quickly so it should only examine messages that relate to critical information.  For example, if you are building a completely stateless model you will need some form of token authentication.  You could create an Authentication Worker service that verifies a user's credentials that the Broker in turn creates an Auth token when it receives a message from the Authentication service approving the user.  This token would then be included in the payload of client messages and verified by the Broker before forwarding or discarding a given message. 

To create an example Broker is straightforward.  Consider the following example...
```Delphi
Broker := TExampleBroker.Create;
try
  if Broker.Bind('tcp://*:1234') then
    WaitForCtrlC;
finally
  Broker.Free;
end;
```
In this example we start a Broker bound to the local IP addresses of the computer on tcp port 1234.  This could be a specific IP address or even a different protocol that works inter-process or intra-process.

## Worker
The Worker in the Majordomo protocol handles service activity based upon your requirements.  You can have completely different Workers that handles different types of work (ie: different service names) and a virtually unlimited amount of any given service.  This allows you to dynamically expand or contract your backend cloud based upon your app requirements.

If you need more authentication, then you simply start another Authentication Worker.   The Broker in the Majordomo protocol takes care of load balancing the requests and handles routing back to the respective client automatically. 

The minimal Worker example would go something like the following...
```Delphi
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
```
When you want the Worker to reply to a request you would call a Send() method such as,
```Delphi
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
```
In the above example we package our response into `AData` and reply to the routing frame `ARoutingFrame`.

To receive a message from the Broker, we would implement the `DoRecv` method as follows,
```Delphi
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
```
ZeroMQ messages are multi-part messages constructed as a stack.  In this case we would 'pop' our bytes from the message, analyze it and send a response back.

To create a Worker is as simple as,
```Delphi
Worker := TExampleWorker.Create;
try
  if Worker.Connect('tcp://localhost:1234', '', TZSocketType.Dealer, SERVICE_NAME) then
    WaitForCtrlC;
finally
  Worker.Free;
end;
```
Here we are connecting to the specified Broker at the specified address.

## Client
The Client in the ZeroMQ Majordomo protocol is simply an interface protocol class and supporting units for communications.

A simple example client would be as follows,
```Delphi
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
  end
```
To send a message to the Broker, which in turn forwards to a Worker we would,
```Delphi
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
```
This example sends the binary payload in `AData` to the service named `AService`.  When the Worker responds we would receive our response as follows,
```Delphi
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
```

## Majordomo Hello World Example
In order to get started quickly we have included a Delphi Project group called [Majordomo in our Grijjy GitHub respository](https://github.com/grijjy/DelphiZeroMQ/).  There are three projects including an ExampleBroker, an ExampleWorker and an ExampleClient.

The ExampleBroker and ExampleBroker are configured to build under Windows or Linux.  The ExampleClient is configured to work on Windows, Android, iOS32 and iOS64.

## Using Google Protocol Buffers
ZeroMQ uses a multi-part message model that behaves like a stack.  It supports building a multi-part message using the basic Delphi data types as well as binary objects.  It is relatively efficient, but it is not as compact as we would like.  It is also not well suited to data serialization from Delphi complex types and records.  

In our PascalZMQ unit and classes we implement the following ZeroMQ push/pop behaviors,
```Delphi
TZMessage.PushInteger
TZMessage.PushSingle
TZMessage.PushDouble
TZMessage.PushEnum
TZMessage.PushString
TZMessage.PushBytes

TZMessage.PopInteger
TZMessage.PopSingle
TZMessage.PopDouble
TZMessage.PopEnum
TZMessage.PopString
TZMessage.PopBytes
```
In addition we added various Peek() methods, such as:
```Delphi
TZMessage.PeekInteger
TZMessage.PeekSingle
TZMessage.PeekDouble
TZMessage.PeekEnum
TZMessage.PeekString
TZMessage.PeekBytes
```
However internally we prefer the simplicity and effiency of Google Protocol Buffers.  Google Protocol Buffers provides an efficient data compacting model that is ideal for IoT and mobile apps.  Because of these limitations we expanded the base PascalZMQ class to support our Google Protocol Buffers implementation.  

Using our [Grijjy implementation of Google Protocol Buffers](https://blog.grijjy.com/2017/04/25/binary-serialization-with-google-protocol-buffers/) you can directly serialize Delphi records into binary objects that can be pushed and popped from ZeroMQ's stack.

To support this feature, we added additional push and pop methods specific to protocol buffers,
```Delphi
TZMessage.PushProtocolBuffer
TZMessage.PopProtocolBuffer
TZMessage.PeekProtocolBuffer
```

For more information on our [Google Protocol Buffers implementation see our article](https://blog.grijjy.com/2017/04/25/binary-serialization-with-google-protocol-buffers/).

## Encryption using CURVE and LibSodium
The default example we do not enable the encryption features found in LibSodium.  However, enabling ZeroMQ's supported encryption is relatively straight-forward.  

To enable encryption, you need to first change the `Bind()` parameters for the Broker as follows,
```Delphi
Broker.Bind('tcp://*:1234', TZSocketType.Router, True);
``` 
This will cause the Broker to create a certificate upon restart.  Then you must use the Broker's public key (contained in the certificate file) when you call `Connect()` from both the Worker and the Client.

> There are other supported models such as server-side created certificates for Clients and more in the ZeroMQ security model.  These other methods provide even greater control over the security model.

## Real-world ideas
What can you do with this?  Well the mind boggles with the possibilities.  Internally we have built a stateless BAAS model that expands and contracts dynamically in Google's Compute Engine.  

We have also used it to create a Delphi cross-platform remote cloud logger so you can originate debug style messages from any platform including iOS, Android and Linux and receive those messages in near real-time at your Windows workstation.  We will demonstrate this example in an upcoming article.

## Conclusion
The beauty of ZeroMQ and it's Majordomo protocol is that you can quickly build efficient performing and highly scalable services that fit perfectly into cloud computing deployments.  ZeroMQ takes are of most of the complexity of managing fault-tolerance and load-balancing for your project.  It fits nicely into IoT projects and even larger BAAS projects.

We hope you will find this implementation useful for your cross-platform projects.

For more information about us, our support and services visit the [Grijjy homepage](http://www.grijjy.com) or the [Grijjy developers blog](http://blog.grijjy.com).

The example contained here depends upon part of our [Grijjy Foundation library](https://github.com/grijjy/GrijjyFoundation).

The source code and related example repository are hosted on GitHub at [https://github.com/grijjy/DelphiZeroMQ/](https://github.com/grijjy/DelphiZeroMQ/). 

# License
PascalZMQ, ZMQ.BrokerProtocol, ZMQ.ClientProtocol, ZMQ.WorkerProtocol, ZMQ.Protocol, ZMQ.Shared and the various Example projects are licensed under the Simplified BSD License. See License.txt for details.