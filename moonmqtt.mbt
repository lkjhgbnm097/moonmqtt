///|
/// MoonMQTT is a portable MQTT 5.0 protocol toolkit for MoonBit.
///
/// The root package intentionally contains no platform I/O. Packet codecs and
/// the session state machine therefore run unchanged on native, JavaScript,
/// and WebAssembly targets. Platform transports live in dedicated packages.
pub const PROTOCOL_LEVEL : Int = 5

///|
pub const MAX_VARIABLE_BYTE_INTEGER : Int = 268435455
