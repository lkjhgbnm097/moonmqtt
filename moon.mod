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

repository = "https://github.com/lkjhgbnm097/moonmqtt"

license = "Apache-2.0"

keywords = [ "mqtt", "iot", "policy", "data-governance", "moonbit" ]

preferred_target = "native"

description = "MQTT 5 message-contract and release-policy gate for MoonBit"

import {
  "moonbitlang/async@0.21.0",
}
