# oof.foo — Vision & Origin Story

## The Name

**oof** — the universal sound of something going wrong. Your computer's slow. You can't reach a website. Windows hasn't been updated in six months. *Oof.*

**foo** — the sound of relief (like *phew*), mirrored. Also a nod to `foobar`, the oldest placeholder in programming. It says: *we're developers, and we fix things.*

Put them together: **oof.foo**. Problem, then solution. Six characters. A palindrome of syllables. A domain that tells its own story.

The domain was available. It had a nice ring to it. So we're building a tool worthy of the name.

## What It Is

oof.foo is a system maintenance and repair tool that speaks human.

Tell it what's wrong in plain language. It figures out the rest.

```
> my computer is kinda slow lately

oof.foo: Running diagnostics...
  - 47 startup programs (12 unnecessary)
  - Disk 94% full
  - Windows Update hasn't run in 4 months
  - 3 stale user profiles consuming 18GB

Want me to clean this up?

> yeah go for it

oof.foo: On it.
  [x] Removed 12 startup items
  [x] Freed 23GB (temp files, old profiles)
  [x] Queued Windows Update + Winget upgrades
  [x] Scheduled disk optimization on reboot

foo. Reboot when ready — machine will be clean by morning.
```

## The Gap It Fills

| Tool | What it does | What it lacks |
|---|---|---|
| Windows Troubleshooter | Click-through wizards | Useless. Rarely fixes anything. |
| Ninite | Installs apps | No updates, no repair, no diagnosis |
| PDQ Deploy | Enterprise deployment | Expensive, IT-only, no NL interface |
| Chocolatey / Winget | Package managers | CLI-only, no diagnostics, no UX |
| ChatGPT | Gives advice | Can't actually touch your system |
| **oof.foo** | Listens, diagnoses, acts | — |

The gap: **an agent that can actually touch the system**, not just give instructions.

## Architecture

```
oof-foo/
├── core/                    ← NL agent layer
│   ├── listener             ← accepts natural language input (CLI or GUI)
│   ├── agent                ← LLM reasoning (Claude API or local Ollama)
│   └── dispatcher           ← maps intent → script library
├── scripts/                 ← the actual fixes
│   ├── windows/
│   │   ├── updates/         ← Windows Update, Winget (from Windows-Comprehensive-Updater)
│   │   ├── tuneup/          ← full tune-up sequence (SFC, DISM, cleanmgr, defrag, chkdsk)
│   │   ├── network/         ← NIC reinstall, DNS flush, connectivity diagnostics
│   │   └── users/           ← profile cleanup (delprof2), account management
│   ├── mac/                 ← future: Homebrew, softwareupdate
│   └── linux/               ← future: apt/dnf/pacman
├── diagnostics/             ← read-only info gathering (safe to run, never changes state)
├── docs/                    ← this file, recipes, architecture decisions
└── site/                    ← landing page at oof.foo
```

## LLM Layer

Three options, user's choice:

- **Claude API** — best reasoning, requires internet + API key
- **Ollama (local)** — privacy-first, runs on-device, no API cost, works offline
- **Both** — local by default, cloud opt-in for harder problems

## Privacy Principles

oof.foo runs as admin. That's power, and it demands trust.

1. **Local by default** — Ollama, no data leaves the machine
2. **Explicit consent** — shows what it's about to run before running it
3. **Open source** — anyone can audit every script
4. **No telemetry** — zero tracking, zero phoning home

## Origin

oof.foo started as a collection of PowerShell scripts that Daniel Johnston ran every time he touched a machine at KWES (NewsWest 9, a TV station in West Texas). SFC, DISM, cleanmgr, defrag, chkdsk, Winget, Windows Update — the full sequence, every time. Plus a NIC reinstall trick for stubborn DHCP issues. Plus delprof2 for clearing stale profiles before handing off a machine.

The scripts worked. But they were scattered — some in iCloud, some in OneDrive, some on a network share. No single entry point. No intelligence. Just a pile of .ps1 files and tribal knowledge.

oof.foo is the consolidation. The scripts become a library. The tribal knowledge becomes an agent. And the name tells you exactly what it does: takes your *oof* and turns it into *foo*.

## Evolution Timeline

| Date | Event |
|---|---|
| 2025-09 | Windows-Comprehensive-Updater v2.1.0 published on GitHub |
| 2025-10 | oof.foo domain registered, placeholder repo created |
| 2026-03-09 | Scripts-Consolidated: 270 files from 3 sources merged |
| 2026-03-11 | oof.foo concept crystallized: NL agent + script library |
| 2026-03-11 | First script recipes documented: full tune-up, NIC reinstall, delprof2 cleanup |
| 2026-03-12 | Repo restructured, Windows-Comprehensive-Updater absorbed as first module |

## What's Next

- Absorb Windows-Comprehensive-Updater as `scripts/windows/updates/`
- Write first scripts from documented recipes
- Audit Scripts-Consolidated (270 files) for more recipes
- Build NL dispatcher prototype
- Landing page at oof.foo
- Cross-platform expansion (Mac, Linux)
