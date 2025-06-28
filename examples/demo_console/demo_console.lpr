program demo_console;

{$mode objfpc}{$H+}

uses
  SysUtils, fpidn;

begin
  Writeln('UnicodeToIDN: ', UnicodeToIDN(''пример.рф''));
  Writeln('IDNToUnicode: ', IDNToUnicode(''xn--e1afmkfd.xn--p1ai''));
end.
