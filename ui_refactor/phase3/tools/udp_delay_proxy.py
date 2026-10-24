#!/usr/bin/env python3
"""UDP delay/loss/jitter proxy for ENet UI truthfulness tests.

Listens on --listen, forwards each client to --target through a dedicated
upstream socket, and schedules packets with per-direction delay + jitter.
"""

import argparse
import heapq
import random
import select
import socket
import sys
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", type=int, required=True)
    parser.add_argument("--target", type=int, required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--delay-ms", type=float, default=75.0)
    parser.add_argument("--jitter-ms", type=float, default=30.0)
    parser.add_argument("--loss", type=float, default=0.02)
    parser.add_argument("--seconds", type=float, default=330.0)
    args = parser.parse_args()

    rng = random.Random(20261024)
    listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    listener.bind((args.host, args.listen))
    listener.setblocking(False)

    client_to_upstream = {}
    upstream_to_client = {}
    queue = []
    sequence = 0
    stats = {"up": 0, "down": 0, "dropped": 0, "sent": 0}
    last_report = time.monotonic()
    deadline = last_report + args.seconds

    def schedule(delay_direction, payload, target):
        nonlocal sequence
        if rng.random() < args.loss:
            stats["dropped"] += 1
            return
        delay = max(0.005, (args.delay_ms + rng.uniform(-args.jitter_ms, args.jitter_ms)) / 1000.0)
        sequence += 1
        heapq.heappush(queue, (time.monotonic() + delay, sequence, delay_direction, payload, target))

    print("[proxy] %s:%d -> %s:%d delay=%.1f±%.1fms loss=%.1f%%" % (
        args.host, args.listen, args.host, args.target,
        args.delay_ms, args.jitter_ms, args.loss * 100
    ), flush=True)

    while time.monotonic() < deadline:
        sockets = [listener] + list(upstream_to_client.keys())
        readable, _, _ = select.select(sockets, [], [], 0.02)
        for source in readable:
            try:
                payload, address = source.recvfrom(65535)
            except OSError:
                continue
            if source is listener:
                if payload == b"__proxy_stats__":
                    continue
                upstream = client_to_upstream.get(address)
                if upstream is None:
                    upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    upstream.bind((args.host, 0))
                    upstream.setblocking(False)
                    upstream.connect((args.host, args.target))
                    client_to_upstream[address] = upstream
                    upstream_to_client[upstream] = address
                    print("[proxy] client %s:%d via %s" % (address[0], address[1], upstream.getsockname()[1]), flush=True)
                stats["up"] += 1
                schedule("up", payload, upstream)
            else:
                client = upstream_to_client.get(source)
                if client is None:
                    continue
                stats["down"] += 1
                schedule("down", payload, client)

        now = time.monotonic()
        while queue and queue[0][0] <= now:
            _, _, direction, payload, target = heapq.heappop(queue)
            try:
                if direction == "up":
                    target.send(payload)
                else:
                    listener.sendto(payload, target)
                stats["sent"] += 1
            except OSError as error:
                print("[proxy] send error: %s" % error, flush=True)

        if now - last_report >= 5.0:
            print("[proxy] up=%d down=%d sent=%d dropped=%d clients=%d queued=%d" % (
                stats["up"], stats["down"], stats["sent"], stats["dropped"],
                len(client_to_upstream), len(queue)
            ), flush=True)
            last_report = now

    print("[proxy] done %s" % stats, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
