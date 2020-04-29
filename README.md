# Kitty Breeder

[Kitty](https://sw.kovidgoyal.net/kitty/) is my favorite new terminal emulator, but it has one problem: it takes a long time to launch new instances, even in single-instance mode. This script maintains a pool of background Kitty instances and unhides an instance when you request it.

Compatible with i3 only for now.

# Status

Not working at the moment. Launching a new terminal causes a deadlock when using `flock`, not sure why. But if that was fixed I'm pretty sure it would work.
