#!/usr/bin/env python3
"""
Tapo P125 Power Cycle Script
Usage: python3 tapo_power_cycle.py <ip> <email> <password> [delay_seconds]
"""

import asyncio
import sys
import time

from plugp100.common.credentials import AuthCredential
from plugp100.new.device_factory import connect, DeviceConnectConfiguration


async def power_cycle(host: str, email: str, password: str, delay: int = 5):
    credentials = AuthCredential(email, password)

    print(f"[*] Connecting to Tapo plug at {host} ...")

    device_config = DeviceConnectConfiguration(
        host=host,
        credentials=credentials,
    )

    device = await connect(device_config)
    await device.update()

    print(f"[+] Connected! Device: {device.raw_state.get('nickname', 'Unknown')} | Model: {device.raw_state.get('model', 'Unknown')}")
    print(f"[*] Current state: {'ON' if device.is_on else 'OFF'}")

    # Turn OFF
    print("\n[*] Turning plug OFF ...")
    await device.turn_off()
    await device.update()
    print(f"[+] Plug is now: {'ON' if device.is_on else 'OFF'}")

    # Wait
    print(f"[*] Waiting {delay} seconds ...")
    for i in range(delay, 0, -1):
        print(f"    {i}...", end="\r")
        await asyncio.sleep(1)
    print()

    # Turn ON
    print("[*] Turning plug ON ...")
    await device.turn_on()
    await device.update()
    print(f"[+] Plug is now: {'ON' if device.is_on else 'OFF'}")

    print("\n[✓] Power cycle complete!")

    await device.client.close()


def main():
    if len(sys.argv) < 4:
        print("Usage: python3 tapo_power_cycle.py <ip> <email> <password> [delay_seconds]")
        print("Example: python3 tapo_power_cycle.py 192.168.1.50 me@email.com mypassword 5")
        sys.exit(1)

    host     = sys.argv[1]
    email    = sys.argv[2]
    password = sys.argv[3]
    delay    = int(sys.argv[4]) if len(sys.argv) > 4 else 5

    asyncio.run(power_cycle(host, email, password, delay))


if __name__ == "__main__":
    main()
