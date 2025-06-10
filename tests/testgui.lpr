program testgui;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, test_idn_n_punycode, test_idn_n_punycode_property
  ;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

