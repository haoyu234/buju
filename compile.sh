#! /bin/bash

set -eu

nim c -d:release -d:danger bench.nim
# nim c -d:debug -d:bujuDumpUpdateResult bench.nim

# nim c -d:release example.nim

# nim js -d:danger -d:debug -d:bujuDumpSkip -d:bujuDumpDirty -d:bujuDumpUpdateResult tools/viewer/app.nim
# python assets/tpl.py

# nim c -d:debug --debugger:native --lineDir:off --passC:"-g" --cc:clang -t:"-fsanitize=fuzzer,address,undefined" -l:"-fsanitize=fuzzer,address,undefined" -d:nosignalhandler --nomain:on -o:fuzzer tools/fuzzer/app.nim
# nim c -d:debug --debugger:native --lineDir:off --passC:"-g" --cc:clang -t:"-fsanitize=fuzzer,address,undefined" -l:"-fsanitize=fuzzer,address,undefined" -d:nosignalhandler --nomain:on -o:app1 tools/fuzzer/app1.nim
# nim c -d:debug --lineDir:off -o:app2 tools/fuzzer/app2.nim
