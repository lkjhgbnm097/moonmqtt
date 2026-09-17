///|
async fn main {
  let options = @native.NativeOptions::new("127.0.0.1")
  let connect = @mqtt.ConnectPacket::new("moonmqtt-example")
  match @native.NativeClient::connect(options, connect) {
    Err(err) => println("connect failed: \{err.message()}")
    Ok(client) => {
      defer client.close()
      let payload = @mqtt.encode_mqtt_utf8("hello from MoonBit").unwrap()
      match
        client.publish("moonmqtt/example", payload, qos=@mqtt.QoS::AtMostOnce) {
        Ok(_) => println("message published")
        Err(err) => println("publish failed: \{err.message()}")
      }
      ignore(client.disconnect())
    }
  }
}
