///|
async fn read_one_packet(
  connection : @socket.Tcp,
  decoder : @mqtt.PacketStreamDecoder,
) -> @mqtt.Packet {
  while true {
    match connection.read_some(max_len=128) {
      None => fail("test broker connection closed unexpectedly")
      Some(chunk) =>
        match decoder.feed(chunk) {
          Err(_) => fail("test broker received an invalid MQTT packet")
          Ok(packets) => if !packets.is_empty() { return packets[0] }
        }
    }
  }
  @mqtt.Packet::PingReqPacket
}

///|
async fn write_packet(connection : @socket.Tcp, packet : @mqtt.Packet) -> Unit {
  match @mqtt.encode_packet(packet) {
    Err(_) => fail("test broker could not encode MQTT packet")
    Ok(bytes) => connection.write(bytes)
  }
}

///|
async fn run_test_broker(server : @socket.TcpServer) -> Unit {
  let (connection, _) = server.accept()
  defer connection.close()
  let decoder = @mqtt.PacketStreamDecoder::new()
  let connect = read_one_packet(connection, decoder)
  assert_true(connect is @mqtt.Packet::ConnectPacket(_))
  write_packet(
    connection,
    @mqtt.Packet::ConnAckPacket({
      session_present: false,
      reason_code: 0,
      properties: [@mqtt.Property::ReceiveMaximum(16)],
    }),
  )
  let publish = read_one_packet(connection, decoder)
  let packet_id = match publish {
    @mqtt.Packet::PublishPacket(value) => {
      assert_eq(value.topic, "integration/temperature")
      assert_eq(value.payload, b"23.4")
      value.packet_id.unwrap()
    }
    _ => fail("test broker expected PUBLISH")
  }
  write_packet(
    connection,
    @mqtt.Packet::PubResponsePacket({
      kind: @mqtt.PacketType::PubAck,
      packet_id,
      reason_code: 0,
      properties: [],
    }),
  )
  let disconnect = read_one_packet(connection, decoder)
  assert_true(disconnect is @mqtt.Packet::DisconnectPacket(_))
}

///|
async test "native client connects and completes QoS 1 flow over TCP" {
  @async.with_task_group(root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    root.spawn_bg(() => run_test_broker(server))
    let client = match
      @native.NativeClient::connect(
        @native.NativeOptions::new("127.0.0.1", port=server.addr.port()),
        @mqtt.ConnectPacket::new("integration-client"),
      ) {
      Ok(value) => value
      Err(_) => fail("native client failed to connect to the test broker")
    }
    match
      client.publish(
        "integration/temperature",
        b"23.4",
        qos=@mqtt.QoS::AtLeastOnce,
      ) {
      Ok(_) => ()
      Err(_) => fail("native client failed to publish")
    }
    let events = match client.receive() {
      Ok(value) => value
      Err(_) => fail("native client failed to receive PUBACK")
    }
    assert_eq(events.length(), 1)
    assert_true(
      events[0]
      is @mqtt.SessionEvent::AcknowledgedEvent(@mqtt.PacketType::PubAck, _, 0),
    )
    match client.disconnect() {
      Ok(_) => ()
      Err(_) => fail("native client failed to disconnect")
    }
  })
}
