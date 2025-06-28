# fp-idn

**fp-idn** is a lightweight Pascal library for encoding and decoding Internationalized Domain Names (IDN) using the [Punycode](https://datatracker.ietf.org/doc/html/rfc3492) algorithm. Designed to be compatible with FreePascal and Lazarus projects.

## Features

* ✅ Pure FreePascal implementation (no dependencies)
* 🌍 Supports full round-trip conversion between Unicode and Punycode
* 🔤 Includes domain-level IDN handling with subdomain support
* 🧪 Comes with comprehensive test coverage using FPCUnit

---

## Units

* `fppunycode.pas`: Core Punycode encode/decode functions
* `fpidn.pas`: Domain-level IDN wrapper functions (`IDNToUnicode`, `UnicodeToIDN`)
* `test_idn_n_punycode.pas`: Unit tests for both units
* `test_idn_n_punycode_property.pas`: Property-based tests
* `fpidn_rt.lpk`: Lazarus run-time package bundling the IDN units

---

## Usage

### Convert UTF-8 to Punycode

```pascal
uses fppunycode;

var
  puny: string;
begin
  puny := UTF8ToPunycode('тест'); // -> b1abfaa5a0a
end;
```

### Convert domain name using IDN unit

```pascal
uses fpidn;

var
  encoded, decoded: string;
begin
  encoded := UnicodeToIDN('пример.рф');
  decoded := IDNToUnicode(encoded);
end;
```

### Demo console application

A small console demonstration is located in `examples/demo_console`. Open the
`demo_console.lpi` project in Lazarus or build it with `lazbuild`:

```bash
lazbuild examples/demo_console/demo_console.lpi
./demo_console
```

---

## Build & Run Tests

Before running the scripts below make sure the FreePascal compiler is installed.
If it is not available in your `PATH`, set the `FPC` environment variable to the
full path of the `fpc` executable.

### Windows

Run the batch script:

```cmd
build_tests.bat
```

### Linux/macOS

Run the shell script:

```bash
./build_tests.sh
```

You will see FPCUnit test output with full results in XML and console form.

---

## Build & Run Benchmarks

The repository also includes simple performance benchmarks for `fppunycode` and `fpidn`.
They output results to the console and save them to `benchmarks/results.csv`.

### Windows

Run the batch script:

```cmd
build_benchmarks.bat
```

### Linux/macOS

Run the shell script:

```bash
./build_benchmarks.sh
```

---

## Requirements

* FreePascal 3.0+ (ensure `fpc` is accessible or set the `FPC` environment variable)
* Optional: [Lazarus IDE](https://www.lazarus-ide.org/) for integration in GUI-based tools

---

## License

MIT License — free to use in personal and commercial projects.

---

## Author

Developed by [@al-muhandis](https://github.com/al-muhandis)

Inspired by the need for lightweight, native Punycode support in FreePascal-based applications.
