# Auto-Smaart

Mac app for one DiGiCo Quantum 225 Matrix output per pass. It reads Rational Acoustics Smaart through the local official API and writes delay and EQ only after confirm.

## Run the tests

On a Mac, from this directory:

```bash
swift test
```

`swift test --filter Quantum225HardwareTests` skips unless all of these are set:

- `AUTO_SMAART_HARDWARE=1`
- `AUTO_SMAART_CONSOLE_HOST` — the console IP typed into Pick
- `AUTO_SMAART_CONSOLE_PORT` — the console OSC port
- `AUTO_SMAART_MATRIX` — one output from 1 through 12

That test writes delay to both delay addresses, writes at least one EQ band, remeasures, then undoes the write. Smaart must be open with the API enabled on port 26000.

## Run the app

```bash
swift run AutoSmaart
```

There is no default console address. Nothing is sent before Confirm delay write or Confirm EQ write.
