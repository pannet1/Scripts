#!/bin/xonsh

import os
import glob

folders = [path for path in glob.glob('*') if os.path.isdir(path)]
if folders:
    sorted = folders.sort()
    print('\n'.join(folders))
else:
    print("no folders present")
