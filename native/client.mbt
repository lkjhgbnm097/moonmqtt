///|
pub(all) struct NativeOptions {
  host : String
  port : Int
  tls : Bool
  verify_tls : Bool
  read_chunk_size : Int
}

///|
pub fn NativeOptions::new(
  host : String,
  port? : Int = 1883,
  tls? : Bool = false,
) -> NativeOptions {
  { host, port, tls, verify_tls: true, read_chunk_size: 8192, }
}

///|
pub enum NativeTransport {
  Plain(@socket.Tcp)
  Secure(@tls.Tls)
}

///|
async fn NativeTransport::read_some(
  self : NativeTransport,
  max_len : Int,
) -> Bytes? {
  match self {
    Plain(connection) => connection.read_some(max_len~)
    Secure(connection) => connection.read_some(max_len~)
  }
}

///|
async fn NativeTransport::write_all(
  self : NativeTransport,
  data : Bytes,
) -> Bool {
  let mut offset = 0
  while offset < data.length() {
    let written = match self {
      Plain(connection) =>
        connection.write_once(data, offset~, len=data.length() - offset)
      Secure(connection) =>
        connection.write_once(data, offset~, len=data.length() - offset)
    }
    guard written > 0 else { return false }
    offset += written
  }
  true
}

///|
fn NativeTransport::close(self : NativeTransport) -> Unit {
  match self {
    Plain(connection) => connection.close()
    Secure(connection) => connection.close()
  }
}

///|
pub struct NativeClient {
  transport : NativeTransport
  session : @mqtt.ClientSession
  decoder : @mqtt.PacketStreamDecoder
  read_chunk_size : Int
  mut closed : Bool
}

///|
async fn open_transport(options : NativeOptions) -> NativeTransport {
  let tcp = @socket.Tcp::connect_to_host(options.host, port=options.port)
  if options.tls {
    let trust = if options.verify_tls {
      @tls.TrustedRoot::SystemRoot
    } else {
      @tls.TrustedRoot::NoVerification
    }
    Secure(@tls.Tls::client(tcp, host=options.host, trust~))
  } else {
    Plain(tcp)
  }
}

///|
pub async fn NativeClient::connect(
  options : NativeOptions,
  connect_packet : @mqtt.ConnectPacket,
) -> Result[NativeClient, @mqtt.MqttError] {
  let transport = open_transport(options)
  let session = @mqtt.ClientSession::new()
  let client = NativeClient::{
    transport,
    session,
    decoder: @mqtt.PacketStreamDecoder::new(),
    read_chunk_size: options.read_chunk_size,
    closed: false,
  }
  let packet = match session.begin_connect(connect_packet) {
    Ok(value) => value
    Err(err) => {
      client.close()
      return Err(err)
    }
  }
  match client.send(packet) {
    Err(err) => {
      client.close()
      return Err(err)
    }
    Ok(_) => ()
  }
  while client.session.state() == @mqtt.ConnectionState::AwaitingConnAck {
    let events = match client.receive() {
      Ok(value) => value
      Err(err) => {
        client.close()
        return Err(err)
      }
    }
    for event in events {
      match event {
        @mqtt.SessionEvent::DisconnectedEvent(reason_code, properties) => {
          client.close()
          return Err(
            @mqtt.MqttError::ConnectionRejected(reason_code, properties),
          )
        }
        _ => ()
      }
    }
  }
  if client.session.state() != @mqtt.ConnectionState::Connected {
    client.close()
    return Err(
      @mqtt.MqttError::InvalidState("connection closed before CONNACK"),
    )
  }
  Ok(client)
}

///|
pub fn NativeClient::session(self : NativeClient) -> @mqtt.ClientSession {
  self.session
}

///|
pub fn NativeClient::is_closed(self : NativeClient) -> Bool {
  self.closed
}

///|
pub fn NativeClient::close(self : NativeClient) -> Unit {
  if !self.closed {
    self.closed = true
    self.transport.close()
    self.session.mark_transport_closed()
  }
}

///|
pub async fn NativeClient::send(
  self : NativeClient,
  packet : @mqtt.Packet,
) -> Result[Unit, @mqtt.MqttError] {
  if self.closed {
    return Err(@mqtt.MqttError::InvalidState("transport is closed"))
  }
  let bytes = match @mqtt.encode_packet(packet) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  if bytes.length() > self.session.server_maximum_packet_size() {
    return Err(
      @mqtt.MqttError::ValueOutOfRange(
        "server Maximum Packet Size",
        bytes.length(),
      ),
    )
  }
  if self.transport.write_all(bytes) {
    Ok(())
  } else {
    self.close()
    Err(@mqtt.MqttError::InvalidState("transport closed during write"))
  }
}

///|
pub async fn NativeClient::receive(
  self : NativeClient,
) -> Result[Array[@mqtt.SessionEvent], @mqtt.MqttError] {
  if self.closed {
    return Err(@mqtt.MqttError::InvalidState("transport is closed"))
  }
  let packets : Array[@mqtt.Packet] = []
  while packets.is_empty() {
    match self.transport.read_some(self.read_chunk_size) {
      None => {
        self.close()
        return Ok([])
      }
      Some(chunk) =>
        match self.decoder.feed(chunk) {
          Err(err) => return Err(err)
          Ok(decoded) =>
            for packet in decoded {
              packets.push(packet)
            }
        }
    }
  }
  let events : Array[@mqtt.SessionEvent] = []
  for packet in packets {
    let outcome = match self.session.handle_incoming(packet) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    for response in outcome.responses {
      match self.send(response) {
        Err(err) => return Err(err)
        Ok(_) => ()
      }
    }
    for event in outcome.events {
      events.push(event)
    }
  }
  Ok(events)
}

///|
pub async fn NativeClient::publish(
  self : NativeClient,
  topic : String,
  payload : Bytes,
  qos? : @mqtt.QoS = @mqtt.QoS::AtMostOnce,
  retain? : Bool = false,
  properties? : Array[@mqtt.Property] = [],
) -> Result[Unit, @mqtt.MqttError] {
  let packet = match
    self.session.prepare_publish(topic, payload, qos~, retain~, properties~) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  self.send(packet)
}

///|
pub async fn NativeClient::subscribe(
  self : NativeClient,
  subscriptions : Array[@mqtt.Subscription],
  properties? : Array[@mqtt.Property] = [],
) -> Result[Unit, @mqtt.MqttError] {
  let packet = match
    self.session.prepare_subscribe(subscriptions, properties~) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  self.send(packet)
}

///|
pub async fn NativeClient::unsubscribe(
  self : NativeClient,
  topic_filters : Array[String],
  properties? : Array[@mqtt.Property] = [],
) -> Result[Unit, @mqtt.MqttError] {
  let packet = match
    self.session.prepare_unsubscribe(topic_filters, properties~) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  self.send(packet)
}

///|
pub async fn NativeClient::ping(
  self : NativeClient,
) -> Result[Unit, @mqtt.MqttError] {
  let packet = match self.session.prepare_ping() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  self.send(packet)
}

///|
pub async fn NativeClient::disconnect(
  self : NativeClient,
  reason_code? : Byte = 0,
  properties? : Array[@mqtt.Property] = [],
) -> Result[Unit, @mqtt.MqttError] {
  let packet = match
    self.session.prepare_disconnect(reason_code~, properties~) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let result = self.send(packet)
  self.close()
  result
}
