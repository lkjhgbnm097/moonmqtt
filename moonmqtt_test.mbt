///|
test "MQTT variable byte integer reference vectors" {
  assert_eq(@moonmqtt.encode_variable_byte_integer(0), Ok(b"\x00"))
  assert_eq(@moonmqtt.encode_variable_byte_integer(127), Ok(b"\x7f"))
  assert_eq(@moonmqtt.encode_variable_byte_integer(128), Ok(b"\x80\x01"))
  assert_eq(@moonmqtt.encode_variable_byte_integer(16383), Ok(b"\xff\x7f"))
  assert_eq(
    @moonmqtt.encode_variable_byte_integer(2097152),
    Ok(b"\x80\x80\x80\x01"),
  )
  assert_eq(
    @moonmqtt.encode_variable_byte_integer(268435455),
    Ok(b"\xff\xff\xff\x7f"),
  )
}

///|
test "minimal MQTT 5 CONNECT vector" {
  let packet = @moonmqtt.Packet::ConnectPacket(
    @moonmqtt.ConnectPacket::new("a"),
  )
  let expected = b"\x10\x0e\x00\x04MQTT\x05\x02\x00\x3c\x00\x00\x01a"
  assert_eq(@moonmqtt.encode_packet(packet), Ok(expected))
  assert_eq(@moonmqtt.decode_exact_packet(expected), Ok(packet))
}

///|
test "CONNECT with Will credentials and properties round-trips" {
  let packet = @moonmqtt.Packet::ConnectPacket({
    client_id: "sensor-7",
    clean_start: false,
    keep_alive: 30,
    username: Some("device"),
    password: Some(b"secret"),
    will: Some({
      topic: "devices/sensor-7/status",
      payload: b"offline",
      qos: @moonmqtt.QoS::AtLeastOnce,
      retain: true,
      properties: [@moonmqtt.Property::ContentType("text/plain")],
    }),
    properties: [
      @moonmqtt.Property::SessionExpiryInterval(300),
      @moonmqtt.Property::ReceiveMaximum(32),
      @moonmqtt.Property::UserProperty("site", "lab-a"),
    ],
  })
  let encoded = @moonmqtt.encode_packet(packet)
  match encoded {
    Err(_) => fail("unexpected CONNECT encode error")
    Ok(bytes) => assert_eq(@moonmqtt.decode_exact_packet(bytes), Ok(packet))
  }
}

///|
test "QoS 0 PUBLISH reference vector" {
  let packet = @moonmqtt.Packet::PublishPacket(
    @moonmqtt.PublishPacket::new("a", b"hi"),
  )
  let expected = b"\x30\x06\x00\x01a\x00hi"
  assert_eq(@moonmqtt.encode_packet(packet), Ok(expected))
  assert_eq(@moonmqtt.decode_exact_packet(expected), Ok(packet))
}

///|
test "QoS 1 PUBLISH with typed properties round-trips" {
  let packet = @moonmqtt.Packet::PublishPacket({
    topic: "factory/line-1/temperature",
    payload: b"21.8",
    qos: @moonmqtt.QoS::AtLeastOnce,
    retain: true,
    duplicate: false,
    packet_id: Some(42),
    properties: [
      @moonmqtt.Property::PayloadFormatIndicator(1),
      @moonmqtt.Property::MessageExpiryInterval(60),
      @moonmqtt.Property::ContentType("text/plain"),
      @moonmqtt.Property::UserProperty("unit", "Cel"),
    ],
  })
  let encoded = @moonmqtt.encode_packet(packet)
  match encoded {
    Err(_) => fail("unexpected PUBLISH encode error")
    Ok(bytes) => assert_eq(@moonmqtt.decode_exact_packet(bytes), Ok(packet))
  }
}

///|
test "SUBSCRIBE reference vector" {
  let packet = @moonmqtt.Packet::SubscribePacket({
    packet_id: 1,
    subscriptions: [@moonmqtt.Subscription::new("a")],
    properties: [],
  })
  let expected = b"\x82\x07\x00\x01\x00\x00\x01a\x00"
  assert_eq(@moonmqtt.encode_packet(packet), Ok(expected))
  assert_eq(@moonmqtt.decode_exact_packet(expected), Ok(packet))
}

///|
test "acknowledgement and control packets round-trip" {
  let packets : Array[@moonmqtt.Packet] = [
    @moonmqtt.Packet::ConnAckPacket({
      session_present: false,
      reason_code: 0,
      properties: [@moonmqtt.Property::ReceiveMaximum(10)],
    }),
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubAck,
      packet_id: 7,
      reason_code: 0,
      properties: [],
    }),
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubRel,
      packet_id: 8,
      reason_code: 0,
      properties: [],
    }),
    @moonmqtt.Packet::SubAckPacket({
      packet_id: 9,
      reason_codes: [0, 1],
      properties: [],
    }),
    @moonmqtt.Packet::UnsubscribePacket({
      packet_id: 10,
      topic_filters: ["a/+", "b/#"],
      properties: [],
    }),
    @moonmqtt.Packet::UnsubAckPacket({
      packet_id: 10,
      reason_codes: [0, 17],
      properties: [],
    }),
    @moonmqtt.Packet::PingReqPacket,
    @moonmqtt.Packet::PingRespPacket,
    @moonmqtt.Packet::DisconnectPacket({ reason_code: 0, properties: [], }),
    @moonmqtt.Packet::AuthPacket({
      reason_code: 24,
      properties: [@moonmqtt.Property::AuthenticationMethod("token")],
    }),
  ]
  for packet in packets {
    let encoded = @moonmqtt.encode_packet(packet)
    match encoded {
      Err(_) => fail("unexpected control packet encode error")
      Ok(bytes) => assert_eq(@moonmqtt.decode_exact_packet(bytes), Ok(packet))
    }
  }
}

///|
test "stream decode reports consumed bytes" {
  assert_eq(
    @moonmqtt.decode_packet(b"\xc0\x00\xd0\x00"),
    Ok((@moonmqtt.Packet::PingReqPacket, 2)),
  )
}

///|
test "decoder rejects malformed packets" {
  assert_eq(
    @moonmqtt.decode_exact_packet(b"\xc1\x00"),
    Err(@moonmqtt.MqttError::InvalidFlags(@moonmqtt.PacketType::PingReq, 1)),
  )
  assert_eq(
    @moonmqtt.decode_exact_packet(b"\xc0\x02\x00"),
    Err(@moonmqtt.MqttError::NeedMoreData),
  )
  assert_eq(
    @moonmqtt.decode_exact_packet(b"\x40\x02\x00\x00"),
    Err(
      @moonmqtt.MqttError::ProtocolViolation(
        "packet identifier must be non-zero",
      ),
    ),
  )
}

///|
test "encoder enforces PUBLISH packet identifier rules" {
  let invalid_qos0 = @moonmqtt.Packet::PublishPacket({
    topic: "a",
    payload: b"x",
    qos: @moonmqtt.QoS::AtMostOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(1),
    properties: [],
  })
  assert_eq(
    @moonmqtt.encode_packet(invalid_qos0),
    Err(
      @moonmqtt.MqttError::ProtocolViolation(
        "QoS 0 PUBLISH must not contain a packet identifier",
      ),
    ),
  )
}

///|
fn connected_session() -> @moonmqtt.ClientSession {
  let session = @moonmqtt.ClientSession::new()
  ignore(session.begin_connect(@moonmqtt.ConnectPacket::new("test-client")))
  ignore(
    session.handle_incoming(
      @moonmqtt.Packet::ConnAckPacket({
        session_present: false,
        reason_code: 0,
        properties: [],
      }),
    ),
  )
  session
}

///|
test "stream decoder buffers partial packets and emits complete frames" {
  let decoder = @moonmqtt.PacketStreamDecoder::new()
  assert_eq(decoder.feed(b"\xc0"), Ok([]))
  assert_eq(decoder.buffered_bytes(), 1)
  assert_eq(
    decoder.feed(b"\x00\xd0\x00"),
    Ok([@moonmqtt.Packet::PingReqPacket, @moonmqtt.Packet::PingRespPacket]),
  )
  assert_eq(decoder.buffered_bytes(), 0)
}

///|
test "stream decoder enforces a per-packet byte limit" {
  match @moonmqtt.PacketStreamDecoder::with_max_packet_size(1) {
    Err(@moonmqtt.MqttError::ValueOutOfRange("maximum packet size", 1)) => ()
    _ => fail("invalid stream limit was accepted")
  }
  let decoder = @moonmqtt.PacketStreamDecoder::with_max_packet_size(7).unwrap()
  assert_eq(decoder.max_packet_size(), 7)
  assert_eq(decoder.feed(b"\x30\x06\x00\x01a\x00h"), Ok([]))
  assert_eq(
    decoder.feed(b"i"),
    Err(@moonmqtt.MqttError::ValueOutOfRange("MQTT packet size", 8)),
  )
  decoder.reset()
  assert_eq(
    decoder.feed(b"\xc0\x00\xd0\x00"),
    Ok([@moonmqtt.Packet::PingReqPacket, @moonmqtt.Packet::PingRespPacket]),
  )
}

///|
test "client session enforces connection lifecycle" {
  let session = @moonmqtt.ClientSession::new()
  assert_eq(session.state(), @moonmqtt.ConnectionState::Disconnected)
  assert_eq(
    session.begin_connect(@moonmqtt.ConnectPacket::new("client")),
    Ok(@moonmqtt.Packet::ConnectPacket(@moonmqtt.ConnectPacket::new("client"))),
  )
  assert_eq(session.state(), @moonmqtt.ConnectionState::AwaitingConnAck)
  let outcome = session.handle_incoming(
    @moonmqtt.Packet::ConnAckPacket({
      session_present: false,
      reason_code: 0,
      properties: [],
    }),
  )
  assert_eq(
    outcome,
    Ok({
      responses: [],
      events: [@moonmqtt.SessionEvent::ConnectedEvent(false, [])],
    }),
  )
  assert_eq(session.state(), @moonmqtt.ConnectionState::Connected)
}

///|
test "outgoing QoS 1 publish is tracked until PUBACK" {
  let session = connected_session()
  let publish = session.prepare_publish(
    "sensors/temp",
    b"22.1",
    qos=@moonmqtt.QoS::AtLeastOnce,
  )
  let packet_id = match publish {
    Ok(@moonmqtt.Packet::PublishPacket(value)) => value.packet_id.unwrap()
    _ => fail("expected a QoS 1 PUBLISH packet")
  }
  assert_eq(session.inflight_count(), 1)
  assert_eq(
    session.handle_incoming(
      @moonmqtt.Packet::PubResponsePacket({
        kind: @moonmqtt.PacketType::PubAck,
        packet_id,
        reason_code: 0,
        properties: [],
      }),
    ),
    Ok({
      responses: [],
      events: [
        @moonmqtt.SessionEvent::AcknowledgedEvent(
          @moonmqtt.PacketType::PubAck,
          packet_id,
          0,
        ),
      ],
    }),
  )
  assert_eq(session.inflight_count(), 0)
}

///|
test "outgoing QoS 2 publish completes four-step handshake" {
  let session = connected_session()
  let publish = session.prepare_publish(
    "commands/motor",
    b"start",
    qos=@moonmqtt.QoS::ExactlyOnce,
  )
  let packet_id = match publish {
    Ok(@moonmqtt.Packet::PublishPacket(value)) => value.packet_id.unwrap()
    _ => fail("expected a QoS 2 PUBLISH packet")
  }
  let pubrec_outcome = session.handle_incoming(
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubRec,
      packet_id,
      reason_code: 0,
      properties: [],
    }),
  )
  assert_eq(
    pubrec_outcome,
    Ok({
      responses: [
        @moonmqtt.Packet::PubResponsePacket({
          kind: @moonmqtt.PacketType::PubRel,
          packet_id,
          reason_code: 0,
          properties: [],
        }),
      ],
      events: [],
    }),
  )
  assert_eq(session.inflight_count(), 1)
  ignore(
    session.handle_incoming(
      @moonmqtt.Packet::PubResponsePacket({
        kind: @moonmqtt.PacketType::PubComp,
        packet_id,
        reason_code: 0,
        properties: [],
      }),
    ),
  )
  assert_eq(session.inflight_count(), 0)
}

///|
test "incoming QoS 2 message is delivered exactly once after PUBREL" {
  let session = connected_session()
  let publish : @moonmqtt.PublishPacket = {
    topic: "commands/motor",
    payload: b"stop",
    qos: @moonmqtt.QoS::ExactlyOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(55),
    properties: [],
  }
  let first = session.handle_incoming(@moonmqtt.Packet::PublishPacket(publish))
  assert_eq(
    first,
    Ok({
      responses: [
        @moonmqtt.Packet::PubResponsePacket({
          kind: @moonmqtt.PacketType::PubRec,
          packet_id: 55,
          reason_code: 0,
          properties: [],
        }),
      ],
      events: [],
    }),
  )
  let duplicate = session.handle_incoming(
    @moonmqtt.Packet::PublishPacket({
      topic: publish.topic,
      payload: publish.payload,
      qos: publish.qos,
      retain: publish.retain,
      duplicate: true,
      packet_id: publish.packet_id,
      properties: publish.properties,
    }),
  )
  match duplicate {
    Ok(outcome) => assert_eq(outcome.events, [])
    Err(_) => fail("duplicate QoS 2 PUBLISH should be acknowledged")
  }
  let completed = session.handle_incoming(
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubRel,
      packet_id: 55,
      reason_code: 0,
      properties: [],
    }),
  )
  assert_eq(
    completed,
    Ok({
      responses: [
        @moonmqtt.Packet::PubResponsePacket({
          kind: @moonmqtt.PacketType::PubComp,
          packet_id: 55,
          reason_code: 0,
          properties: [],
        }),
      ],
      events: [@moonmqtt.SessionEvent::MessageEvent(publish)],
    }),
  )
}

///|
test "PINGREQ allows only one outstanding request" {
  let session = connected_session()
  assert_eq(session.prepare_ping(), Ok(@moonmqtt.Packet::PingReqPacket))
  assert_eq(
    session.prepare_ping(),
    Err(@moonmqtt.MqttError::InvalidState("a PINGREQ is already outstanding")),
  )
  assert_eq(
    session.handle_incoming(@moonmqtt.Packet::PingRespPacket),
    Ok({ responses: [], events: [], }),
  )
  assert_eq(session.has_ping_outstanding(), false)
}

///|
test "MQTT UTF-8 validates Unicode and prohibited scalar values" {
  let text = "传感器🌡️"
  let encoded = @moonmqtt.encode_mqtt_utf8(text)
  match encoded {
    Ok(bytes) => assert_eq(@moonmqtt.decode_mqtt_utf8(bytes), Ok(text))
    Err(_) => fail("valid Unicode text was rejected")
  }
  assert_eq(
    @moonmqtt.decode_mqtt_utf8(b"\xc0\x80"),
    Err(@moonmqtt.MqttError::InvalidUtf8("invalid UTF-8 leading byte")),
  )
  assert_eq(
    @moonmqtt.decode_mqtt_utf8(b"\x00"),
    Err(
      @moonmqtt.MqttError::InvalidUtf8(
        "U+0000 is not permitted in MQTT UTF-8 data",
      ),
    ),
  )
}

///|
test "hex helpers round-trip wire bytes" {
  let wire = b"\x30\x06\x00\x01a\x00hi"
  assert_eq(@moonmqtt.encode_hex(wire), "30 06 00 01 61 00 68 69")
  assert_eq(@moonmqtt.decode_hex("30:06:00:01:61:00:68:69"), Ok(wire))
}

///|
test "topic filters match wildcards shared subscriptions and system topics" {
  assert_eq(
    @moonmqtt.topic_matches("factory/+/temperature", "factory/a/temperature"),
    Ok(true),
  )
  assert_eq(
    @moonmqtt.topic_matches("factory/+/temperature", "factory/a/humidity"),
    Ok(false),
  )
  assert_eq(@moonmqtt.topic_matches("factory/#", "factory"), Ok(true))
  assert_eq(
    @moonmqtt.topic_matches("factory/#", "factory/a/temperature"),
    Ok(true),
  )
  assert_eq(
    @moonmqtt.topic_matches("$share/workers/factory/+", "factory/a"),
    Ok(true),
  )
  assert_eq(@moonmqtt.topic_matches("#", "$SYS/broker/uptime"), Ok(false))
  assert_eq(@moonmqtt.topic_matches("$SYS/#", "$SYS/broker/uptime"), Ok(true))
  assert_eq(
    @moonmqtt.topic_matches("factory/a+", "factory/a"),
    Err(
      @moonmqtt.MqttError::ProtocolViolation(
        "single-level wildcard must occupy an entire topic level",
      ),
    ),
  )
}

///|
test "property validation rejects wrong packet location and duplicates" {
  let wrong_location = @moonmqtt.Packet::PublishPacket({
    topic: "a",
    payload: b"x",
    qos: @moonmqtt.QoS::AtMostOnce,
    retain: false,
    duplicate: false,
    packet_id: None,
    properties: [@moonmqtt.Property::ReceiveMaximum(10)],
  })
  assert_eq(
    @moonmqtt.encode_packet(wrong_location),
    Err(
      @moonmqtt.MqttError::InvalidPropertyValue(
        0x21, "property is not allowed in PUBLISH",
      ),
    ),
  )
  let duplicate = @moonmqtt.Packet::ConnectPacket({
    client_id: "a",
    clean_start: true,
    keep_alive: 60,
    username: None,
    password: None,
    will: None,
    properties: [
      @moonmqtt.Property::ReceiveMaximum(10),
      @moonmqtt.Property::ReceiveMaximum(20),
    ],
  })
  assert_eq(
    @moonmqtt.encode_packet(duplicate),
    Err(
      @moonmqtt.MqttError::InvalidPropertyValue(
        0x21, "property must not occur more than once in CONNECT",
      ),
    ),
  )
}

///|
fn assert_packet_round_trip(packet : @moonmqtt.Packet) -> Unit raise {
  match @moonmqtt.encode_packet(packet) {
    Err(_) => fail("unexpected encode error")
    Ok(bytes) => assert_eq(@moonmqtt.decode_exact_packet(bytes), Ok(packet))
  }
}

///|
test "all MQTT 5 property representations round-trip in valid locations" {
  assert_packet_round_trip(
    @moonmqtt.Packet::ConnectPacket({
      client_id: "property-client",
      clean_start: true,
      keep_alive: 45,
      username: None,
      password: None,
      will: Some({
        topic: "devices/property-client/status",
        payload: b"offline",
        qos: @moonmqtt.QoS::AtLeastOnce,
        retain: true,
        properties: [
          @moonmqtt.Property::WillDelayInterval(5),
          @moonmqtt.Property::PayloadFormatIndicator(1),
          @moonmqtt.Property::MessageExpiryInterval(30),
          @moonmqtt.Property::ContentType("text/plain"),
          @moonmqtt.Property::ResponseTopic("status/response"),
          @moonmqtt.Property::CorrelationData(b"will-1"),
          @moonmqtt.Property::UserProperty("source", "will"),
        ],
      }),
      properties: [
        @moonmqtt.Property::SessionExpiryInterval(300),
        @moonmqtt.Property::ReceiveMaximum(20),
        @moonmqtt.Property::MaximumPacketSize(65536),
        @moonmqtt.Property::TopicAliasMaximum(8),
        @moonmqtt.Property::RequestResponseInformation(1),
        @moonmqtt.Property::RequestProblemInformation(0),
        @moonmqtt.Property::UserProperty("site", "lab"),
        @moonmqtt.Property::AuthenticationMethod("token"),
        @moonmqtt.Property::AuthenticationData(b"proof"),
      ],
    }),
  )
  assert_packet_round_trip(
    @moonmqtt.Packet::ConnAckPacket({
      session_present: true,
      reason_code: 0,
      properties: [
        @moonmqtt.Property::SessionExpiryInterval(300),
        @moonmqtt.Property::ReceiveMaximum(50),
        @moonmqtt.Property::MaximumQoS(1),
        @moonmqtt.Property::RetainAvailable(1),
        @moonmqtt.Property::MaximumPacketSize(131072),
        @moonmqtt.Property::AssignedClientIdentifier("assigned-7"),
        @moonmqtt.Property::TopicAliasMaximum(16),
        @moonmqtt.Property::ReasonString("connected"),
        @moonmqtt.Property::UserProperty("cluster", "east"),
        @moonmqtt.Property::WildcardSubscriptionAvailable(1),
        @moonmqtt.Property::SubscriptionIdentifierAvailable(1),
        @moonmqtt.Property::SharedSubscriptionAvailable(1),
        @moonmqtt.Property::ServerKeepAlive(60),
        @moonmqtt.Property::ResponseInformation("responses/"),
        @moonmqtt.Property::ServerReference("mqtt.example.com"),
        @moonmqtt.Property::AuthenticationMethod("token"),
        @moonmqtt.Property::AuthenticationData(b"challenge"),
      ],
    }),
  )
  assert_packet_round_trip(
    @moonmqtt.Packet::PublishPacket({
      topic: "sensors/temperature",
      payload: b"23.4",
      qos: @moonmqtt.QoS::AtLeastOnce,
      retain: false,
      duplicate: false,
      packet_id: Some(12),
      properties: [
        @moonmqtt.Property::PayloadFormatIndicator(1),
        @moonmqtt.Property::MessageExpiryInterval(60),
        @moonmqtt.Property::TopicAlias(2),
        @moonmqtt.Property::ResponseTopic("responses/temperature"),
        @moonmqtt.Property::CorrelationData(b"request-8"),
        @moonmqtt.Property::UserProperty("unit", "Cel"),
        @moonmqtt.Property::SubscriptionIdentifier(1),
        @moonmqtt.Property::SubscriptionIdentifier(200),
        @moonmqtt.Property::ContentType("text/plain"),
      ],
    }),
  )
  let packets : Array[@moonmqtt.Packet] = [
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubAck,
      packet_id: 12,
      reason_code: 0x10,
      properties: [
        @moonmqtt.Property::ReasonString("accepted"),
        @moonmqtt.Property::UserProperty("node", "1"),
      ],
    }),
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 13,
      subscriptions: [@moonmqtt.Subscription::new("sensors/+")],
      properties: [
        @moonmqtt.Property::SubscriptionIdentifier(7),
        @moonmqtt.Property::UserProperty("purpose", "dashboard"),
      ],
    }),
    @moonmqtt.Packet::SubAckPacket({
      packet_id: 13,
      reason_codes: [1],
      properties: [
        @moonmqtt.Property::ReasonString("granted"),
        @moonmqtt.Property::UserProperty("node", "1"),
      ],
    }),
    @moonmqtt.Packet::UnsubscribePacket({
      packet_id: 14,
      topic_filters: ["sensors/+"],
      properties: [@moonmqtt.Property::UserProperty("reason", "finished")],
    }),
    @moonmqtt.Packet::UnsubAckPacket({
      packet_id: 14,
      reason_codes: [0],
      properties: [
        @moonmqtt.Property::ReasonString("removed"),
        @moonmqtt.Property::UserProperty("node", "1"),
      ],
    }),
    @moonmqtt.Packet::DisconnectPacket({
      reason_code: 0x04,
      properties: [
        @moonmqtt.Property::SessionExpiryInterval(0),
        @moonmqtt.Property::ReasonString("moving"),
        @moonmqtt.Property::UserProperty("planned", "true"),
        @moonmqtt.Property::ServerReference("mqtt-backup.example.com"),
      ],
    }),
    @moonmqtt.Packet::AuthPacket({
      reason_code: 0x18,
      properties: [
        @moonmqtt.Property::AuthenticationMethod("token"),
        @moonmqtt.Property::AuthenticationData(b"response"),
        @moonmqtt.Property::ReasonString("continue"),
        @moonmqtt.Property::UserProperty("round", "2"),
      ],
    }),
  ]
  for packet in packets {
    assert_packet_round_trip(packet)
  }
}

///|
test "property encoders reject reserved zero and invalid scalar values" {
  let invalid_packets : Array[@moonmqtt.Packet] = [
    @moonmqtt.Packet::ConnectPacket({
      client_id: "a",
      clean_start: true,
      keep_alive: 60,
      username: None,
      password: None,
      will: None,
      properties: [@moonmqtt.Property::ReceiveMaximum(0)],
    }),
    @moonmqtt.Packet::ConnectPacket({
      client_id: "a",
      clean_start: true,
      keep_alive: 60,
      username: None,
      password: None,
      will: None,
      properties: [@moonmqtt.Property::MaximumPacketSize(0)],
    }),
    @moonmqtt.Packet::PublishPacket({
      topic: "a",
      payload: b"x",
      qos: @moonmqtt.QoS::AtMostOnce,
      retain: false,
      duplicate: false,
      packet_id: None,
      properties: [@moonmqtt.Property::TopicAlias(0)],
    }),
  ]
  for packet in invalid_packets {
    match @moonmqtt.encode_packet(packet) {
      Err(@moonmqtt.MqttError::InvalidPropertyValue(_, _)) => ()
      _ => fail("reserved zero property value was accepted")
    }
  }
  let invalid_boolean = @moonmqtt.Packet::ConnectPacket({
    client_id: "a",
    clean_start: true,
    keep_alive: 60,
    username: None,
    password: None,
    will: None,
    properties: [@moonmqtt.Property::RequestProblemInformation(2)],
  })
  assert_eq(
    @moonmqtt.encode_packet(invalid_boolean),
    Err(
      @moonmqtt.MqttError::InvalidPropertyValue(
        0x17, "expected byte value 0 or 1",
      ),
    ),
  )
}

///|
test "session handles subscriptions incoming messages and retransmission" {
  let session = connected_session()
  let subscription = session.prepare_subscribe([
    @moonmqtt.Subscription::new("sensors/+", qos=@moonmqtt.QoS::AtLeastOnce),
  ])
  let subscription_id = match subscription {
    Ok(@moonmqtt.Packet::SubscribePacket(value)) => value.packet_id
    _ => fail("expected SUBSCRIBE")
  }
  assert_eq(
    session.handle_incoming(
      @moonmqtt.Packet::SubAckPacket({
        packet_id: subscription_id,
        reason_codes: [1],
        properties: [],
      }),
    ),
    Ok({
      responses: [],
      events: [
        @moonmqtt.SessionEvent::AcknowledgedEvent(
          @moonmqtt.PacketType::SubAck,
          subscription_id,
          1,
        ),
      ],
    }),
  )
  let unsubscription = session.prepare_unsubscribe(["sensors/+"])
  let unsubscription_id = match unsubscription {
    Ok(@moonmqtt.Packet::UnsubscribePacket(value)) => value.packet_id
    _ => fail("expected UNSUBSCRIBE")
  }
  assert_eq(
    session.handle_incoming(
      @moonmqtt.Packet::UnsubAckPacket({
        packet_id: unsubscription_id,
        reason_codes: [0],
        properties: [],
      }),
    ),
    Ok({
      responses: [],
      events: [
        @moonmqtt.SessionEvent::AcknowledgedEvent(
          @moonmqtt.PacketType::UnsubAck,
          unsubscription_id,
          0,
        ),
      ],
    }),
  )
  let qos0 : @moonmqtt.PublishPacket = {
    topic: "sensors/one",
    payload: b"1",
    qos: @moonmqtt.QoS::AtMostOnce,
    retain: false,
    duplicate: false,
    packet_id: None,
    properties: [],
  }
  assert_eq(
    session.handle_incoming(@moonmqtt.Packet::PublishPacket(qos0)),
    Ok({ responses: [], events: [@moonmqtt.SessionEvent::MessageEvent(qos0)], }),
  )
  let qos1 : @moonmqtt.PublishPacket = {
    topic: "sensors/two",
    payload: b"2",
    qos: @moonmqtt.QoS::AtLeastOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(77),
    properties: [],
  }
  assert_eq(
    session.handle_incoming(@moonmqtt.Packet::PublishPacket(qos1)),
    Ok({
      responses: [
        @moonmqtt.Packet::PubResponsePacket({
          kind: @moonmqtt.PacketType::PubAck,
          packet_id: 77,
          reason_code: 0,
          properties: [],
        }),
      ],
      events: [@moonmqtt.SessionEvent::MessageEvent(qos1)],
    }),
  )
  let outgoing = session.prepare_publish(
    "sensors/out",
    b"3",
    qos=@moonmqtt.QoS::AtLeastOnce,
  )
  match (outgoing, session.retransmit_inflight()) {
    (
      Ok(@moonmqtt.Packet::PublishPacket(original)),
      [@moonmqtt.Packet::PublishPacket(retried)],
    ) => {
      assert_eq(retried.packet_id, original.packet_id)
      assert_eq(retried.duplicate, true)
    }
    _ => fail("expected one retransmitted PUBLISH")
  }
}

///|
test "decoder and text helpers reject boundary violations" {
  assert_eq(
    @moonmqtt.encode_variable_byte_integer(-1),
    Err(@moonmqtt.MqttError::ValueOutOfRange("variable byte integer", -1)),
  )
  assert_eq(
    @moonmqtt.encode_variable_byte_integer(268435456),
    Err(
      @moonmqtt.MqttError::ValueOutOfRange("variable byte integer", 268435456),
    ),
  )
  assert_eq(
    @moonmqtt.decode_exact_packet(b"\xc0\x80\x00"),
    Err(
      @moonmqtt.MqttError::MalformedPacket("non-minimal variable byte integer"),
    ),
  )
  assert_eq(
    @moonmqtt.decode_exact_packet(b"\xc0\x00\xd0\x00"),
    Err(
      @moonmqtt.MqttError::MalformedPacket(
        "input contains more than one packet",
      ),
    ),
  )
  assert_eq(
    @moonmqtt.decode_hex("abc"),
    Err(
      @moonmqtt.MqttError::MalformedPacket(
        "hex input must contain an even number of digits",
      ),
    ),
  )
  assert_eq(
    @moonmqtt.decode_hex("zz"),
    Err(
      @moonmqtt.MqttError::MalformedPacket(
        "hex input contains a non-hex character",
      ),
    ),
  )
  assert_eq(
    @moonmqtt.decode_mqtt_utf8(b"\xe2\x82"),
    Err(@moonmqtt.MqttError::InvalidUtf8("truncated three-byte sequence")),
  )
}

///|
test "packet semantics reject invalid topics reason codes and auth fields" {
  let invalid_packets : Array[@moonmqtt.Packet] = [
    @moonmqtt.Packet::PublishPacket({
      topic: "sensors/+",
      payload: b"x",
      qos: @moonmqtt.QoS::AtMostOnce,
      retain: false,
      duplicate: false,
      packet_id: None,
      properties: [],
    }),
    @moonmqtt.Packet::PublishPacket({
      topic: "",
      payload: b"x",
      qos: @moonmqtt.QoS::AtMostOnce,
      retain: false,
      duplicate: false,
      packet_id: None,
      properties: [],
    }),
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 1,
      subscriptions: [@moonmqtt.Subscription::new("sensors/#/invalid")],
      properties: [],
    }),
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 1,
      subscriptions: [@moonmqtt.Subscription::new("sensors/room+")],
      properties: [],
    }),
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 1,
      subscriptions: [@moonmqtt.Subscription::new("$share//sensors/#")],
      properties: [],
    }),
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 1,
      subscriptions: [
        {
          topic_filter: "$share/workers/sensors/+",
          qos: @moonmqtt.QoS::AtLeastOnce,
          no_local: true,
          retain_as_published: false,
          retain_handling: 0,
        },
      ],
      properties: [],
    }),
    @moonmqtt.Packet::PubResponsePacket({
      kind: @moonmqtt.PacketType::PubAck,
      packet_id: 1,
      reason_code: 0x11,
      properties: [],
    }),
    @moonmqtt.Packet::ConnAckPacket({
      session_present: true,
      reason_code: 0x80,
      properties: [],
    }),
    @moonmqtt.Packet::AuthPacket({
      reason_code: 0x18,
      properties: [@moonmqtt.Property::AuthenticationData(b"orphan")],
    }),
    @moonmqtt.Packet::PublishPacket({
      topic: "requests/one",
      payload: b"x",
      qos: @moonmqtt.QoS::AtMostOnce,
      retain: false,
      duplicate: false,
      packet_id: None,
      properties: [@moonmqtt.Property::ResponseTopic("responses/#")],
    }),
  ]
  for packet in invalid_packets {
    match @moonmqtt.encode_packet(packet) {
      Err(@moonmqtt.MqttError::ProtocolViolation(_)) => ()
      _ => fail("invalid packet semantics were accepted")
    }
  }
  assert_packet_round_trip(
    @moonmqtt.Packet::PublishPacket({
      topic: "",
      payload: b"aliased",
      qos: @moonmqtt.QoS::AtMostOnce,
      retain: false,
      duplicate: false,
      packet_id: None,
      properties: [@moonmqtt.Property::TopicAlias(1)],
    }),
  )
  assert_packet_round_trip(
    @moonmqtt.Packet::SubscribePacket({
      packet_id: 9,
      subscriptions: [
        @moonmqtt.Subscription::new(
          "$share/workers/sensors/+",
          qos=@moonmqtt.QoS::AtLeastOnce,
        ),
      ],
      properties: [],
    }),
  )
}
