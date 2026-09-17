///|
fn Property::identifier(self : Property) -> Int {
  match self {
    PayloadFormatIndicator(_) => 0x01
    MessageExpiryInterval(_) => 0x02
    ContentType(_) => 0x03
    ResponseTopic(_) => 0x08
    CorrelationData(_) => 0x09
    SubscriptionIdentifier(_) => 0x0b
    SessionExpiryInterval(_) => 0x11
    AssignedClientIdentifier(_) => 0x12
    ServerKeepAlive(_) => 0x13
    AuthenticationMethod(_) => 0x15
    AuthenticationData(_) => 0x16
    RequestProblemInformation(_) => 0x17
    WillDelayInterval(_) => 0x18
    RequestResponseInformation(_) => 0x19
    ResponseInformation(_) => 0x1a
    ServerReference(_) => 0x1c
    ReasonString(_) => 0x1f
    ReceiveMaximum(_) => 0x21
    TopicAliasMaximum(_) => 0x22
    TopicAlias(_) => 0x23
    MaximumQoS(_) => 0x24
    RetainAvailable(_) => 0x25
    UserProperty(_, _) => 0x26
    MaximumPacketSize(_) => 0x27
    WildcardSubscriptionAvailable(_) => 0x28
    SubscriptionIdentifierAvailable(_) => 0x29
    SharedSubscriptionAvailable(_) => 0x2a
  }
}

///|
fn validate_boolean_property(
  identifier : Int,
  value : Byte,
) -> Result[Unit, MqttError] {
  if value == 0 || value == 1 {
    Ok(())
  } else {
    Err(InvalidPropertyValue(identifier, "expected byte value 0 or 1"))
  }
}

///|
fn encode_property(
  output : Buffer,
  property : Property,
) -> Result[Unit, MqttError] {
  match encode_variable_byte_integer(property.identifier()) {
    Err(err) => return Err(err)
    Ok(identifier) => output.write_bytes(identifier)
  }
  match property {
    PayloadFormatIndicator(value)
    | RequestProblemInformation(value)
    | RequestResponseInformation(value)
    | RetainAvailable(value)
    | WildcardSubscriptionAvailable(value)
    | SubscriptionIdentifierAvailable(value)
    | SharedSubscriptionAvailable(value) =>
      match validate_boolean_property(property.identifier(), value) {
        Err(err) => return Err(err)
        Ok(_) => output.write_byte(value)
      }
    MaximumQoS(value) => {
      if value.to_int() > 1 {
        return Err(
          InvalidPropertyValue(
            property.identifier(),
            "maximum QoS must be 0 or 1",
          ),
        )
      }
      output.write_byte(value)
    }
    MessageExpiryInterval(value)
    | SessionExpiryInterval(value)
    | WillDelayInterval(value) => output.write_uint_be(value)
    MaximumPacketSize(value) => {
      if value == 0 {
        return Err(
          InvalidPropertyValue(
            property.identifier(),
            "value must be greater than zero",
          ),
        )
      }
      output.write_uint_be(value)
    }
    ServerKeepAlive(value) | TopicAliasMaximum(value) =>
      output.write_uint16_be(value)
    ReceiveMaximum(value) | TopicAlias(value) => {
      if value == 0 {
        return Err(
          InvalidPropertyValue(
            property.identifier(),
            "value must be greater than zero",
          ),
        )
      }
      output.write_uint16_be(value)
    }
    SubscriptionIdentifier(value) => {
      if value <= 0 {
        return Err(
          InvalidPropertyValue(
            property.identifier(),
            "value must be greater than zero",
          ),
        )
      }
      match append_result(output, encode_variable_byte_integer(value)) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    }
    ContentType(value)
    | ResponseTopic(value)
    | AssignedClientIdentifier(value)
    | AuthenticationMethod(value)
    | ResponseInformation(value)
    | ServerReference(value)
    | ReasonString(value) =>
      match write_utf8(output, value) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    CorrelationData(value) | AuthenticationData(value) =>
      match write_binary(output, value) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    UserProperty(name, value) => {
      match write_utf8(output, name) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      match write_utf8(output, value) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}

///|
fn encode_properties(properties : Array[Property]) -> Result[Bytes, MqttError] {
  let body = Buffer()
  for property in properties {
    match encode_property(body, property) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  let result = Buffer()
  match append_result(result, encode_variable_byte_integer(body.length())) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  result.write_bytes(body.to_bytes())
  Ok(result.to_bytes())
}

///|
fn decode_boolean_property(
  reader : Reader,
  identifier : Int,
  make_property : (Byte) -> Property,
) -> Result[Property, MqttError] {
  match reader.read_byte() {
    Err(err) => Err(err)
    Ok(value) =>
      match validate_boolean_property(identifier, value) {
        Err(err) => Err(err)
        Ok(_) => Ok(make_property(value))
      }
  }
}

///|
fn decode_property(reader : Reader) -> Result[Property, MqttError] {
  let identifier = match reader.read_variable_byte_integer() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match identifier {
    0x01 =>
      decode_boolean_property(reader, identifier, fn(value) {
        PayloadFormatIndicator(value)
      })
    0x02 =>
      match reader.read_uint32() {
        Ok(value) => Ok(MessageExpiryInterval(value))
        Err(err) => Err(err)
      }
    0x03 =>
      match reader.read_utf8() {
        Ok(value) => Ok(ContentType(value))
        Err(err) => Err(err)
      }
    0x08 =>
      match reader.read_utf8() {
        Ok(value) => Ok(ResponseTopic(value))
        Err(err) => Err(err)
      }
    0x09 =>
      match reader.read_binary() {
        Ok(value) => Ok(CorrelationData(value))
        Err(err) => Err(err)
      }
    0x0b =>
      match reader.read_variable_byte_integer() {
        Ok(value) if value > 0 => Ok(SubscriptionIdentifier(value))
        Ok(_) =>
          Err(
            InvalidPropertyValue(identifier, "value must be greater than zero"),
          )
        Err(err) => Err(err)
      }
    0x11 =>
      match reader.read_uint32() {
        Ok(value) => Ok(SessionExpiryInterval(value))
        Err(err) => Err(err)
      }
    0x12 =>
      match reader.read_utf8() {
        Ok(value) => Ok(AssignedClientIdentifier(value))
        Err(err) => Err(err)
      }
    0x13 =>
      match reader.read_uint16() {
        Ok(value) => Ok(ServerKeepAlive(value))
        Err(err) => Err(err)
      }
    0x15 =>
      match reader.read_utf8() {
        Ok(value) => Ok(AuthenticationMethod(value))
        Err(err) => Err(err)
      }
    0x16 =>
      match reader.read_binary() {
        Ok(value) => Ok(AuthenticationData(value))
        Err(err) => Err(err)
      }
    0x17 =>
      decode_boolean_property(reader, identifier, fn(value) {
        RequestProblemInformation(value)
      })
    0x18 =>
      match reader.read_uint32() {
        Ok(value) => Ok(WillDelayInterval(value))
        Err(err) => Err(err)
      }
    0x19 =>
      decode_boolean_property(reader, identifier, fn(value) {
        RequestResponseInformation(value)
      })
    0x1a =>
      match reader.read_utf8() {
        Ok(value) => Ok(ResponseInformation(value))
        Err(err) => Err(err)
      }
    0x1c =>
      match reader.read_utf8() {
        Ok(value) => Ok(ServerReference(value))
        Err(err) => Err(err)
      }
    0x1f =>
      match reader.read_utf8() {
        Ok(value) => Ok(ReasonString(value))
        Err(err) => Err(err)
      }
    0x21 =>
      match reader.read_uint16() {
        Ok(value) if value != 0 => Ok(ReceiveMaximum(value))
        Ok(_) =>
          Err(
            InvalidPropertyValue(identifier, "value must be greater than zero"),
          )
        Err(err) => Err(err)
      }
    0x22 =>
      match reader.read_uint16() {
        Ok(value) => Ok(TopicAliasMaximum(value))
        Err(err) => Err(err)
      }
    0x23 =>
      match reader.read_uint16() {
        Ok(value) if value != 0 => Ok(TopicAlias(value))
        Ok(_) =>
          Err(
            InvalidPropertyValue(identifier, "value must be greater than zero"),
          )
        Err(err) => Err(err)
      }
    0x24 =>
      match reader.read_byte() {
        Ok(value) if value.to_int() <= 1 => Ok(MaximumQoS(value))
        Ok(_) =>
          Err(InvalidPropertyValue(identifier, "maximum QoS must be 0 or 1"))
        Err(err) => Err(err)
      }
    0x25 =>
      decode_boolean_property(reader, identifier, fn(value) {
        RetainAvailable(value)
      })
    0x26 =>
      match reader.read_utf8() {
        Err(err) => Err(err)
        Ok(name) =>
          match reader.read_utf8() {
            Ok(value) => Ok(UserProperty(name, value))
            Err(err) => Err(err)
          }
      }
    0x27 =>
      match reader.read_uint32() {
        Ok(value) if value != 0 => Ok(MaximumPacketSize(value))
        Ok(_) =>
          Err(
            InvalidPropertyValue(identifier, "value must be greater than zero"),
          )
        Err(err) => Err(err)
      }
    0x28 =>
      decode_boolean_property(reader, identifier, fn(value) {
        WildcardSubscriptionAvailable(value)
      })
    0x29 =>
      decode_boolean_property(reader, identifier, fn(value) {
        SubscriptionIdentifierAvailable(value)
      })
    0x2a =>
      decode_boolean_property(reader, identifier, fn(value) {
        SharedSubscriptionAvailable(value)
      })
    _ => Err(InvalidProperty(identifier))
  }
}

///|
fn decode_properties(reader : Reader) -> Result[Array[Property], MqttError] {
  let length = match reader.read_variable_byte_integer() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties_reader = match reader.sub_reader(length) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let properties : Array[Property] = []
  while properties_reader.remaining() > 0 {
    match decode_property(properties_reader) {
      Ok(property) => properties.push(property)
      Err(err) => return Err(err)
    }
  }
  Ok(properties)
}
