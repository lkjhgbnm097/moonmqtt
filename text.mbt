///|
pub fn PacketType::name(self : PacketType) -> String {
  match self {
    Connect => "CONNECT"
    ConnAck => "CONNACK"
    Publish => "PUBLISH"
    PubAck => "PUBACK"
    PubRec => "PUBREC"
    PubRel => "PUBREL"
    PubComp => "PUBCOMP"
    Subscribe => "SUBSCRIBE"
    SubAck => "SUBACK"
    Unsubscribe => "UNSUBSCRIBE"
    UnsubAck => "UNSUBACK"
    PingReq => "PINGREQ"
    PingResp => "PINGRESP"
    Disconnect => "DISCONNECT"
    Auth => "AUTH"
  }
}

///|
pub fn MqttError::message(self : MqttError) -> String {
  match self {
    NeedMoreData => "more bytes are required to decode the packet"
    MalformedPacket(detail) => "malformed packet: \{detail}"
    InvalidPacketType(value) => "invalid MQTT packet type: \{value}"
    InvalidFlags(kind, flags) =>
      "invalid flags 0x\{flags.to_byte().to_hex()} for \{kind.name()}"
    InvalidQoS(value) => "invalid QoS value: \{value}"
    InvalidProperty(identifier) =>
      "unknown MQTT 5 property: 0x\{identifier.to_byte().to_hex()}"
    InvalidPropertyValue(identifier, detail) =>
      "invalid value for property 0x\{identifier.to_byte().to_hex()}: \{detail}"
    InvalidUtf8(detail) => "invalid MQTT UTF-8 data: \{detail}"
    ValueOutOfRange(name, value) => "\{name} is out of range: \{value}"
    ProtocolViolation(detail) => "MQTT protocol violation: \{detail}"
    InvalidState(detail) => "invalid client state: \{detail}"
    ConnectionRejected(reason, _) =>
      "broker rejected CONNECT with reason code 0x\{reason.to_hex()}"
  }
}

///|
pub fn encode_mqtt_utf8(value : String) -> Result[Bytes, MqttError] {
  let output = Buffer()
  for character in value {
    match validate_mqtt_scalar(character.to_int()) {
      Err(err) => return Err(err)
      Ok(_) => output.write_char_utf8(character)
    }
  }
  Ok(output.to_bytes())
}

///|
pub fn decode_mqtt_utf8(data : Bytes) -> Result[String, MqttError] {
  decode_mqtt_utf8_impl(data)
}

///|
fn hex_nibble(character : Char) -> Int? {
  let value = character.to_int()
  if value >= '0'.to_int() && value <= '9'.to_int() {
    Some(value - '0'.to_int())
  } else if value >= 'a'.to_int() && value <= 'f'.to_int() {
    Some(value - 'a'.to_int() + 10)
  } else if value >= 'A'.to_int() && value <= 'F'.to_int() {
    Some(value - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
pub fn decode_hex(value : String) -> Result[Bytes, MqttError] {
  let output : Array[Byte] = []
  let mut high : Int? = None
  for character in value {
    if character == ' ' ||
      character == ':' ||
      character == '_' ||
      character == '-' {
      continue
    }
    let nibble = match hex_nibble(character) {
      Some(value) => value
      None =>
        return Err(MalformedPacket("hex input contains a non-hex character"))
    }
    match high {
      None => high = Some(nibble)
      Some(prefix) => {
        output.push(((prefix << 4) | nibble).to_byte())
        high = None
      }
    }
  }
  if high is Some(_) {
    return Err(
      MalformedPacket("hex input must contain an even number of digits"),
    )
  }
  Ok(Bytes::from_iter(output.iter()))
}

///|
pub fn encode_hex(value : Bytes) -> String {
  let output = Buffer(size_hint=value.length() * 3)
  let mut first = true
  for byte in value {
    if first {
      first = false
    } else {
      output.write_byte(b' ')
    }
    let encoded = byte.to_hex()
    if encoded.length() == 1 {
      output.write_byte(b'0')
    }
    output.write_string_utf8(encoded)
  }
  match decode_mqtt_utf8_impl(output.to_bytes()) {
    Ok(value) => value
    Err(_) => ""
  }
}
