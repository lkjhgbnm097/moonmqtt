///|
priv struct Reader {
  data : Bytes
  mut offset : Int
}

///|
fn Reader::new(data : Bytes) -> Reader {
  { data, offset: 0, }
}

///|
fn Reader::remaining(self : Reader) -> Int {
  self.data.length() - self.offset
}

///|
fn Reader::position(self : Reader) -> Int {
  self.offset
}

///|
fn Reader::read_byte(self : Reader) -> Result[Byte, MqttError] {
  if self.offset >= self.data.length() {
    return Err(NeedMoreData)
  }
  let value = self.data[self.offset]
  self.offset += 1
  Ok(value)
}

///|
fn Reader::read_uint16(self : Reader) -> Result[UInt16, MqttError] {
  if self.remaining() < 2 {
    return Err(NeedMoreData)
  }
  let high = self.data[self.offset].to_uint16()
  let low = self.data[self.offset + 1].to_uint16()
  self.offset += 2
  Ok((high << 8) | low)
}

///|
fn Reader::read_uint32(self : Reader) -> Result[UInt, MqttError] {
  if self.remaining() < 4 {
    return Err(NeedMoreData)
  }
  let b0 = self.data[self.offset].to_uint()
  let b1 = self.data[self.offset + 1].to_uint()
  let b2 = self.data[self.offset + 2].to_uint()
  let b3 = self.data[self.offset + 3].to_uint()
  self.offset += 4
  Ok((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
}

///|
fn Reader::read_bytes(self : Reader, length : Int) -> Result[Bytes, MqttError] {
  if length < 0 {
    return Err(MalformedPacket("negative byte length"))
  }
  if self.remaining() < length {
    return Err(NeedMoreData)
  }
  let result = Bytes::from_iter(
    self.data[self.offset:self.offset + length].iter(),
  )
  self.offset += length
  Ok(result)
}

///|
fn Reader::read_binary(self : Reader) -> Result[Bytes, MqttError] {
  match self.read_uint16() {
    Err(err) => Err(err)
    Ok(length) => self.read_bytes(length.to_int())
  }
}

///|
fn Reader::read_utf8(self : Reader) -> Result[String, MqttError] {
  match self.read_binary() {
    Err(err) => Err(err)
    Ok(bytes) => decode_mqtt_utf8_impl(bytes)
  }
}

///|
fn is_mqtt_noncharacter(value : Int) -> Bool {
  (value >= 0xfdd0 && value <= 0xfdef) ||
  (value <= 0x10ffff && (value & 0xffff) >= 0xfffe)
}

///|
fn validate_mqtt_scalar(value : Int) -> Result[Char, MqttError] {
  if value == 0 {
    return Err(InvalidUtf8("U+0000 is not permitted in MQTT UTF-8 data"))
  }
  if is_mqtt_noncharacter(value) {
    return Err(InvalidUtf8("Unicode non-character is not permitted"))
  }
  match value.to_char() {
    Some(character) => Ok(character)
    None => Err(InvalidUtf8("invalid Unicode scalar value"))
  }
}

///|
fn continuation_byte(value : Int) -> Bool {
  (value & 0xc0) == 0x80
}

///|
fn decode_mqtt_utf8_impl(data : Bytes) -> Result[String, MqttError] {
  let characters : Array[Char] = []
  let mut index = 0
  while index < data.length() {
    let first = data[index].to_int()
    let mut scalar = 0
    let mut width = 0
    if first <= 0x7f {
      scalar = first
      width = 1
    } else if first >= 0xc2 && first <= 0xdf {
      if index + 1 >= data.length() {
        return Err(InvalidUtf8("truncated two-byte sequence"))
      }
      let b1 = data[index + 1].to_int()
      if !continuation_byte(b1) {
        return Err(InvalidUtf8("invalid UTF-8 continuation byte"))
      }
      scalar = ((first & 0x1f) << 6) | (b1 & 0x3f)
      width = 2
    } else if first >= 0xe0 && first <= 0xef {
      if index + 2 >= data.length() {
        return Err(InvalidUtf8("truncated three-byte sequence"))
      }
      let b1 = data[index + 1].to_int()
      let b2 = data[index + 2].to_int()
      if !continuation_byte(b1) || !continuation_byte(b2) {
        return Err(InvalidUtf8("invalid UTF-8 continuation byte"))
      }
      scalar = ((first & 0x0f) << 12) | ((b1 & 0x3f) << 6) | (b2 & 0x3f)
      if scalar < 0x800 || (scalar >= 0xd800 && scalar <= 0xdfff) {
        return Err(InvalidUtf8("overlong or surrogate UTF-8 sequence"))
      }
      width = 3
    } else if first >= 0xf0 && first <= 0xf4 {
      if index + 3 >= data.length() {
        return Err(InvalidUtf8("truncated four-byte sequence"))
      }
      let b1 = data[index + 1].to_int()
      let b2 = data[index + 2].to_int()
      let b3 = data[index + 3].to_int()
      if !continuation_byte(b1) ||
        !continuation_byte(b2) ||
        !continuation_byte(b3) {
        return Err(InvalidUtf8("invalid UTF-8 continuation byte"))
      }
      scalar = ((first & 0x07) << 18) |
        ((b1 & 0x3f) << 12) |
        ((b2 & 0x3f) << 6) |
        (b3 & 0x3f)
      if scalar < 0x10000 || scalar > 0x10ffff {
        return Err(InvalidUtf8("overlong or out-of-range UTF-8 sequence"))
      }
      width = 4
    } else {
      return Err(InvalidUtf8("invalid UTF-8 leading byte"))
    }
    match validate_mqtt_scalar(scalar) {
      Ok(character) => characters.push(character)
      Err(err) => return Err(err)
    }
    index += width
  }
  Ok(String::from_iter(characters.iter()))
}

///|
fn Reader::read_variable_byte_integer(self : Reader) -> Result[Int, MqttError] {
  let mut multiplier = 1
  let mut value = 0
  let mut bytes_read = 0
  while bytes_read < 4 {
    let encoded = match self.read_byte() {
      Ok(byte) => byte.to_int()
      Err(err) => return Err(err)
    }
    bytes_read += 1
    value += (encoded & 0x7f) * multiplier
    if (encoded & 0x80) == 0 {
      if bytes_read > 1 && encoded == 0 {
        return Err(MalformedPacket("non-minimal variable byte integer"))
      }
      return Ok(value)
    }
    multiplier *= 128
  }
  Err(MalformedPacket("variable byte integer exceeds four bytes"))
}

///|
fn Reader::sub_reader(self : Reader, length : Int) -> Result[Reader, MqttError] {
  match self.read_bytes(length) {
    Ok(bytes) => Ok(Reader::new(bytes))
    Err(err) => Err(err)
  }
}

///|
pub fn encode_variable_byte_integer(value : Int) -> Result[Bytes, MqttError] {
  if value < 0 || value > MAX_VARIABLE_BYTE_INTEGER {
    return Err(ValueOutOfRange("variable byte integer", value))
  }
  let output = Buffer(size_hint=4)
  let mut remaining = value
  while true {
    let mut encoded = remaining % 128
    remaining /= 128
    if remaining > 0 {
      encoded = encoded | 0x80
    }
    output.write_byte(encoded.to_byte())
    if remaining == 0 {
      break
    }
  }
  Ok(output.to_bytes())
}

///|
fn write_binary(output : Buffer, value : Bytes) -> Result[Unit, MqttError] {
  if value.length() > 65535 {
    return Err(ValueOutOfRange("binary data length", value.length()))
  }
  output.write_uint16_be(value.length().to_uint16())
  output.write_bytes(value)
  Ok(())
}

///|
fn write_utf8(output : Buffer, value : String) -> Result[Unit, MqttError] {
  for character in value {
    match validate_mqtt_scalar(character.to_int()) {
      Err(err) => return Err(err)
      Ok(_) => ()
    }
  }
  let encoded = Buffer()
  encoded.write_string_utf8(value)
  write_binary(output, encoded.to_bytes())
}

///|
fn append_result(
  output : Buffer,
  encoded : Result[Bytes, MqttError],
) -> Result[Unit, MqttError] {
  match encoded {
    Ok(bytes) => {
      output.write_bytes(bytes)
      Ok(())
    }
    Err(err) => Err(err)
  }
}
