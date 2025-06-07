#!/bin/bash

echo "Building tests for fpidn and fppunycode..."
echo

# Compile the console test application
echo "Compiling the console test application..."
fpc -Mobjfpc -Scghi -O1 -g -gl -l -vewnhibq \
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
