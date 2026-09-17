///|
priv enum PropertyContext {
  ConnectProperties
  WillProperties
  ConnAckProperties
  PublishProperties
  PublishAckProperties
  SubscribeProperties
  SubAckProperties
  UnsubscribeProperties
  UnsubAckProperties
  DisconnectProperties
  AuthProperties
} derive(Eq)

///|
fn PropertyContext::label(self : PropertyContext) -> String {
  match self {
    ConnectProperties => "CONNECT"
    WillProperties => "Will"
    ConnAckProperties => "CONNACK"
    PublishProperties => "PUBLISH"
    PublishAckProperties => "publish acknowledgement"
    SubscribeProperties => "SUBSCRIBE"
    SubAckProperties => "SUBACK"
    UnsubscribeProperties => "UNSUBSCRIBE"
    UnsubAckProperties => "UNSUBACK"
    DisconnectProperties => "DISCONNECT"
    AuthProperties => "AUTH"
  }
}

///|
fn property_allowed(context : PropertyContext, identifier : Int) -> Bool {
  match context {
    ConnectProperties =>
      identifier == 0x11 ||
      identifier == 0x21 ||
      identifier == 0x27 ||
      identifier == 0x22 ||
      identifier == 0x19 ||
      identifier == 0x17 ||
      identifier == 0x26 ||
      identifier == 0x15 ||
      identifier == 0x16
    WillProperties =>
      identifier == 0x18 ||
      identifier == 0x01 ||
      identifier == 0x02 ||
      identifier == 0x03 ||
      identifier == 0x08 ||
      identifier == 0x09 ||
      identifier == 0x26
    ConnAckProperties =>
      identifier == 0x11 ||
      identifier == 0x21 ||
      identifier == 0x24 ||
      identifier == 0x25 ||
      identifier == 0x27 ||
      identifier == 0x12 ||
      identifier == 0x22 ||
      identifier == 0x1f ||
      identifier == 0x26 ||
      identifier == 0x28 ||
      identifier == 0x29 ||
      identifier == 0x2a ||
      identifier == 0x13 ||
      identifier == 0x1a ||
      identifier == 0x1c ||
      identifier == 0x15 ||
      identifier == 0x16
    PublishProperties =>
      identifier == 0x01 ||
      identifier == 0x02 ||
      identifier == 0x23 ||
      identifier == 0x08 ||
      identifier == 0x09 ||
      identifier == 0x26 ||
      identifier == 0x0b ||
      identifier == 0x03
    PublishAckProperties => identifier == 0x1f || identifier == 0x26
    SubscribeProperties => identifier == 0x0b || identifier == 0x26
    SubAckProperties => identifier == 0x1f || identifier == 0x26
    UnsubscribeProperties => identifier == 0x26
    UnsubAckProperties => identifier == 0x1f || identifier == 0x26
    DisconnectProperties =>
      identifier == 0x11 ||
      identifier == 0x1f ||
      identifier == 0x26 ||
      identifier == 0x1c
    AuthProperties =>
      identifier == 0x15 ||
      identifier == 0x16 ||
      identifier == 0x1f ||
      identifier == 0x26
  }
}

///|
fn property_repeatable(context : PropertyContext, identifier : Int) -> Bool {
  identifier == 0x26 || (context == PublishProperties && identifier == 0x0b)
}

///|
fn validate_property_list(
  context : PropertyContext,
  properties : Array[Property],
) -> Result[Unit, MqttError] {
  let seen : Array[Int] = []
  for property in properties {
    let identifier = property.identifier()
    if !property_allowed(context, identifier) {
      return Err(
        InvalidPropertyValue(
          identifier,
          "property is not allowed in \{context.label()}",
        ),
      )
    }
    if !property_repeatable(context, identifier) &&
      seen.search_by(value => value == identifier) is Some(_) {
      return Err(
        InvalidPropertyValue(
          identifier,
          "property must not occur more than once in \{context.label()}",
        ),
      )
    }
    seen.push(identifier)
  }
  Ok(())
}

///|
fn validate_packet_properties(packet : Packet) -> Result[Unit, MqttError] {
  match packet {
    ConnectPacket(value) => {
      match validate_property_list(ConnectProperties, value.properties) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      match value.will {
        Some(will) => validate_property_list(WillProperties, will.properties)
        None => Ok(())
      }
    }
    ConnAckPacket(value) =>
      validate_property_list(ConnAckProperties, value.properties)
    PublishPacket(value) =>
      validate_property_list(PublishProperties, value.properties)
    PubResponsePacket(value) =>
      validate_property_list(PublishAckProperties, value.properties)
    SubscribePacket(value) =>
      validate_property_list(SubscribeProperties, value.properties)
    SubAckPacket(value) =>
      validate_property_list(SubAckProperties, value.properties)
    UnsubscribePacket(value) =>
      validate_property_list(UnsubscribeProperties, value.properties)
    UnsubAckPacket(value) =>
      validate_property_list(UnsubAckProperties, value.properties)
    DisconnectPacket(value) =>
      validate_property_list(DisconnectProperties, value.properties)
    AuthPacket(value) =>
      validate_property_list(AuthProperties, value.properties)
    PingReqPacket | PingRespPacket => Ok(())
  }
}

///|
fn reason_code_allowed(kind : PacketType, reason : Byte) -> Bool {
  let value = reason.to_int()
  match kind {
    ConnAck =>
      value == 0x00 ||
      value == 0x80 ||
      value == 0x81 ||
      value == 0x82 ||
      value == 0x83 ||
      value == 0x84 ||
      value == 0x85 ||
      value == 0x86 ||
      value == 0x87 ||
      value == 0x88 ||
      value == 0x89 ||
      value == 0x8a ||
      value == 0x8c ||
      value == 0x90 ||
      value == 0x95 ||
      value == 0x97 ||
      value == 0x99 ||
      value == 0x9a ||
      value == 0x9b ||
      value == 0x9c ||
      value == 0x9d ||
      value == 0x9f
    PubAck | PubRec =>
      value == 0x00 ||
      value == 0x10 ||
      value == 0x80 ||
      value == 0x83 ||
      value == 0x87 ||
      value == 0x90 ||
      value == 0x91 ||
      value == 0x97 ||
      value == 0x99
    PubRel | PubComp => value == 0x00 || value == 0x92
    SubAck =>
      value == 0x00 ||
      value == 0x01 ||
      value == 0x02 ||
      value == 0x80 ||
      value == 0x83 ||
      value == 0x87 ||
      value == 0x8f ||
      value == 0x91 ||
      value == 0x97 ||
      value == 0x9e ||
      value == 0xa1 ||
      value == 0xa2
    UnsubAck =>
      value == 0x00 ||
      value == 0x11 ||
      value == 0x80 ||
      value == 0x83 ||
      value == 0x87 ||
      value == 0x8f ||
      value == 0x91
    Disconnect =>
      value == 0x00 ||
      value == 0x04 ||
      value == 0x80 ||
      value == 0x81 ||
      value == 0x82 ||
      value == 0x83 ||
      value == 0x87 ||
      value == 0x89 ||
      value == 0x8b ||
      value == 0x8c ||
      value == 0x8d ||
      value == 0x8e ||
      value == 0x8f ||
      value == 0x90 ||
      value == 0x93 ||
      value == 0x94 ||
      value == 0x95 ||
      value == 0x96 ||
      value == 0x97 ||
      value == 0x98 ||
      value == 0x99 ||
      value == 0x9a ||
      value == 0x9b ||
      value == 0x9c ||
      value == 0x9d ||
      value == 0x9e ||
      value == 0x9f ||
      value == 0xa0 ||
      value == 0xa1 ||
      value == 0xa2
    Auth => value == 0x00 || value == 0x18 || value == 0x19
    _ => false
  }
}

///|
fn validate_reason_code(
  kind : PacketType,
  reason : Byte,
) -> Result[Unit, MqttError] {
  if reason_code_allowed(kind, reason) {
    Ok(())
  } else {
    Err(
      ProtocolViolation(
        "reason code 0x\{reason.to_hex()} is not valid for \{kind.name()}",
      ),
    )
  }
}

///|
fn validate_topic_name(
  value : String,
  label : String,
) -> Result[Unit, MqttError] {
  if value.length() == 0 {
    return Err(ProtocolViolation("\{label} must not be empty"))
  }
  if value.contains_any(chars="#+") {
    return Err(ProtocolViolation("\{label} must not contain wildcards"))
  }
  Ok(())
}

///|
fn validate_topic_filter(value : String) -> Result[Unit, MqttError] {
  if value.length() == 0 {
    return Err(ProtocolViolation("topic filter must not be empty"))
  }
  if value.has_prefix("$share/") {
    let shared = value.strip_prefix("$share/").unwrap()
    match shared.split_once("/") {
      None =>
        return Err(
          ProtocolViolation(
            "shared subscription requires a group and a topic filter",
          ),
        )
      Some((group, filter)) => {
        if group.length() == 0 || group.contains_any(chars="#+") {
          return Err(
            ProtocolViolation(
              "shared subscription group must be non-empty and contain no wildcards",
            ),
          )
        }
        if filter.length() == 0 {
          return Err(
            ProtocolViolation("shared subscription topic filter is empty"),
          )
        }
      }
    }
  }
  let characters : Array[Char] = []
  for character in value {
    characters.push(character)
  }
  for index, character in characters {
    if character == '#' {
      let occupies_level = index == 0 || characters[index - 1] == '/'
      if !occupies_level || index != characters.length() - 1 {
        return Err(
          ProtocolViolation(
            "multi-level wildcard must occupy the final topic level",
          ),
        )
      }
    } else if character == '+' {
      let starts_level = index == 0 || characters[index - 1] == '/'
      let ends_level = index == characters.length() - 1 ||
        characters[index + 1] == '/'
      if !starts_level || !ends_level {
        return Err(
          ProtocolViolation(
            "single-level wildcard must occupy an entire topic level",
          ),
        )
      }
    }
  }
  Ok(())
}

///|
fn property_present(properties : Array[Property], identifier : Int) -> Bool {
  properties.search_by(property => property.identifier() == identifier)
  is Some(_)
}

///|
fn validate_authentication_properties(
  properties : Array[Property],
) -> Result[Unit, MqttError] {
  if property_present(properties, 0x16) && !property_present(properties, 0x15) {
    Err(
      ProtocolViolation("Authentication Data requires an Authentication Method"),
    )
  } else {
    Ok(())
  }
}

///|
fn validate_packet_semantics(packet : Packet) -> Result[Unit, MqttError] {
  match packet {
    ConnectPacket(value) => {
      if value.client_id.length() == 0 && !value.clean_start {
        return Err(
          ProtocolViolation(
            "an empty Client Identifier requires Clean Start to be true",
          ),
        )
      }
      match value.will {
        Some(will) =>
          match validate_topic_name(will.topic, "Will Topic") {
            Err(err) => return Err(err)
            Ok(_) => ()
          }
        None => ()
      }
      validate_authentication_properties(value.properties)
    }
    ConnAckPacket(value) => {
      match validate_reason_code(ConnAck, value.reason_code) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      if value.reason_code != 0 && value.session_present {
        return Err(
          ProtocolViolation(
            "CONNACK Session Present must be false when connection is refused",
          ),
        )
      }
      validate_authentication_properties(value.properties)
    }
    PublishPacket(value) => {
      if value.topic.length() == 0 {
        if !property_present(value.properties, 0x23) {
          return Err(
            ProtocolViolation(
              "an empty PUBLISH Topic Name requires a Topic Alias",
            ),
          )
        }
      } else {
        match validate_topic_name(value.topic, "PUBLISH Topic Name") {
          Err(err) => return Err(err)
          Ok(_) => ()
        }
      }
      for property in value.properties {
        match property {
          ResponseTopic(topic) =>
            match validate_topic_name(topic, "Response Topic") {
              Err(err) => return Err(err)
              Ok(_) => ()
            }
          _ => ()
        }
      }
      Ok(())
    }
    PubResponsePacket(value) =>
      validate_reason_code(value.kind, value.reason_code)
    SubscribePacket(value) => {
      for subscription in value.subscriptions {
        match validate_topic_filter(subscription.topic_filter) {
          Err(err) => return Err(err)
          Ok(_) => ()
        }
        if subscription.no_local &&
          subscription.topic_filter.has_prefix("$share/") {
          return Err(
            ProtocolViolation(
              "No Local must be false for a shared subscription",
            ),
          )
        }
      }
      Ok(())
    }
    SubAckPacket(value) => {
      for reason_code in value.reason_codes {
        match validate_reason_code(SubAck, reason_code) {
          Err(err) => return Err(err)
          Ok(_) => ()
        }
      }
      Ok(())
    }
    UnsubscribePacket(value) => {
      for topic_filter in value.topic_filters {
        match validate_topic_filter(topic_filter) {
          Err(err) => return Err(err)
          Ok(_) => ()
        }
      }
      Ok(())
    }
    UnsubAckPacket(value) => {
      for reason_code in value.reason_codes {
        match validate_reason_code(UnsubAck, reason_code) {
          Err(err) => return Err(err)
          Ok(_) => ()
        }
      }
      Ok(())
    }
    DisconnectPacket(value) =>
      validate_reason_code(Disconnect, value.reason_code)
    AuthPacket(value) => {
      match validate_reason_code(Auth, value.reason_code) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
      validate_authentication_properties(value.properties)
    }
    PingReqPacket | PingRespPacket => Ok(())
  }
}

///|
fn validate_packet(packet : Packet) -> Result[Unit, MqttError] {
  match validate_packet_properties(packet) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  validate_packet_semantics(packet)
}
