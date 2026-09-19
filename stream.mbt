///|
pub struct PacketStreamDecoder {
  mut buffered : Array[Byte]
  max_packet_size : Int
}

///|
pub fn PacketStreamDecoder::new() -> PacketStreamDecoder {
  { buffered: [], max_packet_size: MAX_VARIABLE_BYTE_INTEGER + 5, }
}

///|
/// Creates a stream decoder that rejects a single MQTT packet larger than
/// `max_packet_size` bytes, including the fixed header.
pub fn PacketStreamDecoder::with_max_packet_size(
  max_packet_size : Int,
) -> Result[PacketStreamDecoder, MqttError] {
  if max_packet_size < 2 {
    return Err(ValueOutOfRange("maximum packet size", max_packet_size))
  }
  Ok({ buffered: [], max_packet_size, })
}

///|
pub fn PacketStreamDecoder::buffered_bytes(self : PacketStreamDecoder) -> Int {
  self.buffered.length()
}

///|
pub fn PacketStreamDecoder::max_packet_size(self : PacketStreamDecoder) -> Int {
  self.max_packet_size
}

///|
pub fn PacketStreamDecoder::reset(self : PacketStreamDecoder) -> Unit {
  self.buffered.clear()
}

///|
pub fn PacketStreamDecoder::feed(
  self : PacketStreamDecoder,
  chunk : Bytes,
) -> Result[Array[Packet], MqttError] {
  for byte in chunk {
    self.buffered.push(byte)
  }
  let packets : Array[Packet] = []
  while !self.buffered.is_empty() {
    let data = Bytes::from_iter(self.buffered.iter())
    match decode_packet(data) {
      Err(NeedMoreData) => {
        if self.buffered.length() > self.max_packet_size {
          return Err(
            ValueOutOfRange("MQTT packet size", self.buffered.length()),
          )
        }
        break
      }
      Err(err) => return Err(err)
      Ok((packet, consumed)) => {
        if consumed > self.max_packet_size {
          return Err(ValueOutOfRange("MQTT packet size", consumed))
        }
        packets.push(packet)
        let remaining : Array[Byte] = []
        for index = consumed; index < self.buffered.length(); index = index + 1 {
          remaining.push(self.buffered[index])
        }
        self.buffered = remaining
      }
    }
  }
  Ok(packets)
}
