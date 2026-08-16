# System configuration

This directory is reserved for reviewed source copies of root-owned settings,
such as a deliberate file below `/etc`. Nothing here is automatically applied.

System restoration should use small, idempotent installation steps that show a
diff and request root access only for the exact destination. Do not copy the
whole of `/etc` into this repository.

