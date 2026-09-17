///|
pub(all) struct WillMessage {
  topic : String
  payload : Bytes
  qos : QoS
  retain : Bool
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct ConnectPacket {
  client_id : String
  clean_start : Bool
  keep_alive : UInt16
  username : String?
  password : Bytes?
  will : WillMessage?
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub fn ConnectPacket::new(
  client_id : String,
  clean_start? : Bool = true,
  keep_alive? : UInt16 = 60,
) -> ConnectPacket {
  {
    client_id,
    clean_start,
    keep_alive,
    username: None,
    password: None,
    will: None,
    properties: [],
  }
}

///|
pub(all) struct ConnAckPacket {
  session_present : Bool
  reason_code : Byte
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct PublishPacket {
  topic : String
  payload : Bytes
  qos : QoS
  retain : Bool
  duplicate : Bool
  packet_id : UInt16?
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub fn PublishPacket::new(
  topic : String,
  payload : Bytes,
  qos? : QoS = AtMostOnce,
  retain? : Bool = false,
  duplicate? : Bool = false,
  packet_id? : UInt16? = None,
) -> PublishPacket {
  { topic, payload, qos, retain, duplicate, packet_id, properties: [], }
}

///|
pub(all) struct PubResponsePacket {
  kind : PacketType
  packet_id : UInt16
  reason_code : Byte
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct Subscription {
  topic_filter : String
  qos : QoS
  no_local : Bool
  retain_as_published : Bool
  retain_handling : Int
} derive(Eq, Debug)

///|
pub fn Subscription::new(
  topic_filter : String,
  qos? : QoS = AtMostOnce,
) -> Subscription {
  {
    topic_filter,
    qos,
    no_local: false,
    retain_as_published: false,
    retain_handling: 0,
  }
}

///|
pub(all) struct SubscribePacket {
  packet_id : UInt16
  subscriptions : Array[Subscription]
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct SubAckPacket {
  packet_id : UInt16
  reason_codes : Array[Byte]
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct UnsubscribePacket {
  packet_id : UInt16
  topic_filters : Array[String]
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct UnsubAckPacket {
  packet_id : UInt16
  reason_codes : Array[Byte]
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct DisconnectPacket {
  reason_code : Byte
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) struct AuthPacket {
  reason_code : Byte
  properties : Array[Property]
} derive(Eq, Debug)

///|
pub(all) enum Packet {
  ConnectPacket(ConnectPacket)
  ConnAckPacket(ConnAckPacket)
  PublishPacket(PublishPacket)
  PubResponsePacket(PubResponsePacket)
  SubscribePacket(SubscribePacket)
  SubAckPacket(SubAckPacket)
  UnsubscribePacket(UnsubscribePacket)
  UnsubAckPacket(UnsubAckPacket)
  PingReqPacket
  PingRespPacket
  DisconnectPacket(DisconnectPacket)
  AuthPacket(AuthPacket)
} derive(Eq, Debug)
