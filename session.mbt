///|
pub(all) enum ConnectionState {
  Disconnected
  AwaitingConnAck
  Connected
  Disconnecting
} derive(Eq, Debug)

///|
pub enum InflightStage {
  AwaitingPubAck
  AwaitingPubRec
  AwaitingPubComp
  AwaitingSubAck
  AwaitingUnsubAck
} derive(Eq, Debug)

///|
pub struct Inflight {
  packet_id : UInt16
  stage : InflightStage
  packet : Packet
}

///|
pub(all) enum SessionEvent {
  ConnectedEvent(Bool, Array[Property])
  MessageEvent(PublishPacket)
  AcknowledgedEvent(PacketType, UInt16, Byte)
  DisconnectedEvent(Byte, Array[Property])
  AuthEvent(AuthPacket)
} derive(Eq, Debug)

///|
pub(all) struct SessionOutcome {
  responses : Array[Packet]
  events : Array[SessionEvent]
} derive(Eq, Debug)

///|
fn empty_outcome() -> SessionOutcome {
  { responses: [], events: [], }
}

///|
pub struct ClientSession {
  mut state : ConnectionState
  mut next_packet_id : Int
  mut ping_outstanding : Bool
  inflight : Array[Inflight]
  incoming_qos2 : Array[PublishPacket]
}

///|
pub fn ClientSession::new() -> ClientSession {
  {
    state: Disconnected,
    next_packet_id: 1,
    ping_outstanding: false,
    inflight: [],
    incoming_qos2: [],
  }
}

///|
pub fn ClientSession::state(self : ClientSession) -> ConnectionState {
  self.state
}

///|
pub fn ClientSession::inflight_count(self : ClientSession) -> Int {
  self.inflight.length()
}

///|
pub fn ClientSession::has_ping_outstanding(self : ClientSession) -> Bool {
  self.ping_outstanding
}

///|
fn ClientSession::find_inflight(
  self : ClientSession,
  packet_id : UInt16,
) -> Int? {
  self.inflight.search_by(item => item.packet_id == packet_id)
}

///|
fn ClientSession::identifier_in_use(
  self : ClientSession,
  packet_id : UInt16,
) -> Bool {
  self.find_inflight(packet_id) is Some(_)
}

///|
fn ClientSession::allocate_packet_id(
  self : ClientSession,
) -> Result[UInt16, MqttError] {
  let mut attempts = 0
  while attempts < 65535 {
    if self.next_packet_id > 65535 {
      self.next_packet_id = 1
    }
    let candidate = self.next_packet_id.to_uint16()
    self.next_packet_id += 1
    if !self.identifier_in_use(candidate) {
      return Ok(candidate)
    }
    attempts += 1
  }
  Err(InvalidState("all MQTT packet identifiers are in use"))
}

///|
fn ClientSession::require_connected(
  self : ClientSession,
) -> Result[Unit, MqttError] {
  if self.state == Connected {
    Ok(())
  } else {
    Err(InvalidState("operation requires a connected MQTT session"))
  }
}

///|
pub fn ClientSession::begin_connect(
  self : ClientSession,
  packet : ConnectPacket,
) -> Result[Packet, MqttError] {
  if self.state != Disconnected {
    return Err(
      InvalidState("CONNECT can only start from the disconnected state"),
    )
  }
  self.inflight.clear()
  self.incoming_qos2.clear()
  self.ping_outstanding = false
  self.state = AwaitingConnAck
  Ok(ConnectPacket(packet))
}

///|
pub fn ClientSession::prepare_publish(
  self : ClientSession,
  topic : String,
  payload : Bytes,
  qos? : QoS = AtMostOnce,
  retain? : Bool = false,
  properties? : Array[Property] = [],
) -> Result[Packet, MqttError] {
  match self.require_connected() {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let packet_id = match qos {
    AtMostOnce => None
    AtLeastOnce | ExactlyOnce =>
      match self.allocate_packet_id() {
        Ok(value) => Some(value)
        Err(err) => return Err(err)
      }
  }
  let packet = Packet::PublishPacket({
    topic,
    payload,
    qos,
    retain,
    duplicate: false,
    packet_id,
    properties,
  })
  match packet_id {
    None => ()
    Some(identifier) =>
      self.inflight.push({
        packet_id: identifier,
        stage: if qos == AtLeastOnce {
          AwaitingPubAck
        } else {
          AwaitingPubRec
        },
        packet,
      })
  }
  Ok(packet)
}

///|
pub fn ClientSession::prepare_subscribe(
  self : ClientSession,
  subscriptions : Array[Subscription],
  properties? : Array[Property] = [],
) -> Result[Packet, MqttError] {
  match self.require_connected() {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let packet_id = match self.allocate_packet_id() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let packet = Packet::SubscribePacket({ packet_id, subscriptions, properties, })
  self.inflight.push({ packet_id, stage: AwaitingSubAck, packet, })
  Ok(packet)
}

///|
pub fn ClientSession::prepare_unsubscribe(
  self : ClientSession,
  topic_filters : Array[String],
  properties? : Array[Property] = [],
) -> Result[Packet, MqttError] {
  match self.require_connected() {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let packet_id = match self.allocate_packet_id() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let packet = Packet::UnsubscribePacket({
    packet_id,
    topic_filters,
    properties,
  })
  self.inflight.push({ packet_id, stage: AwaitingUnsubAck, packet, })
  Ok(packet)
}

///|
pub fn ClientSession::prepare_ping(
  self : ClientSession,
) -> Result[Packet, MqttError] {
  match self.require_connected() {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  if self.ping_outstanding {
    return Err(InvalidState("a PINGREQ is already outstanding"))
  }
  self.ping_outstanding = true
  Ok(PingReqPacket)
}

///|
pub fn ClientSession::prepare_disconnect(
  self : ClientSession,
  reason_code? : Byte = 0,
  properties? : Array[Property] = [],
) -> Result[Packet, MqttError] {
  match self.require_connected() {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  self.state = Disconnecting
  Ok(DisconnectPacket({ reason_code, properties, }))
}

///|
pub fn ClientSession::mark_transport_closed(self : ClientSession) -> Unit {
  self.state = Disconnected
  self.ping_outstanding = false
}

///|
fn ClientSession::remove_expected_inflight(
  self : ClientSession,
  packet_id : UInt16,
  expected : InflightStage,
) -> Result[Inflight, MqttError] {
  match self.find_inflight(packet_id) {
    None =>
      Err(ProtocolViolation("acknowledgement has no matching in-flight packet"))
    Some(index) => {
      if self.inflight[index].stage != expected {
        return Err(
          ProtocolViolation("acknowledgement arrived in the wrong QoS stage"),
        )
      }
      Ok(self.inflight.remove(index))
    }
  }
}

///|
fn ClientSession::handle_pub_response(
  self : ClientSession,
  packet : PubResponsePacket,
) -> Result[SessionOutcome, MqttError] {
  let outcome = empty_outcome()
  match packet.kind {
    PubAck =>
      match self.remove_expected_inflight(packet.packet_id, AwaitingPubAck) {
        Err(err) => return Err(err)
        Ok(_) =>
          outcome.events.push(
            AcknowledgedEvent(PubAck, packet.packet_id, packet.reason_code),
          )
      }
    PubRec => {
      match self.remove_expected_inflight(packet.packet_id, AwaitingPubRec) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      let response = Packet::PubResponsePacket({
        kind: PubRel,
        packet_id: packet.packet_id,
        reason_code: 0,
        properties: [],
      })
      self.inflight.push({
        packet_id: packet.packet_id,
        stage: AwaitingPubComp,
        packet: response,
      })
      outcome.responses.push(response)
    }
    PubComp =>
      match self.remove_expected_inflight(packet.packet_id, AwaitingPubComp) {
        Err(err) => return Err(err)
        Ok(_) =>
          outcome.events.push(
            AcknowledgedEvent(PubComp, packet.packet_id, packet.reason_code),
          )
      }
    PubRel => {
      let index = self.incoming_qos2.search_by(publish => {
        publish.packet_id == Some(packet.packet_id)
      })
      let reason_code : Byte = match index {
        Some(found) => {
          let publish = self.incoming_qos2.remove(found)
          outcome.events.push(MessageEvent(publish))
          0
        }
        None => 0x92
      }
      outcome.responses.push(
        PubResponsePacket({
          kind: PubComp,
          packet_id: packet.packet_id,
          reason_code,
          properties: [],
        }),
      )
    }
    _ => return Err(ProtocolViolation("not a publish response packet"))
  }
  Ok(outcome)
}

///|
fn ClientSession::handle_publish(
  self : ClientSession,
  packet : PublishPacket,
) -> SessionOutcome {
  let outcome = empty_outcome()
  match packet.qos {
    AtMostOnce => outcome.events.push(MessageEvent(packet))
    AtLeastOnce =>
      match packet.packet_id {
        Some(identifier) => {
          outcome.events.push(MessageEvent(packet))
          outcome.responses.push(
            PubResponsePacket({
              kind: PubAck,
              packet_id: identifier,
              reason_code: 0,
              properties: [],
            }),
          )
        }
        None => ()
      }
    ExactlyOnce =>
      match packet.packet_id {
        Some(identifier) => {
          if self.incoming_qos2.search_by(publish => {
              publish.packet_id == Some(identifier)
            })
            is None {
            self.incoming_qos2.push(packet)
          }
          outcome.responses.push(
            PubResponsePacket({
              kind: PubRec,
              packet_id: identifier,
              reason_code: 0,
              properties: [],
            }),
          )
        }
        None => ()
      }
  }
  outcome
}

///|
pub fn ClientSession::handle_incoming(
  self : ClientSession,
  packet : Packet,
) -> Result[SessionOutcome, MqttError] {
  match packet {
    ConnAckPacket(value) => {
      if self.state != AwaitingConnAck {
        return Err(InvalidState("unexpected CONNACK"))
      }
      let outcome = empty_outcome()
      if value.reason_code == 0 {
        self.state = Connected
        outcome.events.push(
          ConnectedEvent(value.session_present, value.properties),
        )
      } else {
        self.state = Disconnected
        outcome.events.push(
          DisconnectedEvent(value.reason_code, value.properties),
        )
      }
      Ok(outcome)
    }
    PublishPacket(value) =>
      match self.require_connected() {
        Err(err) => Err(err)
        Ok(_) => Ok(self.handle_publish(value))
      }
    PubResponsePacket(value) =>
      match self.require_connected() {
        Err(err) => Err(err)
        Ok(_) => self.handle_pub_response(value)
      }
    SubAckPacket(value) =>
      match self.remove_expected_inflight(value.packet_id, AwaitingSubAck) {
        Err(err) => Err(err)
        Ok(_) => {
          let outcome = empty_outcome()
          for reason_code in value.reason_codes {
            outcome.events.push(
              AcknowledgedEvent(SubAck, value.packet_id, reason_code),
            )
          }
          Ok(outcome)
        }
      }
    UnsubAckPacket(value) =>
      match self.remove_expected_inflight(value.packet_id, AwaitingUnsubAck) {
        Err(err) => Err(err)
        Ok(_) => {
          let outcome = empty_outcome()
          for reason_code in value.reason_codes {
            outcome.events.push(
              AcknowledgedEvent(UnsubAck, value.packet_id, reason_code),
            )
          }
          Ok(outcome)
        }
      }
    PingRespPacket => {
      if !self.ping_outstanding {
        return Err(ProtocolViolation("unexpected PINGRESP"))
      }
      self.ping_outstanding = false
      Ok(empty_outcome())
    }
    DisconnectPacket(value) => {
      self.state = Disconnected
      self.ping_outstanding = false
      let outcome = empty_outcome()
      outcome.events.push(
        DisconnectedEvent(value.reason_code, value.properties),
      )
      Ok(outcome)
    }
    AuthPacket(value) => {
      let outcome = empty_outcome()
      outcome.events.push(AuthEvent(value))
      Ok(outcome)
    }
    _ => Err(ProtocolViolation("unexpected packet from server"))
  }
}

///|
pub fn ClientSession::retransmit_inflight(
  self : ClientSession,
) -> Array[Packet] {
  let packets : Array[Packet] = []
  for item in self.inflight {
    match item.packet {
      PublishPacket(value) =>
        packets.push(
          PublishPacket({
            topic: value.topic,
            payload: value.payload,
            qos: value.qos,
            retain: value.retain,
            duplicate: true,
            packet_id: value.packet_id,
            properties: value.properties,
          }),
        )
      other => packets.push(other)
    }
  }
  packets
}
