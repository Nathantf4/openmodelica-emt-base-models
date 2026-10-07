#!/usr/bin/env python3
"""Run from the package root with OMPython installed; fresh CSVs go to Results/."""
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import time

from OMPython import OMCSessionLocal


def finite_csv(path, started):
    if not path.is_file() or path.stat().st_mtime_ns < started:
        raise ValueError('Missing or stale CSV')
    with path.open(newline='') as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames or 'time' not in reader.fieldnames or len(set(reader.fieldnames)) != len(reader.fieldnames):
            raise ValueError('Invalid CSV header')
        first = previous = None
        count = 0
        for row in reader:
            values = {k: float(v) for k, v in row.items()}
            if not all(math.isfinite(v) for v in values.values()):
                raise ValueError('Nonfinite CSV cell')
            t = values['time']
            if previous is not None and t < previous:
                raise ValueError('Backward time')
            if first is None:
                first = t
            previous = t
            count += 1
    if count < 2 or first != 0 or previous != 3:
        raise ValueError('Incomplete 0..3 s horizon')
    return {'rows': count, 'first_time': first, 'last_time': previous, 'finite': True,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def main():
    root = Path.cwd()
    results = root / 'Results'
    results.mkdir(exist_ok=True)
    reports = []
    omc = OMCSessionLocal(timeout=120)

    def command(expression):
        try:
            return omc.sendExpression(expression)
        except Exception as error:
            print(f'{type(error).__name__}: {error}', flush=True)
            raise
        finally:
            # OMPython can consume the error buffer; both exception and raw text matter.
            print(omc.sendExpression('getErrorString()', parsed=False, raise_on_error=False), flush=True)

    try:
        if command('loadModel(Modelica,{"4.1.0"},requireExactVersion=true)') is not True:
            raise ValueError('Could not load MSL 4.1.0')
        print('OpenModelica:', command('getVersion()'), 'MSL:', command('getVersion(Modelica)'))
        command('cd(' + json.dumps(str(results)) + ')')
        for model in ('EmtMachineBase', 'EmtMachineBaseFault', 'BrokenMissingClass'):
            broken = model == 'BrokenMissingClass'
            source = root / ('Fixtures' if broken else 'Models') / (model + '.mo')
            target = results / (model + '_res.csv')
            target.unlink(missing_ok=True)
            started = time.time_ns(); wall = time.perf_counter()
            report = {'model': model, 'status': 'FAIL', 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest()}
            try:
                if command('loadFile(' + json.dumps(str(source)) + ')') is not True:
                    raise ValueError('loadFile rejected source')
                diagnostic = ''
                try:
                    checked = command(f'checkModel({model})')
                except Exception as error:
                    checked = ''
                    diagnostic += str(error)
                    if not broken:
                        raise
                if not broken and 'completed successfully' not in checked:
                    raise ValueError('checkModel did not succeed')
                simulation = {}
                try:
                    simulation = command(f'simulate({model},startTime=0,stopTime=3,numberOfIntervals=30000,tolerance=1e-6,outputFormat="csv",variableFilter="time|aimc[.](is.*|wMechanical|tauElectrical)|currentRMS[.]I|terminalVRMS|vTerminal.*|iSource.*|faultSwitch[.](i.*|control.*)|loadTorque[.]tau",fileNamePrefix="{model}")')
                except Exception as error:
                    diagnostic += str(error)
                    if not broken:
                        raise
                report.update(check=checked, simulation=simulation, diagnostic=diagnostic)
                print(simulation.get('messages', ''), flush=True)
                if broken:
                    if ('completed successfully' in checked or simulation.get('resultFile') or target.exists()
                            or not re.search(r'Class .*IdealClosingSwitc.*not found', diagnostic)):
                        raise ValueError('Missing-class negative control did not fail as expected')
                    report['status'] = 'EXPECTED_FAIL'
                    print(f'EXPECTED_FAIL: {model}; no CSV\n{diagnostic}', flush=True)
                else:
                    if not simulation.get('resultFile') or Path(simulation['resultFile']).resolve() != target:
                        raise ValueError('simulate returned no expected result')
                    report['data'] = finite_csv(target, started)
                    report['status'] = 'PASS'
                    print(f'PASS: {model}; fresh finite CSV, full 0..3 s horizon', flush=True)
            except Exception as error:
                report['error'] = f'{type(error).__name__}: {error}'
                print(f'FAIL: {model}; {report["error"]}', flush=True)
            report['wall_seconds'] = time.perf_counter() - wall
            reports.append(report)
    except Exception as error:
        print(f'FAIL: setup; {type(error).__name__}: {error}', flush=True)
    finally:
        (results / 'verification.json').write_text(json.dumps(reports, indent=2) + '\n')
        (results / 'omc.log').write_text(omc.get_log())
        omc.sendExpression('quit()', raise_on_error=False)
    return 0 if len(reports) == 3 and [r['status'] for r in reports] == ['PASS', 'PASS', 'EXPECTED_FAIL'] else 1


if __name__ == '__main__':
    sys.exit(main())
