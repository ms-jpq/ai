# S6

```text
JOBS/watchdog/
├── run.sh
├── env/
│   ├── S67_DAEMON
│   └── S67_ON_UNIT_INACTIVE_SEC
└── data/launch/.gitignore

STATE/watchdog/
├── data/
│   ├── lstart
│   └── launch/
│       └── <pid> -> ../lstart
├── template/
├── instance/
│   └── <pid> -> ../instances/<pid>
└── instances/
    └── <pid>/
        ├── env/S67_DAEMON
        └── data/job
```
