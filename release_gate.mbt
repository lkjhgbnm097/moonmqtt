///|
/// A declarative requirement for one MQTT 5 User Property.
///
/// MQTT allows duplicate User Properties. A requirement is satisfied when at
/// least one property has the configured name and value.
pub(all) struct UserPropertyRequirement {
  name : String
  value : String
} derive(Eq, Debug)

///|
pub fn UserPropertyRequirement::new(
  name : String,
  value : String,
) -> UserPropertyRequirement {
  { name, value, }
}

///|
/// An application-level release contract for MQTT 5 PUBLISH messages.
///
/// This is intentionally separate from broker authorization. Brokers decide
/// whether a principal may publish to a topic; a PublishContract decides
/// whether one concrete message is safe and complete enough to leave an
/// application boundary.
pub(all) struct PublishContract {
  name : String
  topic_filter : String
  max_payload_bytes : Int
  maximum_qos : QoS
  allow_retain : Bool
  required_content_type : String?
  required_user_properties : Array[UserPropertyRequirement]
  require_message_expiry : Bool
  maximum_message_expiry_secs : UInt?
  require_response_topic : Bool
  require_correlation_data : Bool
} derive(Eq, Debug)

///|
pub fn PublishContract::new(
  name : String,
  topic_filter : String,
  max_payload_bytes? : Int = 65536,
  maximum_qos? : QoS = AtLeastOnce,
  allow_retain? : Bool = false,
  required_content_type? : String? = None,
  required_user_properties? : Array[UserPropertyRequirement] = [],
  require_message_expiry? : Bool = false,
  maximum_message_expiry_secs? : UInt? = None,
  require_response_topic? : Bool = false,
  require_correlation_data? : Bool = false,
) -> PublishContract {
  {
    name,
    topic_filter,
    max_payload_bytes,
    maximum_qos,
    allow_retain,
    required_content_type,
    required_user_properties,
    require_message_expiry,
    maximum_message_expiry_secs,
    require_response_topic,
    require_correlation_data,
  }
}

///|
/// Stable, machine-readable reasons for rejecting a PUBLISH message.
pub(all) enum ReleaseViolation {
  NoMatchingContract(String)
  PayloadTooLarge(Int, Int)
  QoSAboveContract(QoS, QoS)
  RetainedPublishForbidden
  ContentTypeRequired(String)
  ContentTypeMismatch(String, String)
  UserPropertyRequired(String, String)
  MessageExpiryRequired
  MessageExpiryTooLong(UInt, UInt)
  ResponseTopicRequired
  CorrelationDataRequired
} derive(Eq, Debug)

///|
/// A deterministic release decision. Denials contain every violation found so
/// callers can produce one complete audit event instead of retrying one field
/// at a time.
pub(all) enum ReleaseDecision {
  Permit(String)
  Deny(String?, Array[ReleaseViolation])
} derive(Eq, Debug)

///|
fn content_type(properties : Array[Property]) -> String? {
  for property in properties {
    match property {
      ContentType(value) => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn message_expiry(properties : Array[Property]) -> UInt? {
  for property in properties {
    match property {
      MessageExpiryInterval(value) => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn has_response_topic(properties : Array[Property]) -> Bool {
  for property in properties {
    match property {
      ResponseTopic(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn has_correlation_data(properties : Array[Property]) -> Bool {
  for property in properties {
    match property {
      CorrelationData(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn has_user_property(
  properties : Array[Property],
  requirement : UserPropertyRequirement,
) -> Bool {
  for property in properties {
    match property {
      UserProperty(name, value) =>
        if name == requirement.name && value == requirement.value {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn validate_publish_contract(
  contract : PublishContract,
) -> Result[Unit, MqttError] {
  if contract.name.length() == 0 {
    return Err(ProtocolViolation("publish contract name must not be empty"))
  }
  if contract.max_payload_bytes < 0 {
    return Err(
      ValueOutOfRange(
        "publish contract max payload bytes",
        contract.max_payload_bytes,
      ),
    )
  }
  validate_topic_filter(contract.topic_filter)
}

///|
fn validate_release_input(packet : PublishPacket) -> Result[Unit, MqttError] {
  validate_packet(Packet::PublishPacket(packet))
}

///|
fn evaluate_matching_contract(
  contract : PublishContract,
  packet : PublishPacket,
) -> ReleaseDecision {
  let violations : Array[ReleaseViolation] = []
  if packet.payload.length() > contract.max_payload_bytes {
    violations.push(
      PayloadTooLarge(packet.payload.length(), contract.max_payload_bytes),
    )
  }
  if packet.qos.to_int() > contract.maximum_qos.to_int() {
    violations.push(QoSAboveContract(packet.qos, contract.maximum_qos))
  }
  if packet.retain && !contract.allow_retain {
    violations.push(RetainedPublishForbidden)
  }
  match contract.required_content_type {
    None => ()
    Some(expected) =>
      match content_type(packet.properties) {
        None => violations.push(ContentTypeRequired(expected))
        Some(actual) if actual != expected =>
          violations.push(ContentTypeMismatch(expected, actual))
        Some(_) => ()
      }
  }
  for requirement in contract.required_user_properties {
    if !has_user_property(packet.properties, requirement) {
      violations.push(UserPropertyRequired(requirement.name, requirement.value))
    }
  }
  let expiry = message_expiry(packet.properties)
  if contract.require_message_expiry && expiry is None {
    violations.push(MessageExpiryRequired)
  }
  match (contract.maximum_message_expiry_secs, expiry) {
    (Some(maximum), Some(actual)) if actual > maximum =>
      violations.push(MessageExpiryTooLong(actual, maximum))
    _ => ()
  }
  if contract.require_response_topic && !has_response_topic(packet.properties) {
    violations.push(ResponseTopicRequired)
  }
  if contract.require_correlation_data &&
    !has_correlation_data(packet.properties) {
    violations.push(CorrelationDataRequired)
  }
  if violations.length() == 0 {
    Permit(contract.name)
  } else {
    Deny(Some(contract.name), violations)
  }
}

///|
/// Evaluates a PUBLISH against one named contract.
///
/// Invalid filters are configuration errors and return MqttError. A valid
/// filter that does not match produces a normal, auditable denial.
pub fn evaluate_publish_contract(
  contract : PublishContract,
  packet : PublishPacket,
) -> Result[ReleaseDecision, MqttError] {
  match validate_publish_contract(contract) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match validate_release_input(packet) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match topic_matches(contract.topic_filter, packet.topic) {
    Err(error) => Err(error)
    Ok(false) => Ok(Deny(None, [NoMatchingContract(packet.topic)]))
    Ok(true) => Ok(evaluate_matching_contract(contract, packet))
  }
}

///|
/// Selects the first matching contract and evaluates the message against it.
/// Contract order is therefore an explicit and deterministic precedence rule.
pub fn evaluate_publish_release(
  contracts : Array[PublishContract],
  packet : PublishPacket,
) -> Result[ReleaseDecision, MqttError] {
  match validate_release_input(packet) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  // Validate the entire registry before selecting a contract. Otherwise an
  // earlier broad filter could hide a broken configuration later in the list.
  for contract in contracts {
    match validate_publish_contract(contract) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  for contract in contracts {
    match topic_matches(contract.topic_filter, packet.topic) {
      Err(error) => return Err(error)
      Ok(true) => return Ok(evaluate_matching_contract(contract, packet))
      Ok(false) => ()
    }
  }
  Ok(Deny(None, [NoMatchingContract(packet.topic)]))
}
