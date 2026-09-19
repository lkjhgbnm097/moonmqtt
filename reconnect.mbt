///|
/// Configuration for reconnect attempts.
///
/// `max_attempts = 0` means unlimited attempts. Jitter is supplied to
/// `delay_for_attempt` by the transport layer so the protocol core remains
/// deterministic and portable across all MoonBit backends.
pub(all) struct ReconnectPolicy {
  initial_delay_ms : Int
  max_delay_ms : Int
  multiplier : Int
  max_attempts : Int
} derive(Eq, Debug)

///|
pub fn ReconnectPolicy::new(
  initial_delay_ms? : Int = 1000,
  max_delay_ms? : Int = 30000,
  multiplier? : Int = 2,
  max_attempts? : Int = 0,
) -> Result[ReconnectPolicy, MqttError] {
  if initial_delay_ms <= 0 {
    return Err(ValueOutOfRange("initial reconnect delay", initial_delay_ms))
  }
  if max_delay_ms < initial_delay_ms {
    return Err(ValueOutOfRange("maximum reconnect delay", max_delay_ms))
  }
  if multiplier < 2 {
    return Err(ValueOutOfRange("reconnect multiplier", multiplier))
  }
  if max_attempts < 0 {
    return Err(ValueOutOfRange("maximum reconnect attempts", max_attempts))
  }
  Ok({ initial_delay_ms, max_delay_ms, multiplier, max_attempts, })
}

///|
pub fn ReconnectPolicy::allows_attempt(
  self : ReconnectPolicy,
  attempt : Int,
) -> Bool {
  attempt >= 0 && (self.max_attempts == 0 || attempt < self.max_attempts)
}

///|
/// Returns the capped exponential delay for a zero-based attempt.
///
/// `jitter_percent` is a caller-provided sample in the inclusive range
/// `-25..25`. A random-capable transport can supply a new sample per attempt;
/// tests and deterministic runtimes can pass zero.
pub fn ReconnectPolicy::delay_for_attempt(
  self : ReconnectPolicy,
  attempt : Int,
  jitter_percent? : Int = 0,
) -> Result[Int, MqttError] {
  if !self.allows_attempt(attempt) {
    return Err(InvalidState("reconnect attempt limit reached"))
  }
  if jitter_percent < -25 || jitter_percent > 25 {
    return Err(ValueOutOfRange("reconnect jitter percent", jitter_percent))
  }
  let mut delay = self.initial_delay_ms
  let mut step = 0
  while step < attempt {
    if delay > self.max_delay_ms / self.multiplier {
      delay = self.max_delay_ms
      break
    }
    delay *= self.multiplier
    step += 1
  }
  let magnitude = if jitter_percent < 0 {
    -jitter_percent
  } else {
    jitter_percent
  }
  let adjustment = delay / 100 * magnitude + delay % 100 * magnitude / 100
  let jittered = if jitter_percent < 0 {
    delay - adjustment
  } else {
    delay + adjustment
  }
  Ok(if jittered > self.max_delay_ms { self.max_delay_ms } else { jittered })
}
