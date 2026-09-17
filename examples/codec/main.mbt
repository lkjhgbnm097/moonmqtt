///|
fn main {
  let packet = @mqtt.Packet::PublishPacket({
    topic: "factory/line-1/temperature",
    payload: @mqtt.encode_mqtt_utf8("23.4").unwrap(),
    qos: @mqtt.QoS::AtLeastOnce,
    retain: false,
    duplicate: false,
    packet_id: Some(7),
    properties: [
      @mqtt.Property::PayloadFormatIndicator(1),
      @mqtt.Property::ContentType("text/plain"),
      @mqtt.Property::UserProperty("unit", "Cel"),
    ],
  })
  match @mqtt.encode_packet(packet) {
    Err(err) => println("encode failed: \{err.message()}")
    Ok(wire) => {
      println("wire: \{@mqtt.encode_hex(wire)}")
      match @mqtt.decode_exact_packet(wire) {
        Ok(decoded) => println(repr(decoded))
        Err(err) => println("decode failed: \{err.message()}")
      }
    }
  }
}
