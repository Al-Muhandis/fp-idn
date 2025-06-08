#!/bin/bash

echo "Building tests for fpidn and fppunycode..."
echo

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
  tests/testconsole.lpr

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to compile the console test application"
  exit 1
fi

echo "Compilation successful!"
echo

# Run tests
echo "Running tests..."
echo
./tests/testconsole --all

echo
echo "Tests completed."
