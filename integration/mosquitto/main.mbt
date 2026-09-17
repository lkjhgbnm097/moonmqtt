///|
async fn wait_for_ack(
  client : @native.NativeClient,
  kind : @mqtt.PacketType,
) -> Unit {
  let mut acknowledged = false
  while !acknowledged {
    let events = match client.receive() {
      Ok(value) => value
      Err(err) => fail(err.message())
    }
    for event in events {
      if event is @mqtt.SessionEvent::AcknowledgedEvent(packet_type, _, 0) &&
        packet_type == kind {
        acknowledged = true
      }
    }
  }
}

///|
async fn main {
  let options = @native.NativeOptions::new("127.0.0.1", port=1883)
  let subscriber = match
    @native.NativeClient::connect(
      options,
      @mqtt.ConnectPacket::new("moonmqtt-integration-subscriber"),
    ) {
    Ok(value) => value
    Err(err) => fail(err.message())
  }
  defer subscriber.close()
  match
    subscriber.subscribe([
      @mqtt.Subscription::new(
        "moonmqtt/integration/roundtrip",
        qos=@mqtt.QoS::AtLeastOnce,
      ),
    ]) {
    Ok(_) => ()
    Err(err) => fail(err.message())
  }
  wait_for_ack(subscriber, @mqtt.PacketType::SubAck)
  let publisher = match
    @native.NativeClient::connect(
      options,
      @mqtt.ConnectPacket::new("moonmqtt-integration-publisher"),
    ) {
    Ok(value) => value
    Err(err) => fail(err.message())
  }
  defer publisher.close()
  let payload = @mqtt.encode_mqtt_utf8("broker round-trip passed").unwrap()
  match
    publisher.publish(
      "moonmqtt/integration/roundtrip",
      payload,
      qos=@mqtt.QoS::AtLeastOnce,
      properties=[@mqtt.Property::PayloadFormatIndicator(1)],
    ) {
    Ok(_) => ()
    Err(err) => fail(err.message())
  }
  wait_for_ack(publisher, @mqtt.PacketType::PubAck)
  let mut delivered = false
  while !delivered {
    let events = match subscriber.receive() {
      Ok(value) => value
      Err(err) => fail(err.message())
    }
    for event in events {
      match event {
        @mqtt.SessionEvent::MessageEvent(message) => {
          assert_eq(message.topic, "moonmqtt/integration/roundtrip")
          assert_eq(message.payload, payload)
          delivered = true
        }
        _ => ()
      }
    }
  }
  ignore(publisher.disconnect())
  ignore(subscriber.disconnect())
  println("Mosquitto MQTT 5 round-trip passed")
}
