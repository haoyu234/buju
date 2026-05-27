#! /bin/bash

set -eu

# nim c -d:release -d:danger bench.nim
# nim c -d:debug -d:bujuDumpUpdateResult bench.nim

# nim c -d:release example.nim

# nim js -d:danger -d:debug -d:bujuDumpSkip -d:bujuDumpDirty -d:bujuDumpUpdateResult tools/viewer/app.nim
# python assets/tpl.py

# nim c -d:debug \
#   --cc:clang --debugger:native --passC:"-g" -t:"-fsanitize=fuzzer,address,undefined" -l:"-fsanitize=fuzzer,address,undefined" \
#   -d:libFuzzer \
#   -d:nosignalhandler --nomain:on \
#   -o:tools/fuzz tools/fuzzer/fuzz.nim

# nim c -d:debug --lineDir:off -o:tools/dump tools/fuzzer/dump.nim
# nim c -d:debug --lineDir:off -o:tools/fuzz tools/fuzzer/fuzz.nim
# nim c -d:debug --lineDir:off -o:tools/serve tools/fuzzer/serve.nim
# nim c -d:debug --lineDir:off -o:tools/report tools/fuzzer/report.nim
