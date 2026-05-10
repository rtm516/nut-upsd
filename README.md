# NUT upsd - Docker image
[![License: GPL-3.0](https://img.shields.io/github/license/rtm516/nut-upsd)](LICENSE)
[![Build Release](https://github.com/rtm516/nut-upsd/actions/workflows/build.yml/badge.svg)](https://github.com/rtm516/nut-upsd/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/v/release/rtm516/nut-upsd)](https://github.com/rtm516/nut-upsd/releases)

Minimal Alpine-based Docker image running [Network UPS Tools](https://networkupstools.org/) `upsd`.
A GitHub Actions workflow automatically rebuilds the image when a new NUT release is published.

## Quick start
A example `docker-compose.yml` is included. At minimum, mount your `ups.conf` and set monitor credentials via environment variables.

Example `ups.conf`:
```conf
# /etc/nut/ups.conf
# See: https://networkupstools.org/docs/man/ups.conf.html
#
# Each section defines a UPS that upsd will serve.
# The driver must match your hardware

[myups]
  driver = mydriver
  port = /dev/ttyS1
  cable = 1234
  desc = "Something descriptive"
```

## Configuration

The only required mount is `ups.conf`, everything else is driven by environment variables.

### Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `UPSMON_USER` | `upsmon` | Monitor username for `upsd.users` |
| `UPSMON_PASSWORD` | *(random)* | Monitor password — logged on boot if auto-generated |
| `UPSMON_ROLE` | `primary` | `primary` or `secondary` |
| `UPSD_LISTEN` | `0.0.0.0` | Listen address |
| `UPSD_PORT` | `3493` | Listen port |
| `UPSD_MAXAGE` | `15` | Seconds before data is considered stale |
| `GENERATE_USERS` | `true` | Set `false` to skip generation and mount your own `upsd.users` |
