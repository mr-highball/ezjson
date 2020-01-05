{$Mode delphi}

program ezjson_test;

uses
  ezjson,
  {%H-}Rtti,
  TypInfo;

type

  { TTestDecorated }
  (*
    a simple object decorated with a custom name to be used when serializing and
    deserializing, as well as some simple typed properties to include in
    serialization
  *)
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

  { ITestSimpleIntf }
  (*
    a simple property interface with a decorated object name.
    we cannot decorate properties here, because this results
    in a compile time error (thinking because interfaces have no "published"
    section
  *)
  [JsonObject('interfacesCanHaveNames')]
  ITestSimpleIntf = interface
    ['{092BD9A8-3572-4128-BBB3-18B7803C2214}']
    function GetTest: String;
    procedure SetTest(const AValue: String);

    property Test : String read GetTest write SetTest;
  end;

  { TTestSimpleIntfImpl }
  (*
    when implementing an interface and json serialization is needed,
    the object implementation needs to have the json property decorators
    *not* the interface
  *)
  TTestSimpleIntfImpl = class(TInterfacedObject, ITestSimpleIntf)
  private
    FTest : String;
    function GetTest: String;
    procedure SetTest(const AValue: String);
  published

    [JsonProperty('test')]
    property Test : String read GetTest write SetTest;
  end;

{ TTestSimpleIntfImpl }

function TTestSimpleIntfImpl.GetTest: String;
begin
  Result := FTest;
end;

procedure TTestSimpleIntfImpl.SetTest(const AValue: String);
begin
  FTest := AValue;
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
const
  VAL = 'a value';
var
  LTest : ITestSimpleIntf;
  LJSON,
  LError : String;
begin
  LTest := TTestSimpleIntfImpl.Create;
  LTest.Test := VAL;

  //serialize the object to json
  if not (EZSerialize<ITestSimpleIntf>(LTest, LJSON, LError)) then
    WriteLn('TestSimpleIntf::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestSimpleIntf::failed, value not found, result = ', LJSON)
  else
    WriteLn('TestSimpleIntf::success, result = ', LJSON);
end;

procedure TestSimpleDeserialize;
const
  VAL = 'a value';
var
  LTest : TTestDecorated;
  LJSON,
  LError : String;
begin
  //create a simple object and assign the test value
  LTest := TTestDecorated.Create;
  LTest.Test := VAL;

  //serialize the object to json so we can use this for deserialize
  if not (EZSerialize<TTestDecorated>(LTest, LJSON, LError)) then
    WriteLn('TestSimpleDeserialize::failed to serialize')
  else if not (Pos(VAL, LJSON) >= 1) then
    WriteLn('TestSimpleDeserialize::failed, value not found, result = ', LJSON);

  //now we can update the value of the object to nothing and attempt to
  //set it via deserialization
  LTest.Test := '';
  if not (EZDeserialize<TTestDecorated>(LJSON, LTest, LError)) then
    WriteLn('TestSimpleDeserialize::failed to deserialize')
  else if not (LTest.Test = VAL) then
    WriteLn('TestSimpleDeserialize::failed to deserialize, value not found')
  else
    WriteLn('TestSimpleDeserialize::success');

  //cleanup
  LTest.Free;
end;

begin
   //TestSimple;
   //TestCustomName;
   //TestNonDecoratedObject;
   //TestComplex;
   //TestSimpleIntf;
   TestSimpleDeserialize;

   //wait for input
   ReadLn;
end.

