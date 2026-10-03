# S6

```text
JOBS/watchdog/
├── run.sh
├── env/
│   └── S9_ON_UNIT_INACTIVE_SEC
└── data/launch/.gitignore

STATE/
├── services/watchdog/
│   ├── data/
│   │   ├── lstart
│   │   └── launch/
│   │       └── <pid> -> ../lstart
│   ├── template/
│   ├── instance/
│   │   └── <pid> -> ../instances/<pid>
│   └── instances/
│       └── <pid>/
│           ├── env/S9_ON_UNIT_INACTIVE_SEC
│           └── data/job
├── log/
│   ├── s6.log
│   └── watchdog/<pid>.log
├── dead/watchdog/<pid>.<timestamp>/
│   ├── log
│   ├── exit_status
│   └── signal
└── failed/watchdog/<pid>.<timestamp> -> ../../dead/watchdog/<pid>.<timestamp>
```
