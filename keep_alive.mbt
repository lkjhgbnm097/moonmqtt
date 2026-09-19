///|
pub(all) enum KeepAliveAction {
  Idle
  SendPing
  TimedOut
} derive(Eq, Debug)

///|
/// Deterministic MQTT keep-alive scheduler driven by a monotonic clock.
///
/// The transport supplies timestamps in milliseconds. A zero keep-alive
/// interval disables scheduling, as defined by MQTT 5.0.
pub struct KeepAliveTracker {
  interval_ms : Int
  mut last_activity_ms : Int
  mut ping_sent_at_ms : Int?
}

///|
pub fn KeepAliveTracker::new(
  keep_alive_seconds : Int,
  start_ms? : Int = 0,
) -> Result[KeepAliveTracker, MqttError] {
  if keep_alive_seconds < 0 || keep_alive_seconds > 65535 {
    return Err(ValueOutOfRange("keep alive seconds", keep_alive_seconds))
  }
  if start_ms < 0 {
    return Err(ValueOutOfRange("keep alive start time", start_ms))
  }
  Ok({
    interval_ms: keep_alive_seconds * 1000,
    last_activity_ms: start_ms,
    ping_sent_at_ms: None,
  })
}

///|
pub fn KeepAliveTracker::interval_ms(self : KeepAliveTracker) -> Int {
  self.interval_ms
}

///|
pub fn KeepAliveTracker::has_ping_outstanding(self : KeepAliveTracker) -> Bool {
  self.ping_sent_at_ms is Some(_)
}

///|
fn KeepAliveTracker::check_time(
  self : KeepAliveTracker,
  now_ms : Int,
) -> Result[Unit, MqttError] {
  if now_ms < self.last_activity_ms {
    Err(InvalidState("keep alive clock moved backwards"))
  } else {
    Ok(())
  }
}

///|
pub fn KeepAliveTracker::record_activity(
  self : KeepAliveTracker,
  now_ms : Int,
) -> Result[Unit, MqttError] {
  match self.check_time(now_ms) {
    Err(err) => Err(err)
    Ok(_) => {
      self.last_activity_ms = now_ms
      Ok(())
    }
  }
}

///|
pub fn KeepAliveTracker::mark_ping_sent(
  self : KeepAliveTracker,
  now_ms : Int,
) -> Result[Unit, MqttError] {
  match self.check_time(now_ms) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  if self.interval_ms == 0 {
    return Err(InvalidState("keep alive scheduling is disabled"))
  }
  if self.ping_sent_at_ms is Some(_) {
    return Err(InvalidState("a keep alive ping is already outstanding"))
  }
  self.last_activity_ms = now_ms
  self.ping_sent_at_ms = Some(now_ms)
  Ok(())
}

///|
pub fn KeepAliveTracker::mark_ping_response(
  self : KeepAliveTracker,
  now_ms : Int,
) -> Result[Unit, MqttError] {
  match self.check_time(now_ms) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  if self.ping_sent_at_ms is None {
    return Err(InvalidState("no keep alive ping is outstanding"))
  }
  self.ping_sent_at_ms = None
  self.last_activity_ms = now_ms
  Ok(())
}

///|
pub fn KeepAliveTracker::poll(
  self : KeepAliveTracker,
  now_ms : Int,
) -> Result[KeepAliveAction, MqttError] {
  match self.check_time(now_ms) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  if self.interval_ms == 0 {
    return Ok(Idle)
  }
  match self.ping_sent_at_ms {
    Some(sent_at) =>
      if now_ms - sent_at >= self.interval_ms {
        Ok(TimedOut)
      } else {
        Ok(Idle)
      }
    None =>
      if now_ms - self.last_activity_ms >= self.interval_ms {
        Ok(SendPing)
      } else {
        Ok(Idle)
      }
  }
}
