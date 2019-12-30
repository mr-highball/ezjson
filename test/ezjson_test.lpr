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
    FTestInt : Integer;
  published
    [JsonProperty('test')]
    property Test : String read FTest write FTest;

    [JsonProperty('testInteger')]
    property TestInt : Integer read FTestInt write FTestInt;
  end;

  { TTestNonDecorated }
  (*
    object name decorator is optional, so this object contains
    at least one decorated property without the object decorator
  *)
  TTestNonDecorated = class(TObject)
  private
    FTest: String;
  published
    [JsonProperty('test')]
    property Test : String read FTest write FTest;
  end;

  { TTestComplex }

  TTestComplex = class(TObject)
  private
    FDecorated: TTestDecorated;
    FNonDecorated: TTestNonDecorated;
  public
    constructor Create;
    destructor Destroy; override;
  published
    [JsonProperty('decorated')]
    property Decorated : TTestDecorated read FDecorated;

    [JsonProperty('nonDecorated')]
    property NonDecorated : TTestNonDecorated read FNonDecorated;
  end;


{ TTestComplex }

constructor TTestComplex.Create;
begin
  FDecorated := TTestDecorated.Create;
  FNonDecorated := TTestNonDecorated.Create;
end;

destructor TTestComplex.Destroy;
begin
  FDecorated.Free;
  FNonDecorated.Free;
  inherited Destroy;
end;

(*
  tests a simple object for serialize and deserialize with simple properties
*)
procedure TestSimple;
const
  VAL = 'a value';
var
  LTest : TTestDecorated;
  LJSON,
  LError : String;
begin
  LTest := TTestDecorated.Create;
  LTest.Test := VAL;

  //serialize the object to json
  if not (EZSerialize<TTestDecorated>(LTest, LJSON, LError)) then
    WriteLn('TestSimple::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestSimple::failed, value not found, result = ', LJSON)
  else
    WriteLn('TestSimple::success, result = ', LJSON);

  //cleanup
  LTest.Free;
end;

(*
  tests whether or not the custom name works for an object
*)
procedure TestCustomName;
const
  VAL = 'customName';
var
  LTest : TTestDecorated;
  LJSON,
  LError : String;
begin
  LTest := TTestDecorated.Create;

  //serialize the object to json
  if not (EZSerialize<TTestDecorated>(LTest, LJSON, LError, VAL)) then
    WriteLn('TestCustomName::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestCustomName::failed, value not found, result = ', LJSON)
  else
    WriteLn('TestCustomName::success, result = ', LJSON);

  //cleanup
  LTest.Free;
end;

(*
  tests whether or not non-decorated object can still be serialized
  (this should be yes)
*)
procedure TestNonDecoratedObject;
const
  VAL = 'a value';
var
  LTest : TTestNonDecorated;
  LJSON,
  LError : String;
begin
  LTest := TTestNonDecorated.Create;
  LTest.Test := VAL;

  //serialize the object to json
  if not (EZSerialize<TTestNonDecorated>(LTest, LJSON, LError)) then
    WriteLn('TestNonDecoratedObject::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestNonDecoratedObject::failed, value not found, result = ', LJSON)
  else
    WriteLn('TestNonDecoratedObject::success, result = ', LJSON);

  //cleanup
  LTest.Free;
end;

(*
  tests serialization of a complex (compound) object with decorated
  object properties
*)
procedure TestComplex;
const
  VAL = 'a value';
var
  LTest : TTestComplex;
  LJSON,
  LError : String;
begin
  LTest := TTestComplex.Create;
  LTest.Decorated.Test := VAL;

  //serialize the object to json
  if not (EZSerialize<TTestComplex>(LTest, LJSON, LError)) then
    WriteLn('TestComplex::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestComplex::failed, value not found, result = ', LJSON)
  else
    WriteLn('TestComplex::success, result = ', LJSON);

  //cleanup
  LTest.Free;
end;

(*
  tests if a simple interface decorated works like objects
*)
procedure TestSimpleIntf;
begin
end;



begin
   TestSimple;
   TestCustomName;
   TestNonDecoratedObject;
   TestComplex;

   //wait for input
   ReadLn;
end.

