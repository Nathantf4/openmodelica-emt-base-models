# Verification

The numbers below were produced with OpenModelica 1.27.1 and MSL 4.1.0 (4.1.0+maint.om).
Everything reproducible from this repository alone is marked as such; the stricter
checked-runner gates were run in the originating project with the same model sources.

## Method

- Both good models: `loadFile` → `checkModel` clean → `simulate` (30 000 intervals over 3 s,
  tolerance 1e-8 in the checked runner; the repo scripts use 1e-6 with the same horizon) →
  fresh CSV, all cells finite, nondecreasing time, final time exactly 3.0 s.
- Independent reference: plain complex-arithmetic per-phase equivalent circuit
  (Rs + jXσs, jXm ∥ (Rr/s + jXσr); torque = 3·p·|Ir′|²·(Rr/s)/ωs) solved for slip by
  bisection — never the model's own `powerBalance` record. With the series line folded into
  the stator branch: slip 0.04135 → 1437.970 rpm, 101.483 A, torque 160.84 N·m
  (quadratic load 161.4 N·m at 1440.45 rpm).
- Fault current reference: `100 / |0.005 + j·2π·50·9.549e-5 + 1e-5| = 3287.80 A RMS`.
  Phase RMS measured time-weighted over exactly the last two cycles before clearing,
  after more than three DC time constants (τ = 19.1 ms).
- Event edges read from the `faultSwitch.control` columns in the CSV, not assumed.
- Parameter overrides validated by the runner's applicability gates plus runtime readback.
- Negative control: `Fixtures/BrokenMissingClass.mo` misspells `IdealClosingSwitch` as
  `IdealClosingSwitc`; it must produce `Class ... not found in scope` and no result file —
  and raw `omc` exits 0 anyway, which is why exit status is never a pass criterion.

## Results

| # | Check | Reference | Simulated | Result |
|---|---|---|---|---|
| A | Final mechanical speed | 1440.45 rpm (MSL doc nominal) | 1437.969522 rpm (0.172 %) | PASS (<1.0 %) |
| A | Final stator RMS current | 100 A (MSL doc nominal) | 101.483344 A (1.483 %) | PASS (<3.0 %) |
| A | Speed vs independent circuit with line + quadratic load | 1437.970698 rpm | 1437.969522 rpm (0.00008 %) | PASS |
| A | Current vs independent circuit | 101.482645 A | 101.483344 A (0.0007 %) | PASS |
| A | Steady-state gate (speed span, final 0.1 s) | < 0.1 rpm | 4.8e-8 rpm | PASS |
| B | Fault-on terminal magnitude (max) | ≤ 1 % of pre-fault 98.06 V | 0.0578 V (0.059 %) | PASS |
| B | Source fault current, phases 1/2/3 | 3287.80 A RMS | 3288.36 / 3293.84 / 3277.77 A | PASS (<0.31 %) |
| B | Kirchhoff: max abs(sum of 3 source currents) | < 1e-6 · max abs(i) | 3.78e-8 A (relative 5.1e-12) | PASS |
| B | Speed pre-fault / min during fault / recovered | dip > 1 rpm, recovery within 1 % | 1437.97 / 1147.77 / 1437.97 rpm | PASS |
| C | Fault switch closes | 1.5 s ± 0.0001 | 1.500000000003 s | PASS |
| C | Fault switch opens | 1.6 s ± 0.0001 | 1.600000000003 s | PASS |
| D | `JLoad` 0.29 → 0.58 (readback) | slower ramp | 888.98 → 552.86 rpm at 0.5 s; 90 % crossing 0.6295 → 0.8717 s | PASS |
| D | `TLoad` 161.4 → 193.68 (readback) | lower final speed | 1437.97 → 1424.21 rpm | PASS |
| E | Broken fixture | missing-class diagnostic, no CSV, raw omc exit 0 | exactly as expected | EXPECTED_FAIL |
| F | Fresh-folder replay / ZIP-extract replay / OMPython replay | 2 finite full-horizon CSVs each | PASS | PASS |

Simulation wall time: ~9–13 s per model (plus ~2 s C compilation) on a modest x86-64 laptop.

## Known artifact (disclosed, not a pass/fail input)

The ideal fault switch opening into inductive current produces a single 326.8 MV terminal
magnitude sample at 1.6000 s. There is no arc or surge-limiting capacitance in the circuit;
the value is nonphysical, retained in the CSV, and plotted on a symlog axis. The checks above
do not validate any clearing-overvoltage behavior.
