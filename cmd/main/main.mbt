///|
fn parse_qos(value : String) -> @mqtt.QoS? {
  let parsed = @string.parse_int(value) catch { _ => -1 }
  match parsed {
    0 => Some(@mqtt.QoS::AtMostOnce)
    1 => Some(@mqtt.QoS::AtLeastOnce)
    2 => Some(@mqtt.QoS::ExactlyOnce)
    _ => None
  }
}

///|
fn connection_options(matches : @argparse.Matches) -> @native.NativeOptions {
  let host = match matches.values {
    { "host": [value], .. } => value
    _ => "127.0.0.1"
  }
  let tls = match matches.flags {
    { "tls": value, .. } => value
    _ => false
  }
  let verify_tls = match matches.flags {
    { "insecure": value, .. } => !value
    _ => true
  }
  let default_port = if tls { 8883 } else { 1883 }
  let port = match matches.values {
    { "port": [value], .. } =>
      @string.parse_int(value) catch {
        _ => default_port
      }
    _ => default_port
  }
  { host, port, tls, verify_tls, read_chunk_size: 8192, }
}

///|
fn connect_packet(matches : @argparse.Matches) -> @mqtt.ConnectPacket {
  let client_id = match matches.values {
    { "client-id": [value], .. } => value
    _ => "moonmqtt-cli"
  }
  let username = match matches.values {
    { "username": [value], .. } => Some(value)
    _ => None
  }
  let password = match matches.values {
    { "password": [value], .. } =>
      match @mqtt.encode_mqtt_utf8(value) {
        Ok(bytes) => Some(bytes)
        Err(_) => None
      }
    _ => None
  }
  {
    client_id,
    clean_start: true,
    keep_alive: 60,
    username,
    password,
    will: None,
    properties: [
      @mqtt.Property::ReceiveMaximum(64),
      @mqtt.Property::RequestProblemInformation(1),
    ],
  }
}

///|
async fn open_client(matches : @argparse.Matches) -> @native.NativeClient? {
  match
    @native.NativeClient::connect(
      connection_options(matches),
      connect_packet(matches),
    ) {
    Ok(client) => Some(client)
    Err(err) => {
      println("connection failed: \{err.message()}")
      None
    }
  }
}

///|
fn inspect_command(matches : @argparse.Matches) -> Unit {
  guard matches.values is { "hex": [value], .. } else {
    println("missing hexadecimal MQTT packet")
    return
  }
  let bytes = match @mqtt.decode_hex(value) {
    Ok(bytes) => bytes
    Err(err) => {
      println("invalid hexadecimal input: \{err.message()}")
      return
    }
  }
  match @mqtt.decode_exact_packet(bytes) {
    Ok(packet) => {
      println(repr(packet))
      println("wire: \{@mqtt.encode_hex(bytes)}")
    }
    Err(err) => println("decode failed: \{err.message()}")
  }
}

///|
async fn publish_command(matches : @argparse.Matches) -> Unit {
  guard matches.values is { "topic": [topic], "payload": [payload_text], .. } else {
    println("publish requires TOPIC and PAYLOAD")
    return
  }
  let qos_text = match matches.values {
    { "qos": [value], .. } => value
    _ => "0"
  }
  let qos = match parse_qos(qos_text) {
    Some(value) => value
    None => {
      println("QoS must be 0, 1, or 2")
      return
    }
  }
  let retain = match matches.flags {
    { "retain": value, .. } => value
    _ => false
  }
  let payload = match @mqtt.encode_mqtt_utf8(payload_text) {
    Ok(value) => value
    Err(err) => {
      println("invalid payload: \{err.message()}")
      return
    }
  }
  guard open_client(matches) is Some(client) else { return }
  defer client.close()
  match
    client.publish(topic, payload, qos~, retain~, properties=[
      @mqtt.Property::PayloadFormatIndicator(1),
    ]) {
    Err(err) => {
      println("publish failed: \{err.message()}")
      return
    }
    Ok(_) => ()
  }
  if qos != @mqtt.QoS::AtMostOnce {
    let mut acknowledged = false
    while !acknowledged && !client.is_closed() {
      match client.receive() {
        Err(err) => {
          println("receive failed: \{err.message()}")
          return
        }
        Ok(events) =>
          for event in events {
            if event is @mqtt.SessionEvent::AcknowledgedEvent(_, _, 0) {
              acknowledged = true
            }
          }
      }
    }
  }
  println("published to \{topic} with QoS \{qos.to_int()}")
  ignore(client.disconnect())
}

///|
async fn subscribe_command(matches : @argparse.Matches) -> Unit {
  guard matches.values is { "topic": [topic], .. } else {
    println("subscribe requires TOPIC")
    return
  }
  let qos_text = match matches.values {
    { "qos": [value], .. } => value
    _ => "0"
  }
  let qos = match parse_qos(qos_text) {
    Some(value) => value
    None => {
      println("QoS must be 0, 1, or 2")
      return
    }
  }
  let count = match matches.values {
    { "count": [value], .. } => @string.parse_int(value) catch { _ => 1 }
    _ => 1
  }
  guard count >= 0 else {
    println("count must be zero or greater")
    return
  }
  guard open_client(matches) is Some(client) else { return }
  defer client.close()
  match client.subscribe([@mqtt.Subscription::new(topic, qos~)]) {
    Err(err) => {
      println("subscribe failed: \{err.message()}")
      return
    }
    Ok(_) => ()
  }
  println("subscribed to \{topic}; waiting for messages")
  let mut received = 0
  while count == 0 || received < count {
    match client.receive() {
      Err(err) => {
        println("receive failed: \{err.message()}")
        return
      }
      Ok(events) => {
        if client.is_closed() {
          println("broker closed the connection")
          return
        }
        for event in events {
          match event {
            @mqtt.SessionEvent::MessageEvent(message) => {
              received += 1
              let payload = match @mqtt.decode_mqtt_utf8(message.payload) {
                Ok(text) => text
                Err(_) => @mqtt.encode_hex(message.payload)
              }
              println("[\{message.topic}] \{payload}")
            }
            @mqtt.SessionEvent::DisconnectedEvent(reason, _) => {
              println("broker disconnected with reason 0x\{reason.to_hex()}")
              return
            }
            _ => ()
          }
        }
      }
    }
  }
  ignore(client.disconnect())
}

///|
fn common_options() -> Array[@argparse.OptionArg] {
  [
    @argparse.OptionArg(
      "host",
      long="host",
      about="MQTT broker host (default: 127.0.0.1)",
    ),
    @argparse.OptionArg("port", short='p', long="port", about="broker port"),
    @argparse.OptionArg(
      "client-id",
      long="client-id",
      about="MQTT client identifier",
    ),
    @argparse.OptionArg("username", short='u', long="username"),
    @argparse.OptionArg("password", short='P', long="password"),
    @argparse.OptionArg(
      "qos",
      short='q',
      long="qos",
      default_values=["0"],
      about="QoS level: 0, 1, or 2",
    ),
  ]
}

///|
fn common_flags() -> Array[@argparse.FlagArg] {
  [
    @argparse.FlagArg("tls", long="tls", about="connect using TLS"),
    @argparse.FlagArg(
      "insecure",
      long="insecure",
      about="disable TLS certificate verification (testing only)",
      requires=["tls"],
    ),
  ]
}

///|
async fn main {
  let publish_options = common_options()
  let subscribe_options = common_options()
  subscribe_options.push(
    @argparse.OptionArg(
      "count",
      short='n',
      long="count",
      default_values=["1"],
      about="messages to receive; zero waits forever",
    ),
  )
  let publish_flags = common_flags()
  publish_flags.push(
    @argparse.FlagArg(
      "retain",
      short='r',
      long="retain",
      about="retain message",
    ),
  )
  let matches = @argparse.Command(
    "moonmqtt",
    version="0.1.0",
    about="MQTT 5.0 protocol inspector and native client",
    subcommand_required=true,
    subcommands=[
      @argparse.Command(
        "inspect",
        about="decode one MQTT packet from hexadecimal bytes",
        positionals=[
          @argparse.PositionArg(
            "hex",
            about="packet bytes, for example: c0 00",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "publish",
        about="publish a UTF-8 payload",
        options=publish_options,
        flags=publish_flags,
        positionals=[
          @argparse.PositionArg(
            "topic",
            num_args=@argparse.ValueRange::single(),
          ),
          @argparse.PositionArg(
            "payload",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
      @argparse.Command(
        "subscribe",
        about="subscribe and print received messages",
        options=subscribe_options,
        flags=common_flags(),
        positionals=[
          @argparse.PositionArg(
            "topic",
            num_args=@argparse.ValueRange::single(),
          ),
        ],
      ),
    ],
  ).parse()
  match matches.subcommand {
    Some(("inspect", command)) => inspect_command(command)
    Some(("publish", command)) => publish_command(command)
    Some(("subscribe", command)) => subscribe_command(command)
    _ => ()
  }
}
