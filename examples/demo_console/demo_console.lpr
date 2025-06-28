program demo_console;

{$mode objfpc}{$H+}
{$codepage utf8}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  fpidn
  ;

begin
  SetMultiByteConversionCodePage(CP_UTF8);

  Writeln('Converting domain to ASCII:');
  Writeln('пример: münchen.de → ', UnicodeToIDN('münchen.de'));

  Writeln('Back conerting:');
  Writeln('xn--mnchen-3ya.de → ', IDNToUnicode('xn--mnchen-3ya.de'));
end.

