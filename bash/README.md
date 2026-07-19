## Bash Commands

[back](../README.md)

```bash

netstat -ano | findstr 8080
netstat -ano | grep 8080
# tcp 0.0.0.0:8080 listening 5136

taskkill /pid 5136 /F
# Success: the process with PID 5136 has been terminated.
```
