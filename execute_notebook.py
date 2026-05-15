import nbformat
from IPython import get_ipython

path = r'd:\School\HK6\NT549 - Học máy tăng cường cho hệ thống mạng\DoAn\experimentes-hub\rl-training.ipynb'
with open(path, 'r', encoding='utf-8') as f:
    nb = nbformat.read(f, as_version=4)

targets = ['ActionSpace', 'RewardCalculator', 'TrainingCallback', 'BaselineRandomAgent', 'FailureScenario']
found = {t: False for t in targets}

# This is a simplified execution logic. In a real environment, we'd use an executor.
# Since I cannot easily run interactive kernels here with full state persistence across cells via shell commands easily without a script,
# I will simulate the 'execution' by finding the cells and potentially running them in a single script if they are Python code.

code_to_run = []
for cell in nb.cells:
    if cell.cell_type == 'code':
        source = cell.source
        for target in targets:
            if target in source:
                 code_to_run.append(source)
                 found[target] = True
                 break

if all(found.values()):
    # Execute the collected code
    try:
        exec('\n'.join(code_to_run), globals())
        print('All target cells executed successfully')
    except Exception as e:
        print(f'Error during execution: {e}')
else:
    missing = [k for k, v in found.items() if not v]
    print(f'Missing cells: {missing}')
