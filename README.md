# Aphex

Korg MS-10 / MS-20 hybrid mono synth with semi-modular patchbay and External Signal Processor, for [Ableton Move](https://www.ableton.com/move/), built for the [Schwung](https://github.com/charlesvestal/schwung) framework.

## Features

- **Faithful MS-20 control surface** — VCO 1 (Tri/Saw/PW-Square/Noise, 32′/16′/8′/4′), VCO 2 (Saw/Square/Pulse/Ring, 16′/8′/4′/2′), VCO Master (Tune, Portamento, MG/T.EXT, EG1/EXT), VCF HPF + LPF with Cutoff/Peak/MG/EG attenuators, EG 1 trapezoid (D-A-R), EG 2 HADSR with 20s hold, MG with continuous waveshape
- **Two filter circuits** (switchable, REV.1 / REV.2):
  - **REV.1 (KORG-35)** — early MS-20 / MS-10 character: Sallen-Key topology, asymmetric forward-path saturation, "creamy fuzz" break-up at self-osc — harsher, more rock'n'roll
  - **REV.2 (OTA / LM13600)** — late MS-20: feedback-loop saturation, buffered inter-stage, "howl/whistle" character, smoother and cleaner — resonance develops earlier in the knob travel
- **Source-side patchbay** (MS-20-faithful): 8 input-jack source selectors, no destination-depth knobs. Attenuation lives in the panel knobs (HPF MG, LPF EG, etc.), exactly like the real hardware.
- **MS-10 mode** — collapses signal flow to VCO 1 + LPF + EG 2 only, hiding VCO 2 / HPF / EG 1 contributions
- **External Signal Processor** — turn Move's line-in into pitch CV (YIN tracker), envelope follower, gate, and routable raw audio with Lo Cut, Hi Cut, CV Adjust, Threshold per MS-20 spec
- **Multi-source analog drift** — per-instance fixed offsets, slow random walk (thermal), mid-rate flutter (mains hum), per-sample phase jitter, note-on phase re-roll. Each plugin instance gets its own personality from a pointer-derived seed.
- **Modern page** — Drift, Drive, KeyTrack, Filter Rev, MS-10 Mode, V1/V2 Drift trim, MW→MG / MW→Filt — non-period-correct extras tucked away from the main panel
- Mono with voice state designed for clean polyphonic expansion (v0.3)

## Pages (v0.2)

| Page | Knobs |
|------|-------|
| Aphex (root) | LPF Cut · LPF Peak · HPF Cut · HPF Peak · MG Freq · MG Depth · M.Tune · Volume |
| VCO 1 | Scale · Wave · PW |
| VCO 2 | Scale · Pitch · Wave · PW · Sync · FM · Detune |
| Mixer | VCO 1 · VCO 2 · Sub · Ring · Noise · Color · ESP Aud · FB |
| Filter | HPF Cut · HPF Peak · HPF MG · HPF EG · LPF Cut · LPF Peak · LPF MG · LPF EG |
| Envelopes | E1 Delay · E1 Atk · E1 Rel · E2 Hold · E2 Atk · E2 Dcy · E2 Sus · E2 Rel |
| MG / ESP | MG Freq · MG Wave · MG Depth · ESP Sig Lvl · ESP Lo Cut · ESP Hi Cut · ESP Threshold · ESP CV Adj |
| Patchbay | KBD CV · T.EXT · VCO Freq · HPF EG/Ext · LPF EG/Ext · Initial Gain · PWM In · Ext Sig |
| Modern | Drift · Drive · KeyTrack · Filter Rev · MS-10 Mode · V1 Drift · MW→MG · MW→Filt |

## Patchbay (MS-20 input jacks)

Each row is a single MS-20 input jack. Pick what's plugged in. The panel attenuators (HPF MG, LPF EG, etc.) control intensity — there are no per-jack depth knobs, matching the original hardware.

```
KBD CV In       [Normal ▾]              ← what feeds VCO Hz/V CV
T.EXT           [MG ▾]                  ← replaces MG in panel attenuators
VCO Freq        [EG1 ▾]                 ← replaces EG1 in VCO Master EG1/EXT
HPF EG/Ext      [EG2 ▾]                 ← replaces EG2 in HPF EG2/EXT
LPF EG/Ext      [EG2 ▾]                 ← replaces EG2 in LPF EG2/EXT
Initial Gain    [None ▾]                ← INITIAL GAIN — adds to EG2's VCA control
PWM In          [None ▾]                ← modulates VCO 1 PW-Square
Ext Sig         [None ▾]                ← VCF external signal input
```

## ESP — External Signal Processor

Plug into Move's line-in. The synth tracks pitch with the YIN algorithm, follows envelope, gates on threshold, and exposes raw audio — all routable through the patchbay. Try sending external audio into the Mixer (ESP Aud) and out through the Korg-35 filter for the iconic MS-20 mangler sound.

## Building

```sh
./scripts/build.sh
```

Requires Docker (cross-compiles for `aarch64-linux-gnu`).

## Installing

```sh
./scripts/install.sh
# Override target:
MOVE_HOST=192.168.1.42 ./scripts/install.sh
```

Or install via the Module Store in Schwung once published.

## Roadmap

- **v0.1** — Mono, full destination-depth patchbay, ESP, 9 pages, factory presets
- **v0.2** — MS-faithful panel layout, REV.1/REV.2 filter switch, source-side patchbay, MS-10 mode, EG1 trapezoid + EG2 HADSR, multi-source drift system, YIN pitch tracker
- **v0.3** — Polyphonic (4 voices, last-note stealing), continuously variable MG waveshape, factory preset library

## Credits

- Inspired by Korg MS-10 (1978) and MS-20 (1978) — designed by Fumio Mieda
- Filter topology research: Tim Stinchcombe ([MS-10/MS-20 Filters study](https://www.timstinchcombe.co.uk/synth/MS20_study.pdf))
- YIN pitch tracker: de Cheveigné & Kawahara (2002)
- Drift taxonomy inspired by Mutable Instruments Braids and U-He Diva
- Built for the Schwung framework by Charles Vestal
- Aphex is named in honor of Richard D. James, lifelong MS-20 abuser

## License

MIT — see [LICENSE](LICENSE)
