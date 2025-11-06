#! /bin/bash

nim c -d:release -d:danger bench.nim
nim c -d:release example.nim
