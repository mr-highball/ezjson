program ezjson_test;

uses ezjson;

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
begin
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
end.

