///|
fn validate_fixed_flags(
  kind : PacketType,
  flags : Int,
) -> Result[Unit, MqttError] {
  let expected = match kind {
    PubRel | Subscribe | Unsubscribe => 0x02
    Publish => return Ok(())
    _ => 0
  }
  if flags == expected {
    Ok(())
  } else {
    Err(InvalidFlags(kind, flags))
  }
}

///|
fn decode_fixed_header(reader : Reader) -> Result[FixedHeader, MqttError] {
  let first = match reader.read_byte() {
    Ok(value) => value.to_int()
    Err(err) => return Err(err)
  }
  let kind = match PacketType::from_code(first >> 4) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let flags = first & 0x0f
  match validate_fixed_flags(kind, flags) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let remaining_length = match reader.read_variable_byte_integer() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok({ packet_type: kind, flags, remaining_length, })
}

///|
fn decode_connect(reader : Reader) -> Result[Packet, MqttError] {
  let protocol_name = match reader.read_utf8() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if protocol_name != "MQTT" {
    return Err(ProtocolViolation("CONNECT protocol name must be MQTT"))
  }
  let level = match reader.read_byte() {
    Ok(value) => value.to_int()
    Err(err) => return Err(err)
  }
  if level != PROTOCOL_LEVEL {
    return Err(ProtocolViolation("unsupported MQTT protocol level"))
  }
  let flags = match reader.read_byte() {
    Ok(value) => value.to_int()
    Err(err) => return Err(err)
  }
  if (flags & 0x01) != 0 {
    return Err(ProtocolViolation("reserved CONNECT flag must be zero"))
  }
  let username_flag = (flags & 0x80) != 0
  let password_flag = (flags & 0x40) != 0
  let will_retain = (flags & 0x20) != 0
  let will_qos_value = (flags >> 3) & 0x03
  let will_flag = (flags & 0x04) != 0
  let clean_start = (flags & 0x02) != 0
  if will_qos_value == 3 {
    return Err(ProtocolViolation("CONNECT Will QoS must not be 3"))
  }
  if !will_flag && (will_retain || will_qos_value != 0) {
    return Err(ProtocolViolation("Will QoS and retain require the Will flag"))
  }
  let keep_alive = match reader.read_uint16() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let client_id = match reader.read_utf8() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let will = if will_flag {
    let will_properties = match decode_properties(reader) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let topic = match reader.read_utf8() {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let payload = match reader.read_binary() {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let qos = match QoS::from_int(will_qos_value) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    Some(WillMessage::{
      topic,
      payload,
      qos,
      retain: will_retain,
      properties: will_properties,
    })
  } else {
    None
  }
  let username = if username_flag {
    match reader.read_utf8() {
      Ok(value) => Some(value)
      Err(err) => return Err(err)
    }
  } else {
    None
  }
  let password = if password_flag {
    match reader.read_binary() {
      Ok(value) => Some(value)
      Err(err) => return Err(err)
    }
  } else {
    None
  }
  Ok(
    ConnectPacket({
      client_id,
      clean_start,
      keep_alive,
      username,
      password,
      will,
      properties,
    }),
  )
}

///|
fn decode_connack(reader : Reader) -> Result[Packet, MqttError] {
  let acknowledge_flags = match reader.read_byte() {
    Ok(value) => value.to_int()
    Err(err) => return Err(err)
  }
  if acknowledge_flags > 1 {
    return Err(ProtocolViolation("invalid CONNACK acknowledge flags"))
  }
  let reason_code = match reader.read_byte() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    ConnAckPacket({
      session_present: acknowledge_flags == 1,
      reason_code,
      properties,
    }),
  )
}

///|
fn decode_publish(reader : Reader, flags : Int) -> Result[Packet, MqttError] {
  let qos_value = (flags >> 1) & 0x03
  if qos_value == 3 {
    return Err(InvalidQoS(qos_value))
  }
  let duplicate = (flags & 0x08) != 0
  let retain = (flags & 0x01) != 0
  if qos_value == 0 && duplicate {
    return Err(ProtocolViolation("DUP must be false for QoS 0 PUBLISH"))
  }
  let qos = match QoS::from_int(qos_value) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let topic = match reader.read_utf8() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let packet_id = if qos == AtMostOnce {
    None
  } else {
    let identifier = match reader.read_uint16() {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    if !packet_identifier_is_valid(identifier) {
      return Err(ProtocolViolation("packet identifier must be non-zero"))
    }
    Some(identifier)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let payload = match reader.read_bytes(reader.remaining()) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    PublishPacket({
      topic,
      payload,
      qos,
      retain,
      duplicate,
      packet_id,
      properties,
    }),
  )
}

///|
fn decode_pub_response(
  reader : Reader,
  kind : PacketType,
) -> Result[Packet, MqttError] {
  let packet_id = match reader.read_uint16() {
    Ok(value) if value != 0 => value
    Ok(_) => return Err(ProtocolViolation("packet identifier must be non-zero"))
    Err(err) => return Err(err)
  }
  if reader.remaining() == 0 {
    return Ok(
      PubResponsePacket({ kind, packet_id, reason_code: 0, properties: [], }),
    )
  }
  let reason_code = match reader.read_byte() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(PubResponsePacket({ kind, packet_id, reason_code, properties, }))
}

///|
fn decode_subscription(reader : Reader) -> Result[Subscription, MqttError] {
  let topic_filter = match reader.read_utf8() {
    Ok(value) if value.length() > 0 => value
    Ok(_) => return Err(ProtocolViolation("topic filter must not be empty"))
    Err(err) => return Err(err)
  }
  let options = match reader.read_byte() {
    Ok(value) => value.to_int()
    Err(err) => return Err(err)
  }
  if (options & 0xc0) != 0 {
    return Err(
      ProtocolViolation("reserved subscription option bits must be zero"),
    )
  }
  let qos_value = options & 0x03
  if qos_value == 3 {
    return Err(InvalidQoS(qos_value))
  }
  let retain_handling = (options >> 4) & 0x03
  if retain_handling == 3 {
    return Err(ProtocolViolation("retain handling must not be 3"))
  }
  let qos = match QoS::from_int(qos_value) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok({
    topic_filter,
    qos,
    no_local: (options & 0x04) != 0,
    retain_as_published: (options & 0x08) != 0,
    retain_handling,
  })
}

///|
fn decode_subscribe(reader : Reader) -> Result[Packet, MqttError] {
  let packet_id = match reader.read_uint16() {
    Ok(value) if value != 0 => value
    Ok(_) => return Err(ProtocolViolation("packet identifier must be non-zero"))
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let subscriptions : Array[Subscription] = []
  while reader.remaining() > 0 {
    match decode_subscription(reader) {
      Ok(value) => subscriptions.push(value)
      Err(err) => return Err(err)
    }
  }
  if subscriptions.is_empty() {
    return Err(
      ProtocolViolation("SUBSCRIBE requires at least one topic filter"),
    )
  }
  Ok(SubscribePacket({ packet_id, subscriptions, properties, }))
}

///|
fn decode_suback(reader : Reader) -> Result[Packet, MqttError] {
  let packet_id = match reader.read_uint16() {
    Ok(value) if value != 0 => value
    Ok(_) => return Err(ProtocolViolation("packet identifier must be non-zero"))
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let reason_codes : Array[Byte] = []
  while reader.remaining() > 0 {
    match reader.read_byte() {
      Ok(value) => reason_codes.push(value)
      Err(err) => return Err(err)
    }
  }
  if reason_codes.is_empty() {
    return Err(ProtocolViolation("SUBACK requires at least one reason code"))
  }
  Ok(SubAckPacket({ packet_id, reason_codes, properties, }))
}

///|
fn decode_unsubscribe(reader : Reader) -> Result[Packet, MqttError] {
  let packet_id = match reader.read_uint16() {
    Ok(value) if value != 0 => value
    Ok(_) => return Err(ProtocolViolation("packet identifier must be non-zero"))
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let topic_filters : Array[String] = []
  while reader.remaining() > 0 {
    match reader.read_utf8() {
      Ok(value) if value.length() > 0 => topic_filters.push(value)
      Ok(_) => return Err(ProtocolViolation("topic filter must not be empty"))
      Err(err) => return Err(err)
    }
  }
  if topic_filters.is_empty() {
    return Err(
      ProtocolViolation("UNSUBSCRIBE requires at least one topic filter"),
    )
  }
  Ok(UnsubscribePacket({ packet_id, topic_filters, properties, }))
}

///|
fn decode_unsuback(reader : Reader) -> Result[Packet, MqttError] {
  let packet_id = match reader.read_uint16() {
    Ok(value) if value != 0 => value
    Ok(_) => return Err(ProtocolViolation("packet identifier must be non-zero"))
    Err(err) => return Err(err)
  }
  let properties = match decode_properties(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let reason_codes : Array[Byte] = []
  while reader.remaining() > 0 {
    match reader.read_byte() {
      Ok(value) => reason_codes.push(value)
      Err(err) => return Err(err)
    }
  }
  if reason_codes.is_empty() {
    return Err(ProtocolViolation("UNSUBACK requires at least one reason code"))
  }
  Ok(UnsubAckPacket({ packet_id, reason_codes, properties, }))
}

///|
fn decode_disconnect(reader : Reader) -> Result[Packet, MqttError] {
  if reader.remaining() == 0 {
    return Ok(DisconnectPacket({ reason_code: 0, properties: [], }))
  }
  let reason_code = match reader.read_byte() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties = if reader.remaining() == 0 {
    []
  } else {
    match decode_properties(reader) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  }
  Ok(DisconnectPacket({ reason_code, properties, }))
}

///|
fn decode_auth(reader : Reader) -> Result[Packet, MqttError] {
  if reader.remaining() == 0 {
    return Ok(AuthPacket({ reason_code: 0, properties: [], }))
  }
  let reason_code = match reader.read_byte() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties = if reader.remaining() == 0 {
    []
  } else {
    match decode_properties(reader) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
  }
  Ok(AuthPacket({ reason_code, properties, }))
}

///|
fn decode_packet_body(
  header : FixedHeader,
  reader : Reader,
) -> Result[Packet, MqttError] {
  match header.packet_type {
    Connect => decode_connect(reader)
    ConnAck => decode_connack(reader)
    Publish => decode_publish(reader, header.flags)
    PubAck | PubRec | PubRel | PubComp =>
      decode_pub_response(reader, header.packet_type)
    Subscribe => decode_subscribe(reader)
    SubAck => decode_suback(reader)
    Unsubscribe => decode_unsubscribe(reader)
    UnsubAck => decode_unsuback(reader)
    PingReq => Ok(PingReqPacket)
    PingResp => Ok(PingRespPacket)
    Disconnect => decode_disconnect(reader)
    Auth => decode_auth(reader)
  }
}

///|
pub fn decode_packet(data : Bytes) -> Result[(Packet, Int), MqttError] {
  let reader = Reader::new(data)
  let header = match decode_fixed_header(reader) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if reader.remaining() < header.remaining_length {
    return Err(NeedMoreData)
  }
  let body = match reader.sub_reader(header.remaining_length) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let packet = match decode_packet_body(header, body) {
    Ok(value) => value
    Err(NeedMoreData) => return Err(MalformedPacket("packet body is truncated"))
    Err(err) => return Err(err)
  }
  if body.remaining() != 0 {
    return Err(MalformedPacket("packet contains trailing bytes"))
  }
  match validate_packet(packet) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  Ok((packet, reader.position()))
}

///|
pub fn decode_exact_packet(data : Bytes) -> Result[Packet, MqttError] {
  match decode_packet(data) {
    Err(err) => Err(err)
    Ok((packet, consumed)) if consumed == data.length() => Ok(packet)
    Ok(_) => Err(MalformedPacket("input contains more than one packet"))
  }
}
