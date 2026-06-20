# Aphex — Design Spec

## Identity

- **Module ID:** `aphex`
- **Display name:** Aphex
- **Abbreviation:** `APHEX`
- **Component type:** sound_generator
- **API:** plugin_api_v2 (C)
- **License:** MIT (original DSP, no copyleft inheritance)
- **One-liner:** Korg MS-10/MS-20 hybrid mono synth with Korg-35 filter cascade, semi-modular patchbay, and External Signal Processor.

## Concept

A raw, vintage analog mono synth fusing the **MS-10**'s focused playability with the **MS-20**'s modulation depth and aggressive Korg-35 self-oscillating filter. The defining sound: dual-VCO grit fed into a screaming HPF→LPF cascade with drive into the filter (where the MS-20 magic lives).

The **patchbay** is the soul: every modulation destination is listed as a menu row, and the user picks which source plugs into it via an enum dropdown. Single source per destination (clean, gestural, fits Move's UI). Attenuators on a knob page set the depth.

The **ESP** (External Signal Processor) turns Move's line-in into pitch CV, an envelope follower, a gate, and raw audio — all routable into the patchbay. The killer trick: route ESP Audio through the filter for the iconic external-signal-into-MS-20 sound.

## Voice architecture

**v0.1: Monophonic, last-note priority** — but voice state is fully encapsulated in `voice_t` (per-voice oscillator phases, envelope state, glide). Going polyphonic later is a struct-array swap + voice allocator, not a DSP rewrite. Global modulation (LFO/MG, S&H, ESP) stays singular even in poly mode.

## Signal flow

```
                                      ┌── ENV1 (filter env)
                                      │
   VCO1 ─┬─────┐                       │
   VCO2 ─┤     │                       v
   Sub ──┤  →  MIX → DRIVE → HPF (K35) → LPF (K35) → VCA → tanh → OUT
   Ring ─┤                                          ^      ^
   Noise ┤                                          │      │
   ESPAud┘                                       cutoff   ENV2 (amp env)
                                                  reso

   Modulation generators (always running):
     ENV1 (ADSR)   — HADR-capable later, ADSR for v0.1
     ENV2 (ADSR)   — amp envelope
     MG / LFO      — Tri / Saw / Sq / Rev-Saw, free or tempo-synced
     S&H           — clocked from MG, source = noise (configurable)
     ESP Pitch CV  — YIN-style pitch tracker on line-in
     ESP Env       — fast envelope follower on line-in
     ESP Gate      — Schmitt-trigger gate when input > threshold
```

## Patchbay model

**Destinations (the inputs — listed as menu rows):**

| # | Destination | Use case |
|---|-------------|----------|
| 1 | VCO1 Pitch | Vibrato, glissando, pitch sequencing |
| 2 | VCO2 Pitch | Cross-mod, FM-ish movement |
| 3 | VCO2 Sync | Trigger hard-sync gestures |
| 4 | HPF Cutoff | Sweep the high-pass |
| 5 | LPF Cutoff | The classic auto-wah / filter sweep |
| 6 | Resonance | Animate the bite |
| 7 | VCA CV | Tremolo / external amp envelope |
| 8 | PWM | Pulse-width modulation on both VCOs |

(8 destinations for v0.1 — single page of 8 attenuators + 8 enum source selectors. v0.2 can expand to 16.)

**Sources (the outputs — enum options for each destination):**

```
  0  None
  1  ENV1            (filter envelope, bipolar -1..+1)
  2  ENV2            (amp envelope, bipolar)
  3  MG Tri          (LFO triangle)
  4  MG Sq           (LFO square)
  5  S&H             (sample-and-hold stepped random)
  6  Noise           (slowly-drifting filtered random)
  7  Note CV         (keyboard tracking)
  8  Velocity        (per-note velocity, latched until next note)
  9  Aftertouch      (continuous pressure)
 10  Mod Wheel       (CC1)
 11  ESP Pitch       (line-in pitch tracker, V/oct-style CV)
 12  ESP Env         (line-in envelope follower)
 13  ESP Gate        (line-in Schmitt-trigger gate)
 14  ESP Audio       (raw line-in audio — for AM/ring routing)
```

**Routing semantics:**
- One source per destination (single patch cable per input — true to MS-20 ergonomics)
- Each destination has a depth attenuator (`-1..+1`, bipolar — sources are bipolar, depth flips polarity)
- Patchbay state (sources + depths) saved with preset state

## UI Pages (jog-wheel navigation)

| # | Page | Role |
|---|------|------|
| 1 | **Patches** | Preset, Pad Mode, Random — main perf knobs |
| 2 | VCO1 | Pitch, Fine, Wave, PW, Sub, PWM Rate, PWM Depth, Drift |
| 3 | VCO2 | Pitch, Fine, Wave, PW, Sync (toggle), Cross-Mod, Detune, Drift |
| 4 | Mixer | VCO1, VCO2, Sub, Ring, Noise, NoiseColor, ESPAudio, FB |
| 5 | Filter | LPFCut, LPFReso, HPFCut, HPFReso, EnvAmt, KeyTrack, Drive, Mode |
| 6 | Envelopes | ENV1 ADSR + ENV2 ADSR (8 knobs) |
| 7 | MG / S&H | Rate, Wave, Depth, Delay, S&HRate, S&HSmooth, MWheel→MG, MWheel→Filter |
| 8 | ESP | InGain, PitchSlew, EnvAtk, EnvRel, GateThresh, AudMix, PitchMode, GatePolarity |
| 9 | **Patchbay** | 8 enum source selectors (menu) + 8 depth knobs |

### Page 1 (Patches) — perf surface

- **Knobs:** Cutoff, Resonance, Drive, Env→Filter, MG Rate, MG Depth, Glide, Volume
- **Menu (jog-scroll):** Preset (enum, factory + user), Pad Mode (Play/Patch — defer to v0.2), Rnd Patch (action), Reset (action), Octave (-2..+2)

### Page 9 (Patchbay) — the heart of the synth

- **Knobs:** Depth1..Depth8 (one per destination)
- **Menu rows (jog-scroll):**
  ```
  → VCO1 Pitch    [None ▾]
  → VCO2 Pitch    [None ▾]
  → VCO2 Sync     [None ▾]
  → HPF Cutoff    [ENV1 ▾]
  → LPF Cutoff    [ENV1 ▾]
  → Resonance     [None ▾]
  → VCA CV        [None ▾]
  → PWM           [MG Tri ▾]
  ```

## Filter — Korg 35 cascade (the signature sound)

Both HPF and LPF use the **Korg 35** topology (Sallen-Key, single-pole feedback w/ asymmetric clipping). Self-oscillates near maximum resonance with characteristic gritty edge.

- **Modes:** HP+LP cascade (default, MS-20 mode), LP only, HP only, Notch (HP path inverted into LP)
- **Drive INTO the filter** (pre-filter saturation) is where the MS-20 grit lives — knob control on Filter page
- **Resonance:** taps near self-oscillation (Q > 4), gain-compensated to avoid signal cancellation
- **DSP source:** port from open-source — likely Will Pirkle's K35 model (BSD), Surge XT's K35 filter (GPL — would force GPL on Aphex), or a clean-room implementation. **Decision: clean-room implementation** based on the public Sallen-Key + 1-pole feedback math. Stage 4 will fetch reference code via `dsp-fetch` for cross-checking.

## ESP (External Signal Processor)

- **Input:** Move line-in via `g_host->mapped_memory + g_host->audio_in_offset` (Phasma/Deforme pattern — no ALSA, no capture threads). Requires `audio_in: true` in capabilities.
- **Pitch tracker:** YIN algorithm (proven in Spectra). Output is V/oct-style continuous CV. Slewable.
- **Envelope follower:** rectified + one-pole lowpass with separate attack/release coefficients.
- **Gate:** Schmitt trigger with hysteresis. Threshold knob, polarity toggle.
- **ESP Audio:** raw line-in samples available as a source (gain-staged). Route through Mixer to feed it into the filter — the iconic MS-20 trick.

## Randomization

- **Rnd Patch** (page 1, action knob): full patch rerandomize
  - Oscillator pitches (within ±1 oct), waves, mix levels
  - Filter cutoff, resonance, drive
  - Envelope times (capped at 1.5s for musicality)
  - Patchbay sources + depths (weighted distribution favoring subtle values, per Denis pattern)
- **Reset Patchbay** (action): all sources → None, all depths → 0

## Presets (factory)

To be designed during coding stage. Target categories:
- **MS-20 Bass** (raw saw + screaming filter)
- **Lead Scream** (self-osc filter as oscillator)
- **External Audio Mangler** (ESP Audio → filter, gate-driven)
- **Sync Lead** (VCO2 sync + LFO→VCO2 pitch)
- **Random Drone** (S&H → pitch, slow LFO)
- **Vocal Harmonizer** (ESP Pitch → VCO1, ESP Gate → ENV2 trig)

## Critical constraints (carried into CLAUDE.md)

- Mono first, but voice state in `voice_t` for clean future poly expansion
- No memory allocation in `render_block`
- Per-sample modulation for filter cutoff and pitch (per-block creates artifacts at audio-rate LFO)
- Output through soft tanh saturation (analog warmth)
- All filter cutoff smoothing at 20ms (per Denis lessons)
- Linear envelope release (per Denis lessons — exponential makes 1.5s feel like 10s)
- `audio_in: true` in capabilities (for ESP)
- Single-source-per-destination patchbay (depth attenuator handles polarity)

## Roadmap

- **v0.1:** Mono, all 9 pages, ESP working, 8 patchbay destinations, 6 factory presets
- **v0.2:** Pad Mode (Play/Patch like Denis), Hold stage on ENV1 (proper HADR), expand to 16 patchbay destinations
- **v0.3:** Polyphonic mode (4 voices, last-note stealing), per-voice patchbay
