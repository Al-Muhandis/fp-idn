#!/bin/bash

echo "Building benchmarks..."

# Determine FreePascal compiler
FPC_CMD="${FPC:-$(command -v fpc)}"
if [ -z "$FPC_CMD" ] || [ ! -x "$FPC_CMD" ]; then
  echo "ERROR: FreePascal compiler (fpc) not found. Install FPC and set the FPC environment variable if needed."
  exit 1
fi

# Ensure the output directory exists
mkdir -p ../lib
mkdir -p lib

# Compile the console test application
echo "Compiling the console test application..."
"$FPC_CMD" -Mobjfpc -Scghi -O1 -g -gl -l -vewnhibq \
  -Fu. -Fu.. -FUlib/ \
  benchmarks/benchconsole.lpr

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to compile benchmarks"
  exit 1
fi

echo "Running benchmarks..."
./benchmarks/benchconsole

echo
echo "Benchmarks completed."
