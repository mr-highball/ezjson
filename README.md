# ezjson
a simple way to serialize / deserialize your classes by using decorators (custom attributes)

To request features or report a bug, open a github issue with details/steps to reproduce

# Sample

Below is a sample pulled from the console tester application which shows a possible use for ezjson

```pascal
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
  
  ...
  
procedure TestSimple;  
var
  LTest : TTestDecorated;
  LJSON,
  LError : String;
begin
  //setting a value on our test
  LTest := TTestDecorated.Create;
  LTest.Test := 'a test';
  
  //calling serialize
  if not (EZSerialize<TTestDecorated>(LTest, LJSON, LError)) then
    raise Exception.Create(LError) //failed to serialize
  else
    WriteLn(LJSON); //success
end;
```

and here's the output json 

```json
 { "myTestObject" : { "test" : "a value", "testInteger" : 0 } }
```

# Notes

1. make sure your decorated properties are in the **published** section
1. object / interface properties can be decorated as long as they also have property decorators
1. **JsonObject** is not required (if not supplied will determine name from class) but **JsonProperty** is
    * works as "opt-in" so non-decorated properties will **not** be serialized without

# How To Use

1. download and install lazarus if you don't already have it (http://www.lazarus-ide.org)
  or by using the super simple fpcupdeluxe (https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases)
1. git clone this repo
1. open ezjson_test.lpr and attempt to compile/run (F9 Key)
    * this project shows some basic usage of the library
    * also, by going to `Toolbar -> Project\Project Options\Paths` you can copy the `other units` text to include in your own project
1. add `.\src` path to your project `other units`
1. also to note, this project requires that you use the latest trunk fpc / lazarus (another reason to use fpcupdeluxe :) )


**Tip Jar**
  * :dollar: BTC - bc1q55qh7xptfgkp087sfr5ppfkqe2jpaa59s8u2lz
  * :euro: LTC - LPbvTsFDZ6EdaLRhsvwbxcSfeUv1eZWGP6
