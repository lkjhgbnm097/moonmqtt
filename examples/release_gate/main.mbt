///|
fn main {
  let contract = @mqtt.PublishContract::new(
    "factory-telemetry-v1",
    "factory/+/telemetry",
    max_payload_bytes=16,
    maximum_qos=@mqtt.QoS::AtLeastOnce,
    allow_retain=false,
    required_content_type=Some("application/json"),
    required_user_properties=[
      @mqtt.UserPropertyRequirement::new("purpose", "maintenance"),
      @mqtt.UserPropertyRequirement::new("schema", "telemetry-v1"),
    ],
    require_message_expiry=true,
    maximum_message_expiry_secs=Some(60),
  )
  let accepted : @mqtt.PublishPacket = {
    topic: "factory/line-7/telemetry",
    payload: b"{\"temp\":21}",
    qos: @mqtt.QoS::AtLeastOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(7),
    properties: [
      @mqtt.Property::ContentType("application/json"),
      @mqtt.Property::MessageExpiryInterval(30),
      @mqtt.Property::UserProperty("purpose", "maintenance"),
      @mqtt.Property::UserProperty("schema", "telemetry-v1"),
    ],
  }
  let rejected : @mqtt.PublishPacket = {
    ..accepted,
    retain: true,
    properties: [
      @mqtt.Property::ContentType("text/plain"),
      @mqtt.Property::MessageExpiryInterval(300),
    ],
  }
  println(repr(@mqtt.evaluate_publish_contract(contract, accepted)))
  println(repr(@mqtt.evaluate_publish_contract(contract, rejected)))
}
