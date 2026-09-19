///|
pub(all) enum QueueOverflowPolicy {
  RejectNewest
  DropOldest
} derive(Eq, Debug)

///|
pub(all) struct QueuedPublish {
  topic : String
  payload : Bytes
  qos : QoS
  retain : Bool
  properties : Array[Property]
} derive(Eq, Debug)

///|
/// Bounded queue for application publishes produced while a transport is
/// disconnected. Packet identifiers are intentionally assigned only when an
/// item is later handed to `ClientSession::prepare_publish`.
pub struct OfflinePublishQueue {
  capacity : Int
  overflow_policy : QueueOverflowPolicy
  items : Array[QueuedPublish]
}

///|
pub fn OfflinePublishQueue::new(
  capacity : Int,
  overflow_policy? : QueueOverflowPolicy = RejectNewest,
) -> Result[OfflinePublishQueue, MqttError] {
  if capacity <= 0 {
    return Err(ValueOutOfRange("offline queue capacity", capacity))
  }
  Ok({ capacity, overflow_policy, items: [], })
}

///|
pub fn OfflinePublishQueue::capacity(self : OfflinePublishQueue) -> Int {
  self.capacity
}

///|
pub fn OfflinePublishQueue::length(self : OfflinePublishQueue) -> Int {
  self.items.length()
}

///|
pub fn OfflinePublishQueue::is_empty(self : OfflinePublishQueue) -> Bool {
  self.items.is_empty()
}

///|
pub fn OfflinePublishQueue::peek(self : OfflinePublishQueue) -> QueuedPublish? {
  if self.items.is_empty() {
    None
  } else {
    Some(self.items[0])
  }
}

///|
/// Enqueues a validated publish request. The returned value is the item that
/// was evicted when `DropOldest` is configured, or `None` otherwise.
pub fn OfflinePublishQueue::enqueue(
  self : OfflinePublishQueue,
  topic : String,
  payload : Bytes,
  qos? : QoS = AtMostOnce,
  retain? : Bool = false,
  properties? : Array[Property] = [],
) -> Result[QueuedPublish?, MqttError] {
  let packet_id : UInt16? = if qos == AtMostOnce { None } else { Some(1) }
  match
    validate_packet(
      PublishPacket({
        topic,
        payload,
        qos,
        retain,
        duplicate: false,
        packet_id,
        properties,
      }),
    ) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let queued = QueuedPublish::{ topic, payload, qos, retain, properties, }
  let dropped = if self.items.length() == self.capacity {
    match self.overflow_policy {
      RejectNewest => return Err(InvalidState("offline publish queue is full"))
      DropOldest => Some(self.items.remove(0))
    }
  } else {
    None
  }
  self.items.push(queued)
  Ok(dropped)
}

///|
pub fn OfflinePublishQueue::dequeue(
  self : OfflinePublishQueue,
) -> QueuedPublish? {
  if self.items.is_empty() {
    None
  } else {
    Some(self.items.remove(0))
  }
}

///|
pub fn OfflinePublishQueue::clear(self : OfflinePublishQueue) -> Unit {
  self.items.clear()
}
