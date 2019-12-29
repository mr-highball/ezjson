{$Mode delphi}

program ezjson_test;

uses
  ezjson,
  Rtti,
  TypInfo;

type

  { TTestDecorated }

  [JsonObject('myTestObject')]
  TTestDecorated = class(TObject)
  private
    FTest : String;
    function GetTest: String;
    procedure SetTest(const AValue: String);
  published
    [JsonProperty('test')]
    property Test : String read GetTest write SetTest;
  end;

{ TTestDecorated }

function TTestDecorated.GetTest: String;
begin
  Result := FTest;
end;

procedure TTestDecorated.SetTest(const AValue: String);
begin
  FTest := AValue;
end;

(*
  tests a simple object for serialize and deserialize with a single property
*)
procedure TestSimple;
var
  LTest : TTestDecorated;
  LJSON,
  LError : String;
begin
  LTest := TTestDecorated.Create;
  LTest.Test := 'a value';

  //serialize the object to json
  if not (EZSerialize<TTestDecorated>(LTest, LJSON, LError)) then
    WriteLn('TestSimple::failed to serialize')
  else if (LJSON = '') or (LJSON = '{}') then
    WriteLn('TestSimple::failed, result is empty, or has no properties')
  else
    WriteLn('Test::success, result = ', LJSON);

  //cleanup
  LTest.Free;
end;

(*
  tests whether or not the custom name works for an object
*)
procedure TestCustomName;
begin
end;

(*
  tests whether or not non-decorated object can still be serialized
  (this should be yes)
*)
procedure TestNonDecoratedObject;
begin
end;

(*
  tests if a simple interface decorated works like objects
*)
procedure TestSimpleIntf;
begin
end;

begin
   TestSimple;

   //wait for input
   ReadLn;
end.

