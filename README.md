# Pump Calibration

This folder contains a MonkeyLogic pump calibration task that measures pump
output on the serial scale.

## Scale Setup

Set the scale to continuous RS-232 output:

```text
F3 SEr -> S 232 -> P2 Con -> b 4800 -> 8 n 1
```

The MATLAB scripts use `cfg.scale_port = 'auto'` by default. If one serial
port is available, they will use it. If several ports are available, set
`cfg.scale_port` manually in `pump_calibration_config.m`, for example `COM7`.
Alternatively, set `cfg.auto_probe_scale_port = true` to probe ports for
scale-like continuous output.

## Configure

Edit `pump_calibration_config.m`.

Important fields:

- `cfg.scale_port`: serial port for the scale, or `'auto'`
- `cfg.auto_probe_scale_port`: set `true` to probe multiple serial ports
- `cfg.durations_ms`: pump durations tested by `goodmonkey`, in ms
- `cfg.repetitions`: repeats per duration
- `cfg.DRY_REWARD`: set `true` to skip `goodmonkey` and leave the pump off
- `cfg.scale_require_stable`: set `true` to ignore scale lines marked `US`
- `cfg.juiceline`: MonkeyLogic reward line that drives the pump
- `cfg.fluid_density_g_per_ml`: `1.0` for water-like fluids

## Run In MonkeyLogic

Load `pump_calibration_conditions.txt` as the conditions file. It runs
`ml_pump_calibration.m` once, writes a CSV, and then pauses MonkeyLogic.
The conditions file includes a dummy `TaskObject#1` fixation object because
MonkeyLogic requires at least one TaskObject header.

Make sure the pump output lands in a container on the scale. The CSV is written
to `data/pump_calibration_YYYYMMDD_HHMMSS.csv`.

For debugging without the pump, set this in `pump_calibration_config.m`:

```matlab
cfg.DRY_REWARD = true;
```

Dry mode skips `goodmonkey`, waits for each requested duration, and logs
`dry_reward = 1` in the CSV.

## Scale Raw Strings

The raw columns keep the exact scale lines used for the baseline/post readings.
For example:

```text
US,NT-      0.355 g | US,NT-      0.335 g | US,NT-      0.310 g
```

This means three scale samples were read because `cfg.scale_samples = 3`.
`US` means unstable, `NT` means net/tared weight, and the `-` means the value is
negative. If you want to wait for stable lines only, set:

```matlab
cfg.scale_require_stable = true;
```

## Quick Scale Test In MATLAB

This does not run the pump:

```matlab
cfg = pump_calibration_config;
scale_port = resolve_scale_port_matlab(cfg);
s = open_scale_serial_matlab(scale_port, cfg);
r = read_scale_weight_matlab(s, cfg)
pump_clear_scale(s)
```

## Multiple Serial Ports

First list the ports:

```matlab
scale_available_ports_matlab()
```

If MonkeyLogic reports that it cannot find an exact case-sensitive match for
`serialport` and points to `SerialPort.m`, that is MonkeyLogic's own serial
class, not MATLAB's newer lowercase `serialport` API. The calibration helpers
detect this and fall back to MATLAB's legacy `serial` API automatically.

Safest option: set the scale port explicitly:

```matlab
cfg.scale_port = 'COM7';
```

Convenience option: keep `cfg.scale_port = 'auto'` and enable probing:

```matlab
cfg.auto_probe_scale_port = true;
cfg.scale_probe_timeout_s = 2;
```

Probing opens each available serial port briefly and looks for lines like
`GS 0.00g`, so use it only when opening the other serial devices on that
computer is harmless.

## Analyze Calibration

After collecting a pump calibration CSV, run:

```matlab
analyze_pump_calibration
```

With no arguments, it analyzes the newest `pump_calibration_*.csv` file in
`data/`. To analyze a specific file:

```matlab
analyze_pump_calibration('data/pump_calibration_YYYYMMDD_HHMMSS.csv')
```

The analysis:

- computes mean delivered volume and SEM for each `duration_ms`
- fits `delivered_uL = offset + gain * duration_seconds ^ exponent`
- saves a PNG with mean +/- SEM and the nonlinear trendline
- saves predictions from 100 ms to 3000 ms in 100 ms steps

Outputs are saved beside the input CSV:

```text
*_summary.csv
*_fit_predictions.csv
*_fit.png
```

By default, dry-reward rows are excluded. To analyze a dry-run CSV anyway:

```matlab
analyze_pump_calibration('', true)
```
