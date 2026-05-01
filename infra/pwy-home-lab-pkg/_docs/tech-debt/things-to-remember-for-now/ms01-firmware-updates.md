# MS-01 Firmware Update

## Steps

1. Download the latest BIOS from the [Minisforum MS-01 product page](https://www.minisforum.com/pages/product-info) (select MS-01 → Drivers & Downloads → BIOS)
2. Extract the zip — the update package contains a `.bin` or `.rom` file
3. Copy the firmware file to the root of a **FAT32-formatted USB drive**
4. Insert the USB drive into the MS-01 and power on
5. Press **F7** immediately to enter Boot Menu
6. Navigate to: **UEFI: USB**
7. At "Shell>", type "fs0:", then "ls" to list the contents of the USB drive
8. Enter the nsh utility name to run it, e.g. "AfuefiFlash.nsh"
9. After reboot, re-enter BIOS Setup (**Delete**) to verify the new BIOS version is shown on the main screen
10. Continue with BIOS configuration (see below)

## BIOS Configuration

After flashing, verify/apply these settings:

```
Power on → press Delete → BIOS Setup
  → Save and Exit:
      Load Optimized Defaults (fixes some issues)
      Before this, the machine would stay off after power cycle.
  → Security → Secure Boot:
      Secure Boot: DISABLE
      Secure Boot Mode: Standard (default)
  → Boot → Boot Option Priorities:
      set to: UEFI Network I-226V, NVMe, USB, Hard Disk
  → Advanced → Network Stack Configuration:
      Network Stack: ENABLE
      IPv4 PXE Support: ENABLE
  → Advanced → ACPI Power Settings:
      Restore on AC Power Loss: Always On
  → MEBx -> AMT Config -> Power Control:
      ME ON in ...: ON in S0, ME Wake in S3, S4-5 (AC only)
      Idle Timeout: 65535
```

> AMT goes offline in S5 on the MS-01 regardless of Power Policies.
> The automation handles this by polling and prompting for manual power-on.

## Known Good Version
- Direct download: https://pc-file.s3.us-west-1.amazonaws.com/ms-01/Bios/MS-01-AHWSA-V1.27_4_28_V2.zip

## History
- 2026-04-12
  - ms01-01: set bios settings properly (restore AC power was not set to on)
  - ms01-01: updated firmware to 1.27-4-28-v2
  - ms01-02: has not lost AMT for over a day
  - ms01-02: set bios settings properly
  - ms01-02: updated firmware to 1.27-4-28-v2
  - ms01-03: updated firmware to 1.27-4-28-v2

## ERRATA
- ms01-01: has a hardware bug/flaw, it does NOT power on 
  after power cycle despite bios settings telling it to do so.

  
