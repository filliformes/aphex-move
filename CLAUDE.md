# Aphex — Claude Code context

## What this is
MS-10 / MS-20 hybrid mono synth with semi-modular patchbay and External Signal Processor.
Schwung sound generator. API: `plugin_api_v2_t`. Language: C (single file).
Voice architecture: **Monophonic, last-note priority**. Voice state encapsulated in
`voice_t` for clean future polyphonic expansion (see `## Going polyphonic` below).

## Repo structure
- `src/dsp/aphex.c` — all DSP (oscillators, filter, envelopes, MG, S&H, ESP, patchbay routing)
- `src/module.json` — module metadata, ui_hierarchy, chain_params (must match git tag on release)
- `scripts/build.sh` — Docker ARM64 cross-compile (always use this)
- `scripts/install.sh` — deploys to Move via scp + fixes `ableton:users` ownership
- `scripts/Dockerfile` — `gcc-aarch64-linux-gnu` toolchain
- `.github/workflows/release.yml` — CI: verifies version, builds, releases, updates release.json
- `design-spec.md` — original design (signal flow, patchbay model, page layout, presets, roadmap)

## Pages (jog-wheel navigation, 8 knobs each)
1. **Root / Patches** — Cutoff, Reso, Drive, Env→Filt, MG Rate, MG Depth, Glide, Volume
   - Menu: Preset, Octave, Rnd Patch, Reset Patch, + page links
2. **VCO 1** — Pitch, Fine, Wave, PW, Sub, PWM Rate, PWM Depth, Drift
3. **VCO 2** — Pitch, Fine, Wave, PW, Sync (toggle), X-Mod, Detune, Drift
4. **Mixer** — VCO1, VCO2, Sub, Ring, Noise, Color, ESP Aud, FB
5. **Filter** — LPF Cut, LPF Reso, HPF Cut, HPF Reso, Env Amt, KeyTrack, Drive, Mode (HP+LP/LP/HP/Notch)
6. **Envelopes** — E1 ADSR + E2 ADSR (8 knobs total)
7. **MG / S&H** — Rate, Wave, Depth, Delay, S&H Rate, S&H Smooth, MW→MG, MW→Filt
8. **ESP** — In Gain, Pitch Slew, Env Atk, Env Rel, Gate Thr, Aud Mix, Pitch Mode, Gate Pol
9. **Patchbay** — 8 enum source selectors (menu) + 8 depth knobs

## Patchbay (v0.2 — source-side jack model)
The MS-20 patch panel works by routing one *source* into each *input jack* with
no per-jack attenuator at the jack itself — attenuation lives in the panel
knobs feeding that input (HPF MG, LPF EG, VCO MIXER MG/T.EXT, etc.). Aphex
v0.2 mirrors this: each jack is a single enum selector picking what's plugged
into that input. Default value (index 0) = the hard-wired MS-20 routing.

**Panel jacks (visible on Patchbay page, 8 knobs):**
| Slot | Key | MS-20 jack |
|------|-----|-----------|
| 1 | `pb_kbd_cv` | KBD CV IN |
| 2 | `pb_total` | TOTAL (sum mod) |
| 3 | `pb_freq` | VCO FREQ |
| 4 | `pb_hpf_cv` | HPF CUTOFF FREQ |
| 5 | `pb_lpf_cv` | LPF CUTOFF FREQ |
| 6 | `pb_vca_in` | INITIAL GAIN |
| 7 | `pb_vco2_cv` | VCO 2 CV IN |
| 8 | `pb_ext_sig` | EXT SIGNAL IN |

**Menu jacks (Patchbay menu extras):**
- `pb_pwm_in` — PWM IN (Kit-only feature; demoted to menu in FS-strict mode)
- `pb_eg1_trig` — EG 1 TRIG IN (rising edge retriggers EG1)
- `pb_eg12_trig` — EG 1+2 TRIG IN (rising edge retriggers both envelopes)

EG TRIG IN edge detection lives in `render_block`: per-sample tracking of
`pb_eg1_trig_prev` / `pb_eg12_trig_prev` floats with rising-edge fire.
Keyboard triggers still fire normally — these are *additional* sources.

**Legacy v0.1 destination-depth model** (`pb_src[]`, `pb_depth[]`) is kept for
back-compat with old presets and for the Random Patch button, but is no longer
the primary path. New code uses the v0.2 source-side jack resolvers.

## ESP (External Signal Processor)
- Reads line-in via `g_host->mapped_memory + g_host->audio_in_offset`
  (Phasma/Deforme pattern — no ALSA, no capture threads)
- `audio_in: true` REQUIRED in capabilities (already set)
- Pitch tracker: **YIN** (de Cheveigné & Kawahara 2002), see `src/dsp/yin.h`.
  Difference function → CMNDF → absolute threshold pick → parabolic interpolation.
  Range τ ∈ [30, 512] = ~86 Hz to ~1.47 kHz at SR=44.1k. Sub-cent accuracy on
  clean tones, octave-error-resistant on harmonic content, rejects silence/noise.
  Updates every 8 blocks (~23 ms). Replaces v0.1 naive autocorrelation.
- Env follower: rectified + one-pole with separate atk/rel coefs
- Gate: Schmitt trigger with hysteresis (`thr_lo = thr_hi * 0.7`)
- ESP Audio is itself a patchbay source — route through Mixer for the iconic
  external-audio-into-MS-20 trick

## Filter — Korg-35 cascade with REV switch (src/dsp/k35.h + k35_ota.h)
**REV.1 (KORG-35)** — `k35.h`, the early-MS-20 / MS-10 filter character.
- Clean-room K35 LPF + HPF, derived from public Pirkle AN-5 / AN-7v2 equations
  + Zavalishin TPT framework. No GPL code copied.
- Topology: Sallen-Key, asymmetric saturation in forward path (predictor-corrector
  NLP placement, saturation on resonance feedback only).
- LPF: 12 dB/oct, HPF1 reads from LPF1 output. HPF: 6 dB/oct bass side,
  12 dB/oct above resonance (AN-7v2 simplified).
- Resonance ∈ [0,1] mapped to K ∈ [0, 1.99] LINEARLY — peak develops late in
  the knob travel (matching real K35: only really sings past ~3 o'clock).
- Sonic character: **creamy fuzz** at self-osc, "tube amp breaking up" — harsher,
  more rock'n'roll. Higher noise floor.

**REV.2 (OTA)** — `k35_ota.h`, the late-MS-20 LM13600 filter character.
- Clean-room OTA-based topology, derived from Stinchcombe 2014 study + Schmitz
  schematics + Korg KLM-307 daughterboard. No GPL code copied.
- Differences from K35:
  1. SYMMETRIC saturation in feedback loop (not asymmetric forward-path)
  2. Unity-gain BUFFER between LP1 and LP2 (no inter-stage loading — Stinchcombe
     argues this disqualifies it from being "Sallen-Key")
  3. Resonance maps via sqrt curve → peak develops EARLIER in knob travel
     (matching real OTA filter: "tunable throughout most of the pots range")
  4. Cleaner self-osc tone (howl/whistle vs K35 fuzz break-up)
  5. Lower noise floor
- Same `k35_t` state struct layout as REV.1 (3 floats), so switching between
  revs at runtime is a single int dispatch — no state migration needed.

License: MIT, both revs. Switch via `filter_rev` enum on Modern page.
Reference for revisions: timstinchcombe.co.uk/synth/MS20_study.pdf.

## Page layout (v0.2 — MS-faithful + Modern)
9 pages: Aphex (root), VCO 1, VCO 2, Mixer, Filter, Envelopes, MG/ESP,
Patchbay, Modern. After the post-MG-shape cleanup pass, **9 of 11 pages
match the original MS-20 panel knob-for-knob** — only the Aphex (root)
summary page and the Modern page are clearly Move/Aphex inventions.

- **Aphex (root)**: 8 knobs (LPF Cut/Peak, HPF Cut/Peak, MG Freq/Depth,
  M.Tune, Volume) — Move convention summary page, not an MS-20 panel section.
  Menu: Preset, Octave, Portamento, Trigger (manual gate), Rnd/Reset Patch.
- **VCO 1**: Scale (32'/16'/8'/4'), Wave (Tri/Saw/PW-Square/Noise), PW —
  3 knobs, matches MS-20 spec exactly.
- **VCO 2**: Scale (16'/8'/4'/2'), Pitch (±2 oct per MS-20 Kit spec),
  Wave (Saw/Square/Pulse/Ring), Sync (slide switch), FM (slide switch — binary,
  not depth) — 5 knobs. Sync and FM are Kit/M Kit features (not on the
  original 1978 FS panel). PW is removed from the panel — no MS-20 ever had a
  VCO 2 PW knob; pulse wave is fixed-narrow per spec. v2_pw is kept as a
  Modern menu param for back-compat with old presets.
  Menu: PW (Modern Kit-only extra), Detune (Aphex fine-detune extra).
- **Mixer**: VCO 1 Level, VCO 2 Level, MG/T.EXT, EG1/EXT — 4 knobs, matches
  the original MS-20's VCO MIXER column exactly. The two FREQ MOD attenuators
  control how much the patchbay TOTAL and FREQ jacks (default = MG and EG1)
  modulate BOTH VCOs' pitch. Independent from the HPF/LPF MG/EG knobs.
  Menu extras (non-period): Sub, Ring, Noise, Color (white/pink), ESP Aud, FB.
- **Filter**: HPF Cut/Peak/MG/EG and LPF Cut/Peak/MG/EG — 8 knobs (4 + 4),
  matches MS-20's panel-side MG/T.EXT and EG2/EXT attenuators per filter.
- **Envelopes**: EG1 D-A-R (3 knobs, sustain forced to max) + EG2 H-A-D-S-R
  (5 knobs, 20s hold range) = 8 knobs, matches MS-20 spec exactly.
- **MG/ESP**: 2 MG (Freq, Shape) + 5 ESP (Sig Lvl, Lo Cut, Hi Cut, Threshold,
  CV Adj) = 7 knobs, matches MS-20 panel for both sections combined.
  Menu extras: MG PW, MG Depth (global scaler), ESP Pitch Slew, Env Atk/Rel,
  Aud Mix, Pitch Mode, Gate Pol.
- **Patchbay**: 8 input-jack source selectors on the panel:
  KBD CV In, T.EXT, VCO Freq, HPF Ext, LPF Ext, Initial Gain, **VCO 2 CV**, Ext Sig.
  Source-side model — each row picks what's plugged into one MS-20 input jack.
  Default value (index 0) = the hard-wired MS-20 routing. Attenuation lives
  in panel knobs (HPF MG, LPF EG, etc.) per the original semantic.
  Menu extras: PWM In (Kit-only), EG 1 Trig In, EG 1+2 Trig In (rising-edge
  retrigger of envelopes per MS-20 FS panel jacks).
- **Modern**: Drift, Drive, KeyTrack, Filter Rev, MS-10 Mode, V1 Drift,
  MW→MG, MW→Filt — 8 knobs, all non-period-correct extras.
  Menu: V2 Drift, Filter Mode (HP+LP/LP only/HP only/Notch), X-Mod Amt.

## VCO Master FREQ MOD attenuators
The Mixer page slots 3-4 (`vco_mg`, `vco_eg`) are the panel attenuators that
sit at the bottom of the original MS-20's VCO MIXER column — labeled
**MG/T.EXT** and **EG1/EXT** on the silkscreen. They scale the patchbay
TOTAL and FREQ jack signals on their way to BOTH VCOs' pitch input.

Internally these are stored as `synth_t::vco_mg_int` and `synth_t::vco_eg_int`
(distinct from the HPF/LPF mod knobs). render_block does:

```c
float vco_mod_mgtext = inst->vco_mg_int * jack_total_sig;
float vco_mod_eg1ext = inst->p_ms10_mode ? 0.0f
                                         : inst->vco_eg_int * jack_vco_freq_sig;
v1_semi += (vco_mod_mgtext + vco_mod_eg1ext) * 12.0f + ...
v2_semi += (vco_mod_mgtext + vco_mod_eg1ext) * 12.0f + jack_vco2_cv_sig * 12.0f + ...
```

VCO 2 also receives `jack_vco2_cv` separately — the MS-20 FS's VCO 2 CV IN
jack provides Hz/V into VCO 2 only.

**Historic bug fixed in v0.2 cleanup:** earlier versions aliased these to
`hpf_mg_int` / `hpf_eg_int`, so adjusting the HPF MG knob also detuned VCOs.
The `routing_test` suite verifies the fix end-to-end with zero-crossing-rate
variance measurement (3.1× ratio between vco_mg and hpf_mg paths).

## MG (Modulation Generator / LFO)
The MS-20 MG is a single LFO with **two simultaneous outputs** that are
*both* continuously variable in shape, available as patch sources at all times:

- **Slope output** (`mg_tri`) — controlled by `mg_shape ∈ [0, 1]`:
  - `0` = positive saw (rising ramp)
  - `0.5` = triangle
  - `1` = negative saw (falling ramp)
  - intermediate values morph smoothly via a two-segment piecewise-linear
    waveform whose peak position = `1 - mg_shape`.
- **Pulse output** (`mg_sq`) — controlled by `mg_pw ∈ [0, 1]`:
  - `0` = wide pulse (~95% duty)
  - `0.5` = square (50% duty)
  - `1` = narrow pulse (~5% duty)
  - independent from `mg_shape` — both signals run concurrently.

`mg_shape` is exposed on the MG/ESP page as the "MG Shape" knob (slot 2,
replacing the old discrete `mg_wave` enum). `mg_pw` is settable via menu
(non-knob param) to keep the panel matching the MS-20's single rotary look.

The discrete `mg_wave` enum still works as a back-compat input — old presets
with "Tri"/"Saw"/"Square"/"Rev-Saw" map to the corresponding `mg_shape`
positions automatically.

## MS-10 Mode (Modern page toggle)
When `ms10_mode=On`, Aphex collapses to the MS-10 layout:
- VCO 2 contribution silenced
- HPF bypassed (MS-10 has only LPF)
- EG 1 ignored (MS-10 has only one envelope, the HADSR — same as MS-20 EG2)
- VCO 1 still has all 4 MS-10 waveforms (Tri/Saw/Pulse/Noise)
- LPF stays as the same K35/OTA cascade (REV.1 by default — historically MS-10
  shipped only with KORG-35)
- ESP stays available (MS-10 had ESP via the ext sig in / EG/Ext knob)
- Patchbay is reduced — VCO 2 / HPF jacks become no-ops

## Analog drift system (src/dsp/drift.h)
- Multi-source physically-motivated drift, original implementation inspired by
  the public taxonomy of MI Braids' `vco_jitter_source.h` (MIT) and U-He Diva's
  Trimmers panel (closed source, taxonomy only). License: MIT.
- Five sources combined per instance:
  1. **Per-instance fixed offsets** — VCO1/2/sub detune (~±5 cents), filter
     calibration error (~±2%), env time scaling (~±2.5%). Set once at instance
     creation from a pointer-derived seed → each instance has its own personality.
  2. **Slow random walk** (~0.3 Hz cutoff via leaky integration) — models thermal
     drift. ±12 cents max at full intensity.
  3. **Mid-rate flutter** (6-15 Hz sine LFOs at slightly different rates per VCO)
     — models mains hum / power supply coupling. ±1.5 cents at full intensity.
  4. **Per-sample phase jitter** — broadband noise on phase increment, models
     thermal noise in integrator caps.
  5. **Note-on phase re-roll** — flutter LFOs get fresh phases each note-on.
- `p_drift` global knob (0..1, default 0.35) scales the time-varying components.
  Fixed personality offsets stay regardless of p_drift.
- Per-VCO `v1_drift`/`v2_drift` knobs (already in module.json) act as Diva-style
  per-VCO trims.
- Block-rate update + per-sample linear interpolation keeps slow drift glitch-free
  while staying very cheap (~5 ALU ops per sample for the lerp).
- Cost: drift_t struct ~140 bytes per instance; ~10ns per sample tick on the
  Move's ARM64 (well within budget).

## Factory presets
**41 presets** (Init + 40 character patches), accessible via the Preset menu on
the root page. `PRESET_NAMES` / `PRESET_COUNT` in `aphex.c` and the `preset`
enum in `module.json` are the source of truth and MUST stay in sync. Each
`apply_preset_*` calls `apply_init_preset()` first, then overrides only what
defines its character.

Distribution (inspired by Korg Collection MS-20 V2 and Arturia MS-20 V):
8 Bass · 8 Lead · 4 Pad · 3 Keys · 3 Sequence · 5 SFX · 4 Drone · 5 ESP/External.

`apply_init_preset()` defaults: REV.1, **HP+LP** filter cascade, EG1→filter
(unipolar) + subtle MG→LPF wobble, EG2→amp.

## Critical constraints
- NEVER allocate memory in `render_block` — all state lives in `synth_t`
- NEVER call printf / log / mutex in `render_block`
- Output path: `modules/sound_generators/aphex/` (NOT audio_fx)
- `.so` MUST be named `dsp.so` (not `aphex.so`)
- `.so` MUST be `chmod +x` after deploy (`scripts/install.sh` handles this)
- Files on Move owned by `ableton:users`
- Release: tag `vX.Y.Z` MUST match `version` in `src/module.json` exactly
- `release.json` is auto-updated by CI — never edit manually

### Per-Schwung gotchas
- `plugin_api_v2_t` has 8 fields including `get_error` — set to NULL but MUST exist
  (missing it shifts `render_block` ptr → SIGSEGV)
- `get_param` MUST return `-1` for unknown keys, NOT 0 (returning 0 breaks Master FX
  menu editing for float/int params)
- Enum `get_param` returns **string names** (e.g. "Saw"), not integers
- Enum `set_param` accepts both string name and numeric index (we use `parse_enum`)
- module.json changes (chain_params, ui_hierarchy) require **power cycling the Move** to
  reload — re-adding the module from a slot only reloads the .so
- The `ui_hierarchy` in module.json is what the Shadow UI uses — we do NOT also return
  it from `get_param` (sound generators use module.json hierarchy + chain_params)
- Per-sample modulation for filter cutoff and pitch — per-block staircase artifacts
  are audible at any LFO rate above ~30Hz (per Denis lessons)
- All filter cutoff smoothing at ~20ms (`SMOOTH = 0.135`)
- Linear envelope release — exponential makes 1.5s feel like 10s (Denis lesson)

## Going polyphonic (v0.3 roadmap)
1. Change `voice_t voice` to `voice_t voices[N_VOICES]`, e.g. N=4
2. Add `int voice_cursor` for round-robin allocation
3. In `on_midi` Note On: find a free voice, or steal `voices[voice_cursor++ % N]`
4. In Note Off: scan `voices[]` for matching note, set `e2_stage = 3`
5. In `render_block`: accumulate output across all active voices, divide by `N_VOICES`
6. Keep MG / S&H / ESP global (single instance) — don't duplicate per voice
7. Patchbay: per-voice if you want per-note S&H; global is fine for v0.3

## Build & deploy
```bash
./scripts/build.sh          # Docker ARM64 cross-compile
./scripts/install.sh        # scp to move.local, fix ownership, restart schwung
# Override host:
MOVE_HOST=192.168.1.42 ./scripts/install.sh
```

## Release
Use the `/move-schwung-release` skill (commit, tag, push, CI builds, GitHub release).

## Source / license notes
- All DSP is original (no GPL'd sources). Free to keep MIT.
- K35 (src/dsp/k35.h) is clean-room from Pirkle AN-5/AN-7v2 + Zavalishin TPT.
  No standalone test harness ships yet — filter stability (high-reso /
  self-oscillation) is verified by ear on-device, not by an automated suite.
- ESP pitch tracker: YIN algorithm (de Cheveigné & Kawahara 2002), implemented
  in `src/dsp/yin.h` and used by `update_esp` — done, not a TODO.
