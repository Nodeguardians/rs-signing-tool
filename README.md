# Replicated Security Signature Check

## Usage

- Create a `.env` file with the following contents (at the root of the script):

```bash
VALIDATOR_HEX_ADDRESS="2C8E45AB480021B3B903B92721D55BA7702A6601" # Default
SLACK_WEBHOOK="https://hooks.slack.com/services/..."
CHAIN_ID="pion-1" # Default
NUMBER_OF_BLOCKS_TO_CHECK=10 # Default
HEALTHCHECK_UUID="<uuid_healthcheck.io>"
```

- We want the script to run every hour, but we want the logs in `journalctl`. So create the following service file (`neutron-check.service`):

```bash
[Unit]
Description=Check Neutron Validator Signature and send Slack notification if not valid

[Service]
Type=oneshot
User=neutron
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin:/home/neutron/go/bin"
ExecStart=/bin/bash /home/neutron/replicated-security-signature-check/check_signature.sh
```

- Now, create a timer file (`neutron-check.timer`):

```bash
[Unit]
Description=Runs neutron-check.service every set interval

[Timer]
OnUnitActiveSec=1h
Unit=neutron-check.service

[Install]
WantedBy=timers.target
```

- Then, enable/start the **timer**:

```bash
systemctl enable neutron-check.timer
systemctl start neutron-check.timer
```

To check the status of the timer:

```bash
> systemctl status neutron-check.timer
● neutron-check.timer - Runs neutron-check.service every set interval
     Loaded: loaded (/etc/systemd/system/neutron-check.timer; enabled; vendor preset: enabled)
     Active: active (waiting) since Thu 2023-05-04 14:33:31 CEST; 9s ago
    Trigger: Thu 2023-05-04 15:33:22 CEST; 59min left
   Triggers: ● neutron-check.service
```
