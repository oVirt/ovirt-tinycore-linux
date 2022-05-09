## oVirt TinyCore Linux

oVirt TinyCore Linux is a customized version of TinyCore Linux that includes a pre-installed and running Qemu Guest Agent.

Currently implemented features:

* Qemu Guest Agent
* IPv6 support
* ACPI support
* Support for hot-pluggable CPUs and NICs
  `NOTE: Support for Block devices is already included in plain TinyCore Linux, and hot-plugging RAM is generally only supported in 64-bit Linux kernels` [^1]

[^1]: https://www.kernel.org/doc/html/latest/admin-guide/mm/memory-hotplug.html
