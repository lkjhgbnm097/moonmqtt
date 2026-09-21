///|
fn telemetry_contract() -> @moonmqtt.PublishContract {
  @moonmqtt.PublishContract::new(
    "factory-telemetry-v1",
    "factory/+/telemetry",
    max_payload_bytes=16,
    maximum_qos=@moonmqtt.QoS::AtLeastOnce,
    allow_retain=false,
    required_content_type=Some("application/json"),
    required_user_properties=[
      @moonmqtt.UserPropertyRequirement::new("purpose", "maintenance"),
      @moonmqtt.UserPropertyRequirement::new("schema", "telemetry-v1"),
    ],
    require_message_expiry=true,
    maximum_message_expiry_secs=Some(60),
  )
}

///|
test "release gate permits a purpose-bound telemetry message" {
  let packet : @moonmqtt.PublishPacket = {
    topic: "factory/line-7/telemetry",
    payload: b"{\"temp\":21}",
    qos: @moonmqtt.QoS::AtLeastOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(7),
    properties: [
      @moonmqtt.Property::PayloadFormatIndicator(1),
      @moonmqtt.Property::ContentType("application/json"),
      @moonmqtt.Property::MessageExpiryInterval(30),
      @moonmqtt.Property::UserProperty("purpose", "maintenance"),
      @moonmqtt.Property::UserProperty("schema", "telemetry-v1"),
    ],
  }
  assert_eq(
    @moonmqtt.evaluate_publish_contract(telemetry_contract(), packet),
    Ok(@moonmqtt.ReleaseDecision::Permit("factory-telemetry-v1")),
  )
}

///|
test "release gate reports every contract violation in stable order" {
  let packet : @moonmqtt.PublishPacket = {
    topic: "factory/line-7/telemetry",
    payload: b"payload-is-longer-than-sixteen-bytes",
    qos: @moonmqtt.QoS::ExactlyOnce,
    retain: true,
    duplicate: false,
    packet_id: Some(8),
    properties: [
      @moonmqtt.Property::ContentType("text/plain"),
      @moonmqtt.Property::MessageExpiryInterval(120),
      @moonmqtt.Property::UserProperty("purpose", "analytics"),
    ],
  }
  assert_eq(
    @moonmqtt.evaluate_publish_contract(telemetry_contract(), packet),
    Ok(
      @moonmqtt.ReleaseDecision::Deny(Some("factory-telemetry-v1"), [
        @moonmqtt.ReleaseViolation::PayloadTooLarge(packet.payload.length(), 16),
        @moonmqtt.ReleaseViolation::QoSAboveContract(
          @moonmqtt.QoS::ExactlyOnce,
          @moonmqtt.QoS::AtLeastOnce,
        ),
        @moonmqtt.ReleaseViolation::RetainedPublishForbidden,
        @moonmqtt.ReleaseViolation::ContentTypeMismatch(
          "application/json", "text/plain",
        ),
        @moonmqtt.ReleaseViolation::UserPropertyRequired(
          "purpose", "maintenance",
        ),
        @moonmqtt.ReleaseViolation::UserPropertyRequired(
          "schema", "telemetry-v1",
        ),
        @moonmqtt.ReleaseViolation::MessageExpiryTooLong(120, 60),
      ]),
    ),
  )
}

///|
test "release gate denies topics without a contract" {
  let packet = @moonmqtt.PublishPacket::new(
    "personal/alice/location", b"secret",
  )
  assert_eq(
    @moonmqtt.evaluate_publish_release([telemetry_contract()], packet),
    Ok(
      @moonmqtt.ReleaseDecision::Deny(None, [
        @moonmqtt.ReleaseViolation::NoMatchingContract(
          "personal/alice/location",
        ),
      ]),
    ),
  )
}

///|
test "request contracts require response routing and correlation" {
  let contract = @moonmqtt.PublishContract::new(
    "device-command-v1",
    "factory/+/command",
    require_response_topic=true,
    require_correlation_data=true,
  )
  let packet = @moonmqtt.PublishPacket::new("factory/line-7/command", b"stop")
  assert_eq(
    @moonmqtt.evaluate_publish_contract(contract, packet),
    Ok(
      @moonmqtt.ReleaseDecision::Deny(Some("device-command-v1"), [
        @moonmqtt.ReleaseViolation::ResponseTopicRequired,
        @moonmqtt.ReleaseViolation::CorrelationDataRequired,
      ]),
    ),
  )
}

///|
test "release gate rejects invalid contract configuration" {
  let invalid = @moonmqtt.PublishContract::new(
    "broken",
    "factory/#/invalid",
    max_payload_bytes=-1,
  )
  match
    @moonmqtt.evaluate_publish_contract(
      invalid,
      @moonmqtt.PublishPacket::new("factory/line-7/telemetry", b"x"),
    ) {
    Err(@moonmqtt.MqttError::ValueOutOfRange(_, -1)) => ()
    _ => fail("invalid contract was not rejected")
  }
}

///|
test "release registry validates contracts hidden by an earlier match" {
  let broad = @moonmqtt.PublishContract::new("broad", "factory/#")
  let hidden_invalid = @moonmqtt.PublishContract::new(
    "hidden-invalid", "factory/#/invalid",
  )
  match
    @moonmqtt.evaluate_publish_release(
      [broad, hidden_invalid],
      @moonmqtt.PublishPacket::new("factory/line-7/telemetry", b"x"),
    ) {
    Err(@moonmqtt.MqttError::ProtocolViolation(_)) => ()
    _ => fail("hidden invalid contract was not rejected")
  }
}
