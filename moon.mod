// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "moonmqtt/moonmqtt"

version = "0.1.0"

readme = "README.md"

repository = ""

license = "Apache-2.0"

keywords = [ "mqtt", "iot", "protocol", "networking", "moonbit" ]

preferred_target = "native"

description = "Portable MQTT 5.0 codec, client state machine, and native TCP/TLS client"

import {
  "moonbitlang/async@0.21.0",
}
