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
- `cfg.juiceline`: MonkeyLogic reward line that drives the pump
- `cfg.fluid_density_g_per_ml`: `1.0` for water-like fluids

## Run In MonkeyLogic

Load `pump_calibration_conditions.txt` as the conditions file. It runs
`ml_pump_calibration.m` once, writes a CSV, and then pauses MonkeyLogic.

Make sure the pump output lands in a container on the scale. The CSV is written
to `data/pump_calibration_YYYYMMDD_HHMMSS.csv`.

## Quick Scale Test In MATLAB

This does not run the pump:

```matlab
cfg = pump_calibration_config;
scale_port = resolve_scale_port_matlab(cfg);
s = serialport(scale_port, cfg.scale_baud, ...
    'DataBits', cfg.scale_databits, ...
    'Parity', cfg.scale_parity, ...
    'StopBits', cfg.scale_stopbits, ...
    'Timeout', cfg.scale_timeout_s);
configureTerminator(s, 'LF');
r = read_scale_weight_matlab(s, cfg)
clear s
```

## Multiple Serial Ports

First list the ports:

```matlab
serialportlist("available")
```

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
