///|
pub(all) enum QoS {
  AtMostOnce
  AtLeastOnce
  ExactlyOnce
} derive(Eq, Debug)

///|
pub fn QoS::to_int(self : QoS) -> Int {
  match self {
    AtMostOnce => 0
    AtLeastOnce => 1
    ExactlyOnce => 2
  }
}

///|
pub fn QoS::from_int(value : Int) -> Result[QoS, MqttError] {
  match value {
    0 => Ok(AtMostOnce)
    1 => Ok(AtLeastOnce)
    2 => Ok(ExactlyOnce)
    _ => Err(InvalidQoS(value))
  }
}

///|
pub(all) enum PacketType {
  Connect
  ConnAck
  Publish
  PubAck
  PubRec
  PubRel
  PubComp
  Subscribe
  SubAck
  Unsubscribe
  UnsubAck
  PingReq
  PingResp
  Disconnect
  Auth
} derive(Eq, Debug)

///|
pub fn PacketType::code(self : PacketType) -> Int {
  match self {
    Connect => 1
    ConnAck => 2
    Publish => 3
    PubAck => 4
    PubRec => 5
    PubRel => 6
    PubComp => 7
    Subscribe => 8
    SubAck => 9
    Unsubscribe => 10
    UnsubAck => 11
    PingReq => 12
    PingResp => 13
    Disconnect => 14
    Auth => 15
  }
}

///|
pub fn PacketType::from_code(value : Int) -> Result[PacketType, MqttError] {
  match value {
    1 => Ok(Connect)
    2 => Ok(ConnAck)
    3 => Ok(Publish)
    4 => Ok(PubAck)
    5 => Ok(PubRec)
    6 => Ok(PubRel)
    7 => Ok(PubComp)
    8 => Ok(Subscribe)
    9 => Ok(SubAck)
    10 => Ok(Unsubscribe)
    11 => Ok(UnsubAck)
    12 => Ok(PingReq)
    13 => Ok(PingResp)
    14 => Ok(Disconnect)
    15 => Ok(Auth)
    _ => Err(InvalidPacketType(value))
  }
}

///|
pub(all) enum MqttError {
  NeedMoreData
  MalformedPacket(String)
  InvalidPacketType(Int)
  InvalidFlags(PacketType, Int)
  InvalidQoS(Int)
  InvalidProperty(Int)
  InvalidPropertyValue(Int, String)
  InvalidUtf8(String)
  ValueOutOfRange(String, Int)
  ProtocolViolation(String)
  InvalidState(String)
  ConnectionRejected(Byte, Array[Property])
} derive(Eq, Debug)

///|
pub(all) struct FixedHeader {
  packet_type : PacketType
  flags : Int
  remaining_length : Int
} derive(Eq, Debug)

///|
pub(all) enum Property {
  PayloadFormatIndicator(Byte)
  MessageExpiryInterval(UInt)
  ContentType(String)
  ResponseTopic(String)
  CorrelationData(Bytes)
  SubscriptionIdentifier(Int)
  TopicAlias(UInt16)
  UserProperty(String, String)
  SessionExpiryInterval(UInt)
  WillDelayInterval(UInt)
  AssignedClientIdentifier(String)
  ServerKeepAlive(UInt16)
  AuthenticationMethod(String)
  AuthenticationData(Bytes)
  RequestProblemInformation(Byte)
  RequestResponseInformation(Byte)
  ResponseInformation(String)
  ServerReference(String)
  ReasonString(String)
  ReceiveMaximum(UInt16)
  TopicAliasMaximum(UInt16)
  MaximumQoS(Byte)
  RetainAvailable(Byte)
  MaximumPacketSize(UInt)
  WildcardSubscriptionAvailable(Byte)
  SubscriptionIdentifierAvailable(Byte)
  SharedSubscriptionAvailable(Byte)
} derive(Eq, Debug)
