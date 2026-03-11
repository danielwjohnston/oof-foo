# oof.foo

**Something's broken. Now it's not.**

oof.foo is a system maintenance and repair toolkit that turns IT tribal knowledge into scripts you can actually run. Tell it what's wrong — it figures out the rest.

## What's Inside

```
scripts/windows/
├── updates/         Windows Update + Winget automation (from Windows-Comprehensive-Updater)
├── tuneup/          Full PC tune-up: SFC, DISM, cleanmgr, defrag, chkdsk, patching
├── network/         NIC reinstall, connectivity diagnostics
└── users/           Profile cleanup with delprof2
```

## Quick Start

All scripts require **Administrator** (Run as Admin).

### Full Tune-Up
The flagship. Run this every time you touch a machine:
```powershell
.\scripts\windows\tuneup\full-tuneup.ps1
```
SFC, DISM, disk cleanup, optimize, chkdsk, Winget upgrade, Windows Update — then reboot. Leave it overnight, get a clean machine in the morning.

### Profile Cleanup
New user getting this machine? Clear the slate:
```powershell
.\scripts\windows\users\cleanup-profiles.ps1
```
Keeping one user, removing everyone else:
```powershell
.\scripts\windows\users\cleanup-profiles.ps1 -ExcludeUser "jsmith"
```

### NIC Reinstall
Network adapter acting up? DHCP won't renew? The fastest fix:
```powershell
.\scripts\windows\network\nic-reinstall.ps1
```
Backs up the driver, uninstalls the adapter, rescans hardware, reinstalls, reconfigures. Checks the hosts file while it's in there.

### Windows Update
Full automated patching with dashboard and scheduling:
```powershell
.\scripts\windows\updates\windows-comprehensive-updater.ps1
```
See `scripts/windows/updates/SIMPLE-HOW-TO.md` for details.

## The Name

**oof** — the sound of something going wrong.
**foo** — the sound of relief (*phew*), mirrored. Also a nod to `foobar`.

Problem, then solution. That's the whole product.

## Where This Is Going

The scripts are phase one. Phase two is a natural language agent layer:

```
> my computer has been slow lately

oof.foo: Running diagnostics...
  - 47 startup programs (12 unnecessary)
  - Disk 94% full
  - Windows Update hasn't run in 4 months

Want me to clean this up?
```

An AI layer (Claude API or local Ollama) that interprets symptoms and dispatches the right scripts. See [docs/VISION.md](docs/VISION.md) for the full roadmap.

## Privacy

oof.foo runs as admin. That's power, and it demands trust.

- **Open source** — audit every script
- **No telemetry** — zero tracking, zero phoning home
- **Local by default** — future AI layer uses Ollama (on-device) by default
- **Explicit consent** — shows what it will run before running it

## Origin

Built by Daniel Johnston at KWES (NewsWest 9) in West Texas. Born from running the same maintenance sequence on every machine he touched, and knowing exactly which trick fixes which problem — but having those scripts scattered across three different locations with no single entry point.

oof.foo is the consolidation. The scripts become a library. The tribal knowledge becomes code. And eventually, an agent.

## License

MIT
