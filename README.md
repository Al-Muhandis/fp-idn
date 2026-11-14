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

## Installation

### Via the Lazarus package

1. Clone or download this repository.
2. In Lazarus choose `Package → Open Package File (.lpk)` and open `fpidn_rt.lpk`.
3. In the package editor click `Compile`, then `Use → Add to Project` —
   Lazarus adds the package dependency to your project and extends the unit
   search path automatically.
4. Add `fpidn` and/or `fppunycode` to the `uses` clause of your program.

### Without the IDE package

`fppunycode.pas` and `fpidn.pas` depend on nothing beyond the FCL/RTL, so the
package step is optional: copy both units into your project folder, or add
their directory to the project's unit search path (`Other unit files (-Fu)` in
`Project → Project Options → Compiler Settings → Paths`).

---

## Usage

### Convert UTF-8 to Punycode

```pascal
uses fppunycode;

var
  puny: string;
begin
  // Primary API: False on malformed UTF-8 or arithmetic overflow,
  // puny is then guaranteed to be an empty string
  if not TryUTF8ToPunycode('тест', puny) then
    Writeln('invalid input');
  // success: puny = 'e1aybc'

  // Compatibility wrapper: returns an empty string on any failure
  puny := UTF8ToPunycode('тест'); // -> e1aybc
end;
```

### Convert domain name using IDN unit

```pascal
uses fpidn;

var
  encoded, decoded: string;
begin
  // Before encoding, a pragmatic IDNA mapping is applied: the Unicode
  // label separators U+FF0E/U+3002/U+FF61 are mapped to '.', and
  // ASCII/Cyrillic/Greek uppercase is folded to lowercase.
  // DNS length limits and forbidden ASCII characters fail with False.
  if not TryUnicodeToIDN('ПРИМЕР．РФ', encoded) then
    Writeln('invalid domain');
  // success: encoded = 'xn--e1afmkfd.xn--p1ai'

  // The decode direction keeps undecodable xn-- labels verbatim instead
  // of losing them, so it currently always succeeds
  if not TryIDNToUnicode(encoded, decoded) then
    Writeln('unreachable');
  // success: decoded = 'пример.рф'

  // Compatibility wrappers: empty string on any failure
  encoded := UnicodeToIDN('пример.рф');  // -> xn--e1afmkfd.xn--p1ai
  decoded := IDNToUnicode(encoded);      // -> пример.рф
end;
```

The `Try*` variants (`TryUnicodeToIDN`, `TryIDNToUnicode`,
`TryUTF8ToPunycode`, `TryPunycodeToUTF8`) are the recommended API: they
return `False` on invalid input (with the output parameter guaranteed
empty), while the plain functions project every failure to an empty
string. An empty input is a success with an empty result, not an error;
use the `Try*` variants to tell the two cases apart.

### Demo console application

A small console demonstration is located in `examples/demo_console`. Open the
`demo_console.lpi` project in Lazarus or build it with `lazbuild`:

```bash
lazbuild examples/demo_console/demo_console.lpi
./demo_console
```

---

## Limitations

The library implements Punycode (RFC 3492) plus a pragmatic subset of IDNA
mapping — not full IDNA2008/UTS-46 processing:

* **No NFC normalization.** The input is expected to be already normalized;
  composed and decomposed forms of the same name encode to different labels.
* **Case folding is an MVP.** Only ASCII `A-Z`, Cyrillic `U+0400..U+042F`
  (including `Ё → ё`) and basic Greek `U+0391..U+03A9` fold to lowercase.
  Other characters (e.g. Latin-1 `Ü`, Turkish `İ`) pass through unchanged.
* **UseSTD3ASCIIRules-lite.** Labels containing bytes below `$21` (control
  characters and space) or any of `<>"/\?#@:|` are rejected. Other non-LDH
  ASCII characters (e.g. `_`, `+`, `%`) pass through.
* **DNS length limits.** A label longer than 63 bytes (ASCII labels and
  `xn--` labels alike) or a domain longer than 253 bytes fails.
* **Label separators.** `U+FF0E` `．`, `U+3002` `。` and `U+FF61` `｡` are
  treated as dots by the encode direction only; the decode direction keeps
  them verbatim.
* **Strict input validation.** The encode direction requires well-formed
  UTF-8; the decode direction requires valid punycode. Invalid input fails
  (`Try*` returns `False`, plain functions return an empty string) instead
  of producing garbage.

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
