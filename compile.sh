#! /bin/bash

nim c -d:release -d:danger bench.nim

# nim c -d:release example.nim

# nim js -d:danger -d:release tools/viewer/app.nim
# python assets/tpl.py
