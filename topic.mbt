///|
/// Tests whether an MQTT topic name matches a subscription filter.
///
/// The matcher implements single-level (`+`) and multi-level (`#`)
/// wildcards, the system-topic rule for names beginning with `$`, and shared
/// subscription filters. Invalid topic names or filters are rejected instead
/// of being treated as a non-match.
pub fn topic_matches(
  topic_filter : String,
  topic_name : String,
) -> Result[Bool, MqttError] {
  match validate_topic_filter(topic_filter) {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  match validate_topic_name(topic_name, "topic name") {
    Err(err) => return Err(err)
    Ok(_) => ()
  }
  let effective_filter = if topic_filter.has_prefix("$share/") {
    let shared = topic_filter.strip_prefix("$share/").unwrap()
    shared.split_once("/").unwrap().1.to_owned()
  } else {
    topic_filter
  }
  if topic_name.has_prefix("$") && !effective_filter.has_prefix("$") {
    return Ok(false)
  }
  let filter_levels = effective_filter.split("/").collect()
  let topic_levels = topic_name.split("/").collect()
  let mut filter_index = 0
  let mut topic_index = 0
  while filter_index < filter_levels.length() {
    let level = filter_levels[filter_index]
    if level == "#" {
      return Ok(true)
    }
    if topic_index >= topic_levels.length() {
      return Ok(false)
    }
    if level != "+" && level != topic_levels[topic_index] {
      return Ok(false)
    }
    filter_index += 1
    topic_index += 1
  }
  Ok(topic_index == topic_levels.length())
}
