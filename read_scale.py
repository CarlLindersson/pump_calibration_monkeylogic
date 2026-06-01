"""Read weights from the Portable Series balance over RS-232/USB serial.

The manual's default communication settings are:
  4800 baud, 8 data bits, no parity, 1 stop bit, ASCII.

The balance prints a reading when it receives:
  P<CR><LF>

Examples:
  python read_scale.py --list-ports
  python read_scale.py --port COM3 --once
  python read_scale.py --port COM3 --raw
  python read_scale.py --port COM3 --once --max-seconds 10
  python read_scale.py --port COM3 --no-request --once
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import sys
import time
from dataclasses import asdict, dataclass

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("pyserial is required. In your conda env, run: conda install pyserial")
    raise


NUMBER_RE = re.compile(r"[-+]?\d{1,3}(?:,\d{3})*(?:\.\d+)?|[-+]?\d+(?:\.\d+)?")
READING_RE = re.compile(
    r"^\s*(?:(?P<status>[A-Za-z](?:\s*[A-Za-z]){0,2})\s+)?"
    r"(?P<weight>[-+]?\d{1,3}(?:,\d{3})*(?:\.\d+)?|[-+]?\d+(?:\.\d+)?)"
    r"\s*(?P<unit>[A-Za-z%./0-9]*)"
)


@dataclass
class Reading:
    weight: float
    unit: str = ""
    status: str = ""
    raw: str = ""


def list_serial_ports():
    return list(serial.tools.list_ports.comports())


def print_serial_ports() -> None:
    ports = list_serial_ports()
    if not ports:
        print("No serial ports found.")
        return

    for port in ports:
        parts = [port.device]
        if port.description:
            parts.append(port.description)
        if port.hwid:
            parts.append(port.hwid)
        print(" | ".join(parts))


def auto_select_port() -> str | None:
    ports = list_serial_ports()
    if not ports:
        return None
    if len(ports) == 1:
        return ports[0].device

    for port in ports:
        desc = (port.description or "").lower()
        hwid = (port.hwid or "").lower()
        if any(token in f"{desc} {hwid}" for token in ("usb", "cp210", "ftdi", "ch340")):
            return port.device

    return ports[0].device


def decode_escaped_ascii(text: str) -> bytes:
    """Turn command-line text like 'P\\r\\n' into ASCII bytes."""
    return bytes(text, "utf-8").decode("unicode_escape").encode("ascii")


def parse_weight_from_line(line: str) -> Reading | None:
    text = line.strip()
    if not text:
        return None
    if text.upper().startswith("ERR"):
        return None

    match = READING_RE.search(text)
    if match:
        weight = match.group("weight").replace(",", "")
        try:
            return Reading(
                weight=float(weight),
                unit=match.group("unit") or "",
                status=(match.group("status") or "").replace(" ", "").upper(),
                raw=line,
            )
        except ValueError:
            return None

    match = NUMBER_RE.search(text.replace(" ", ""))
    if not match:
        match = NUMBER_RE.search(text)
    if not match:
        return None

    try:
        return Reading(weight=float(match.group(0).replace(",", "")), raw=line)
    except ValueError:
        return None


def format_reading(reading: Reading, output_format: str) -> str:
    if output_format == "json":
        return json.dumps(asdict(reading))
    if output_format == "raw":
        return reading.raw

    pieces = [f"{reading.weight:g}"]
    if reading.unit:
        pieces.append(reading.unit)
    if reading.status:
        pieces.append(f"[{reading.status}]")
    return " ".join(pieces)


def open_serial(args) -> serial.Serial:
    return serial.Serial(
        port=args.port,
        baudrate=args.baud,
        bytesize=args.bytesize,
        parity=args.parity,
        stopbits=args.stopbits,
        timeout=args.timeout,
        write_timeout=args.timeout,
    )


def read_until_reading(args, ser: serial.Serial, request: bytes) -> bool:
    ser.reset_input_buffer()
    next_request_time = 0.0
    deadline = time.monotonic() + args.max_seconds if args.max_seconds else None
    request_sent = False
    request_once = args.request_once or (args.once and not args.repeat_request)
    saw_reading = False

    while True:
        now = time.monotonic()
        if deadline and now >= deadline:
            return saw_reading

        if request and not request_sent and now >= next_request_time:
            logging.debug("Sending request: %r", request)
            ser.write(request)
            ser.flush()
            request_sent = request_once
            next_request_time = now + args.interval

        raw = ser.readline()
        if not raw:
            continue

        line = raw.decode("ascii", errors="replace").strip()
        if args.dump_bytes:
            print(f"RAW: {raw!r} | HEX: {' '.join(f'{byte:02X}' for byte in raw)}", flush=True)
        logging.debug("Received raw bytes: %r", raw)
        if not line:
            continue

        reading = parse_weight_from_line(line)
        if reading:
            saw_reading = True
            print(format_reading(reading, args.format), flush=True)
            if args.once:
                return True
        elif args.show_unparsed:
            print(f"UNPARSED: {line}", flush=True)


def scan_port(args, request: bytes) -> int:
    bauds = [4800, 9600, 2400, 1200, 600]
    serial_formats = [(8, "N", 1), (7, "E", 1), (7, "O", 1)]
    original = (args.baud, args.bytesize, args.parity, args.stopbits, args.max_seconds, args.once)
    args.once = True
    args.max_seconds = args.scan_seconds

    try:
        for baud in bauds:
            for bytesize, parity, stopbits in serial_formats:
                args.baud = baud
                args.bytesize = bytesize
                args.parity = parity
                args.stopbits = stopbits
                logging.info("Trying %s @ %s baud, %s%s%s", args.port, baud, bytesize, parity, stopbits)
                try:
                    with open_serial(args) as ser:
                        if read_until_reading(args, ser, request):
                            logging.info("Matched %s baud, %s%s%s", baud, bytesize, parity, stopbits)
                            return 0
                except serial.SerialException as exc:
                    logging.error("Serial error while scanning: %s", exc)
                    return 1

        logging.error("No parsed scale reading found during scan")
        return 2
    finally:
        args.baud, args.bytesize, args.parity, args.stopbits, args.max_seconds, args.once = original


def main() -> int:
    parser = argparse.ArgumentParser(description="Read weight from RS-232 serial scale")
    parser.add_argument("--list-ports", action="store_true", help="List serial ports and exit")
    parser.add_argument("--port", help="Serial port, for example COM3")
    parser.add_argument("--baud", type=int, default=4800, help="Manual default: 4800")
    parser.add_argument("--bytesize", type=int, choices=[5, 6, 7, 8], default=8)
    parser.add_argument("--parity", choices=["N", "E", "O", "M", "S"], default="N")
    parser.add_argument("--stopbits", type=float, choices=[1, 1.5, 2], default=1)
    parser.add_argument("--timeout", type=float, default=1.0)
    parser.add_argument(
        "--request",
        default=r"P\r\n",
        help=r"Request sent before reads. Manual print command is P\r\n. Use '' to disable.",
    )
    parser.add_argument("--no-request", action="store_true", help="Do not send a print command; only listen")
    parser.add_argument("--interval", type=float, default=1.0, help="Polling interval in seconds")
    parser.add_argument("--once", action="store_true", help="Print one parsed reading and exit")
    parser.add_argument("--request-once", action="store_true", help="Send the request once, then only listen")
    parser.add_argument(
        "--repeat-request",
        action="store_true",
        help="With --once, keep polling at --interval until a reading is parsed",
    )
    parser.add_argument(
        "--max-seconds",
        type=float,
        help="Stop if no requested reading is parsed within this many seconds",
    )
    parser.add_argument("--raw", action="store_const", dest="format", const="raw", help="Alias for --format raw")
    parser.add_argument("--json", action="store_const", dest="format", const="json", help="Alias for --format json")
    parser.add_argument("--dump-bytes", action="store_true", help="Print every received serial chunk as repr and hex")
    parser.add_argument(
        "--format",
        choices=["text", "raw", "json"],
        default="text",
        help="Output format for successfully parsed readings",
    )
    parser.add_argument("--show-unparsed", action="store_true", help="Print lines that do not parse")
    parser.add_argument("--scan", action="store_true", help="Try the manual's supported baud/parity settings")
    parser.add_argument("--scan-seconds", type=float, default=3.0, help="Seconds to try each scanned setting")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO, format="%(message)s")

    if args.list_ports:
        print_serial_ports()
        return 0

    args.port = args.port or auto_select_port()
    if not args.port:
        logging.error("No serial ports found. Connect the USB serial adapter and try again.")
        return 1

    request = b"" if args.no_request else decode_escaped_ascii(args.request) if args.request else b""
    logging.info(
        "Using %s @ %s baud, %s%s%s",
        args.port,
        args.baud,
        args.bytesize,
        args.parity,
        args.stopbits,
    )
    if request:
        logging.info("Polling scale with request bytes: %r", request)
    else:
        logging.info("Request disabled; waiting for scale output")

    if args.scan:
        return scan_port(args, request)

    try:
        with open_serial(args) as ser:
            if read_until_reading(args, ser, request):
                return 0
            logging.error("Timed out without a parsed scale reading")
            return 2

    except serial.SerialException as exc:
        logging.error("Serial error: %s", exc)
        return 1
    except KeyboardInterrupt:
        logging.info("Interrupted")
        return 130


if __name__ == "__main__":
    sys.exit(main())
