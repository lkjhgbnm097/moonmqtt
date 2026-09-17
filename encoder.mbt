///|
fn packet_type_of(packet : Packet) -> PacketType {
  match packet {
    ConnectPacket(_) => Connect
    ConnAckPacket(_) => ConnAck
    PublishPacket(_) => Publish
    PubResponsePacket(value) => value.kind
    SubscribePacket(_) => Subscribe
    SubAckPacket(_) => SubAck
    UnsubscribePacket(_) => Unsubscribe
    UnsubAckPacket(_) => UnsubAck
    PingReqPacket => PingReq
    PingRespPacket => PingResp
    DisconnectPacket(_) => Disconnect
    AuthPacket(_) => Auth
  }
}

///|
fn packet_flags(packet : Packet) -> Int {
  match packet {
    PublishPacket(value) => {
      let duplicate = if value.duplicate { 0x08 } else { 0 }
      let retain = if value.retain { 0x01 } else { 0 }
      duplicate | (value.qos.to_int() << 1) | retain
    }
    PubResponsePacket(value) if value.kind == PubRel => 0x02
    SubscribePacket(_) | UnsubscribePacket(_) => 0x02
    _ => 0
  }
}

///|
fn packet_identifier_is_valid(value : UInt16) -> Bool {
  value != 0
}

///|
fn write_packet_identifier(
  output : Buffer,
  value : UInt16,
) -> Result[Unit, MqttError] {
  if !packet_identifier_is_valid(value) {
    return Err(ProtocolViolation("packet identifier must be non-zero"))
  }
  output.write_uint16_be(value)
  Ok(())
}

///|
fn encode_connect(packet : ConnectPacket) -> Result[Bytes, MqttError] {
  let body = Buffer()
  match write_utf8(body, "MQTT") {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  body.write_byte(PROTOCOL_LEVEL.to_byte())
  let mut flags = if packet.clean_start { 0x02 } else { 0 }
  match packet.will {
    Some(will) => {
      flags = flags | 0x04 | (will.qos.to_int() << 3)
      if will.retain {
        flags = flags | 0x20
      }
    }
    None => ()
  }
  if packet.password is Some(_) {
    flags = flags | 0x40
  }
  if packet.username is Some(_) {
    flags = flags | 0x80
  }
  body.write_byte(flags.to_byte())
  body.write_uint16_be(packet.keep_alive)
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match write_utf8(body, packet.client_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match packet.will {
    Some(will) => {
      match append_result(body, encode_properties(will.properties)) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      match write_utf8(body, will.topic) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      match write_binary(body, will.payload) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    }
    None => ()
  }
  match packet.username {
    Some(username) =>
      match write_utf8(body, username) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    None => ()
  }
  match packet.password {
    Some(password) =>
      match write_binary(body, password) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    None => ()
  }
  Ok(body.to_bytes())
}

///|
fn encode_connack(packet : ConnAckPacket) -> Result[Bytes, MqttError] {
  let body = Buffer()
  body.write_byte(if packet.session_present { 1 } else { 0 })
  body.write_byte(packet.reason_code)
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => Err(err)
    Ok(_) => Ok(body.to_bytes())
  }
}

///|
fn encode_publish(packet : PublishPacket) -> Result[Bytes, MqttError] {
  if packet.qos == AtMostOnce && packet.duplicate {
    return Err(ProtocolViolation("DUP must be false for QoS 0 PUBLISH"))
  }
  let body = Buffer()
  match write_utf8(body, packet.topic) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match packet.qos {
    AtMostOnce =>
      if packet.packet_id is Some(_) {
        return Err(
          ProtocolViolation(
            "QoS 0 PUBLISH must not contain a packet identifier",
          ),
        )
      }
    AtLeastOnce | ExactlyOnce =>
      match packet.packet_id {
        None =>
          return Err(
            ProtocolViolation("QoS 1/2 PUBLISH requires a packet identifier"),
          )
        Some(identifier) =>
          match write_packet_identifier(body, identifier) {
            Err(err) => return Err(err)
            Ok(_) => ()
          }
      }
  }
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  body.write_bytes(packet.payload)
  Ok(body.to_bytes())
}

///|
fn is_pub_response(kind : PacketType) -> Bool {
  kind == PubAck || kind == PubRec || kind == PubRel || kind == PubComp
}

///|
fn encode_pub_response(packet : PubResponsePacket) -> Result[Bytes, MqttError] {
  if !is_pub_response(packet.kind) {
    return Err(ProtocolViolation("invalid publish response packet type"))
  }
  let body = Buffer()
  match write_packet_identifier(body, packet.packet_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  if packet.reason_code != 0 || packet.properties.length() > 0 {
    body.write_byte(packet.reason_code)
    match append_result(body, encode_properties(packet.properties)) {
      Err(err) => return Err(err)
      Ok(_) => ()
    }
  }
  Ok(body.to_bytes())
}

///|
fn encode_subscription_options(value : Subscription) -> Result[Byte, MqttError] {
  if value.retain_handling < 0 || value.retain_handling > 2 {
    return Err(ProtocolViolation("retain handling must be between 0 and 2"))
  }
  let mut options = value.qos.to_int()
  if value.no_local {
    options = options | 0x04
  }
  if value.retain_as_published {
    options = options | 0x08
  }
  options = options | (value.retain_handling << 4)
  Ok(options.to_byte())
}

///|
fn encode_subscribe(packet : SubscribePacket) -> Result[Bytes, MqttError] {
  if packet.subscriptions.is_empty() {
    return Err(
      ProtocolViolation("SUBSCRIBE requires at least one topic filter"),
    )
  }
  let body = Buffer()
  match write_packet_identifier(body, packet.packet_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  for subscription in packet.subscriptions {
    if subscription.topic_filter.length() == 0 {
      return Err(ProtocolViolation("topic filter must not be empty"))
    }
    match write_utf8(body, subscription.topic_filter) {
      Err(err) => return Err(err)
      Ok(_) => ()
    }
    match encode_subscription_options(subscription) {
      Ok(options) => body.write_byte(options)
      Err(err) => return Err(err)
    }
  }
  Ok(body.to_bytes())
}

///|
fn encode_suback(packet : SubAckPacket) -> Result[Bytes, MqttError] {
  if packet.reason_codes.is_empty() {
    return Err(ProtocolViolation("SUBACK requires at least one reason code"))
  }
  let body = Buffer()
  match write_packet_identifier(body, packet.packet_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  for reason in packet.reason_codes {
    body.write_byte(reason)
  }
  Ok(body.to_bytes())
}

///|
fn encode_unsubscribe(packet : UnsubscribePacket) -> Result[Bytes, MqttError] {
  if packet.topic_filters.is_empty() {
    return Err(
      ProtocolViolation("UNSUBSCRIBE requires at least one topic filter"),
    )
  }
  let body = Buffer()
  match write_packet_identifier(body, packet.packet_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  for topic_filter in packet.topic_filters {
    if topic_filter.length() == 0 {
      return Err(ProtocolViolation("topic filter must not be empty"))
    }
    match write_utf8(body, topic_filter) {
      Err(err) => return Err(err)
      Ok(_) => ()
    }
  }
  Ok(body.to_bytes())
}

///|
fn encode_unsuback(packet : UnsubAckPacket) -> Result[Bytes, MqttError] {
  if packet.reason_codes.is_empty() {
    return Err(ProtocolViolation("UNSUBACK requires at least one reason code"))
  }
  let body = Buffer()
  match write_packet_identifier(body, packet.packet_id) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  for reason in packet.reason_codes {
    body.write_byte(reason)
  }
  Ok(body.to_bytes())
}

///|
fn encode_disconnect(packet : DisconnectPacket) -> Result[Bytes, MqttError] {
  if packet.reason_code == 0 && packet.properties.is_empty() {
    return Ok(b"")
  }
  let body = Buffer()
  body.write_byte(packet.reason_code)
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => Err(err)
    Ok(_) => Ok(body.to_bytes())
  }
}

///|
fn encode_auth(packet : AuthPacket) -> Result[Bytes, MqttError] {
  if packet.reason_code == 0 && packet.properties.is_empty() {
    return Ok(b"")
  }
  let body = Buffer()
  body.write_byte(packet.reason_code)
  match append_result(body, encode_properties(packet.properties)) {
    Err(err) => Err(err)
    Ok(_) => Ok(body.to_bytes())
  }
}

///|
fn encode_packet_body(packet : Packet) -> Result[Bytes, MqttError] {
  match validate_packet(packet) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match packet {
    ConnectPacket(value) => encode_connect(value)
    ConnAckPacket(value) => encode_connack(value)
    PublishPacket(value) => encode_publish(value)
    PubResponsePacket(value) => encode_pub_response(value)
    SubscribePacket(value) => encode_subscribe(value)
    SubAckPacket(value) => encode_suback(value)
    UnsubscribePacket(value) => encode_unsubscribe(value)
    UnsubAckPacket(value) => encode_unsuback(value)
    PingReqPacket | PingRespPacket => Ok(b"")
    DisconnectPacket(value) => encode_disconnect(value)
    AuthPacket(value) => encode_auth(value)
  }
}

///|
pub fn encode_packet(packet : Packet) -> Result[Bytes, MqttError] {
  let body = match encode_packet_body(packet) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let packet_type = packet_type_of(packet)
  let first = ((packet_type.code() << 4) | packet_flags(packet)).to_byte()
  let output = Buffer(size_hint=body.length() + 5)
  output.write_byte(first)
  match append_result(output, encode_variable_byte_integer(body.length())) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  output.write_bytes(body)
  Ok(output.to_bytes())
}
