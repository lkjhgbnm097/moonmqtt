///|
pub struct PacketStreamDecoder {
  mut buffered : Array[Byte]
}

///|
pub fn PacketStreamDecoder::new() -> PacketStreamDecoder {
  { buffered: [], }
}

///|
pub fn PacketStreamDecoder::buffered_bytes(self : PacketStreamDecoder) -> Int {
  self.buffered.length()
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
      Err(NeedMoreData) => break
      Err(err) => return Err(err)
      Ok((packet, consumed)) => {
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
