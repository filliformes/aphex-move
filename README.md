# Aphex

**Korg MS-10 / MS-20 hybrid mono synth for [Ableton Move](https://www.ableton.com/move/).**

Built for the [Schwung](https://github.com/charlesvestal/schwung) framework. Part of the
open-source lutherie banner **Filliformes**.

> Dual-VCO grit through a self-oscillating **KORG-35 / OTA** filter cascade, a
> **source-side patchbay**, an **External Signal Processor** that turns Move's
> line-in into pitch/envelope/gate CV, and a multi-source **analog drift** engine
> that gives every instance its own personality. 41 factory patches, MS-10 collapse
> mode, and a "Modern" page of extras.

---

## What it is

Aphex is a **monophonic sound generator** module for Ableton Move that fuses the
**MS-10**'s focused playability with the **MS-20**'s modulation depth and aggressive
Korg-35 filter. Two oscillators feed a drive stage into an HPF→LPF cascade — the
place where the MS-20 magic lives — with a semi-modular patchbay and ESP modeled on
the original hardware's ergonomics.

Voice state is fully encapsulated for a clean polyphonic expansion later; v0.1.0 is
mono, last-note priority.

## Features

- **Two oscillators** — VCO 1 (Tri / Saw / PW-Square / Noise, 32′/16′/8′/4′),
  VCO 2 (Saw / Square / Pulse / Ring, 16′/8′/4′/2′) with hard sync, FM, sub, and detune.
- **Two switchable filter circuits:**
  - **REV.1 (KORG-35)** — early MS-20 / MS-10: Sallen-Key, asymmetric forward-path
    saturation, "creamy fuzz" break-up at self-oscillation — harsher, rock'n'roll.
  - **REV.2 (OTA / LM13600)** — late MS-20: symmetric feedback saturation, buffered
    inter-stage, cleaner "howl/whistle", resonance develops earlier in the travel.
  - Cascade modes: **HP+LP** (default, MS-20), LP only, HP only, Notch.
- **Source-side patchbay** — 8 input-jack source selectors, no destination-depth knobs.
  Attenuation lives in the panel knobs (HPF MG, LPF EG, …) exactly like the hardware.
- **External Signal Processor (ESP)** — Move's line-in becomes a YIN pitch tracker,
  envelope follower, Schmitt gate, and routable raw audio, with Lo Cut / Hi Cut / CV
  Adjust / Threshold. Route ESP Audio through the filter for the classic mangler sound.
- **Two envelopes** — EG 1 trapezoid (Delay-Attack-Release) drives the **filter** by
  default; EG 2 HADSR (with up to 20 s hold) drives the **amplitude**.
- **Multi-source analog drift** — per-instance fixed detune/calibration offsets, slow
  thermal random walk, mid-rate mains-hum flutter, per-sample phase jitter, and note-on
  phase re-roll. Each instance gets its own character from a pointer-derived seed.
- **Velocity shaping** — gentle (sqrt) curve + floor so soft pad hits stay audible,
  with a **Vel→Amp** depth control (0 = velocity ignored … 1 = full dynamic range).
- **20 ms "analog" smoothing** on cutoff, resonance, pitch (Scale/Fine/Detune/Tune),
  volume, and LFO depth — knob moves glide while envelopes and the LFO stay snappy.
- **MS-10 mode** — collapses to VCO 1 + LPF + EG 2 only.
- **41 factory presets** across Bass / Lead / Pad / Keys / Sequence / SFX / Drone / ESP,
  plus Random Patch / Mutate / Random Mod performance triggers.
- MIDI note, pitch bend (±1 oct), mod wheel, and channel/poly aftertouch.

## Signal flow

```
 VCO1 ─┬─────┐                          ┌── EG1 (filter env, default)
 VCO2 ─┤     │                          │
 Sub  ─┤  →  MIX → DRIVE → HPF(K35) → LPF(K35) → VCA → output stage → OUT
 Ring ─┤                                  ^          ^
 Noise┤                               cutoff/reso   EG2 (amp) × velocity × volume
 ESP  ┘                               (+ MG / drift)
```

## Pages (jog-wheel navigation, 8 encoders each)

| Page | Knobs |
|------|-------|
| **Aphex** (root) | LPF Cut · LPF Peak · HPF Cut · HPF Peak · MG Freq · MG Depth · Drive · Volume |
| Patch *(menu)* | Preset · Rnd Patch · Mutate · Rnd Mod · Reset Patch · Octave · M.Tune · Portamento |
| VCO 1+2 | V1 Wave · V2 Wave · V1 PW · Pitch (V2) · Scale 1 · Scale 2 · Portamento · M.Tune |
| Mixer | VCO 1 · VCO 2 · MG/T.EXT · EG1/EXT · ESP Aud · Sub · Noise · FB |
| Filter | HPF Cut · HPF Peak · HPF MG · HPF EG · LPF Cut · LPF Peak · LPF MG · LPF EG |
| Envelopes | E1 Delay · E1 Atk · E1 Rel · E2 Hold · E2 Atk · E2 Dcy · E2 Sus · E2 Rel |
| MG / ESP | MG Freq · MG Shape · ESP Sig Lvl · ESP Lo Cut · ESP Hi Cut · ESP CV Adj · ESP Threshold · MG PW |
| Patchbay | KBD CV · T.EXT · VCO Freq · HPF EG/Ext · LPF EG/Ext · Initial Gain · VCO 2 CV · Ext Sig |
| Modern | Drift · Drive · KeyTrack · Filter Rev · MS-10 Mode · V1 Drift · MW→MG · MW→Filt |

Menu-only extras live on most pages (Sync/FM/Detune on VCO; Color on Mixer; MG PW; Filter
Mode, X-Mod, **Vel→Amp** on Modern; PWM In and EG-trigger jacks on Patchbay).

## Patchbay (MS-20 input jacks)

Each row is one MS-20 input jack — pick what's plugged in. There are no per-jack depth
knobs; the panel attenuators (HPF MG, LPF EG, …) control intensity, just like the original.

```
KBD CV In     [Normal ▾]    ← what feeds the VCO Hz/V CV
T.EXT         [MG ▾]        ← replaces MG in the panel MG/T.EXT attenuators
VCO Freq      [EG1 ▾]       ← replaces EG1 in the VCO Master EG1/EXT attenuator
HPF EG/Ext    [EG1 ▾]       ← filter envelope source for the HPF
LPF EG/Ext    [EG1 ▾]       ← filter envelope source for the LPF
Initial Gain  [None ▾]      ← INITIAL GAIN: adds to EG2's VCA control
VCO 2 CV      [None ▾]      ← separate Hz/V into VCO 2 only
Ext Sig       [None ▾]      ← VCF external signal input
```

## ESP — External Signal Processor

Plug a source into Move's line-in (or use the mic when nothing is connected). Aphex tracks
its pitch with the **YIN** algorithm, follows its envelope, gates on a threshold, and exposes
the raw audio — all routable through the patchbay. The signature trick: send **ESP Aud** into
the Mixer and out through the Korg-35 filter for the iconic MS-20 external-audio mangler.

## Installation

### From the Schwung Manager (recommended, once in the catalog)
1. In Schwung Manager, refresh the catalog.
2. Find **Aphex** under sound generators and click Install.
3. **Power-cycle the Move** so the host loads the new `module.json`.
4. Add Aphex to a chain.

### Manual install (devs / pre-release)
```bash
git clone https://github.com/filliformes/aphex-move.git
cd aphex-move
./scripts/build.sh                       # Docker ARM64 cross-compile → dist/aphex/dsp.so
./scripts/install.sh                     # scp dsp.so + module.json + help.json to move.local
# Override target host:
MOVE_HOST=192.168.1.42 ./scripts/install.sh
```
After install, **power-cycle the Move** (module.json changes are cached at host startup;
removing/re-adding the module only reloads the `.so`).

## Building from source

Requires Docker (or a local `aarch64-linux-gnu-gcc` toolchain).

```bash
./scripts/build.sh    # cross-compile dsp.so for ARM64, package dist/aphex-module.tar.gz
./scripts/install.sh  # deploy to the Move over SSH
```

```
src/
  module.json          metadata, ui_hierarchy, chain_params
  help.json            on-device help tree
  dsp/
    aphex.c            all DSP (oscillators, K35/OTA filters, envelopes, MG, S&H, ESP, patchbay)
    k35.h / k35_ota.h  clean-room KORG-35 and OTA filter models
    yin.h              YIN pitch tracker
    drift.h            multi-source analog drift
```

## Credits

- Inspired by the Korg **MS-10** and **MS-20** (1978), designed by Fumio Mieda.
- Filter research: Tim Stinchcombe — [MS-10/MS-20 Filters study](https://www.timstinchcombe.co.uk/synth/MS20_study.pdf).
- Clean-room K35 derivation from Will Pirkle (AN-5 / AN-7v2) + Vadim Zavalishin's TPT framework.
- YIN pitch tracker: de Cheveigné & Kawahara (2002).
- Drift taxonomy inspired by Mutable Instruments *Braids* and U-He *Diva*.
- Built for the **Schwung** framework by Charles Vestal.
- Named in honor of Richard D. James, lifelong MS-20 abuser.

## License

MIT — see [LICENSE](LICENSE). All DSP is original / clean-room (no copyleft inheritance).
