{ ezjson

  Copyright (c) 2020 mr-highball

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE.
}
unit ezjson;

{$mode delphi}

interface

uses
  Classes,
  SysUtils;

type

  { TNamedAttribute }

  TNamedAttribute = class(TCustomAttribute)
  strict private
    FName : String;
  private
    {%H-}constructor Create; overload;
    function GetName: String;
  public
    constructor Create(const AName : String); overload;
  published
    property Name : String read GetName;
  end;

  (*
    object decorator which allows for a custom name to be applied to
    and object or interface type
  *)
  JsonObject = class(TNamedAttribute)
  end;

  (*
    property decorator which controls name of the serialized property
    as well as "opting in" properties for serialization
  *)
  JsonProperty = class(TNamedAttribute)
  end;

  (*
    this method will attempt to serialize "source" into a json object.
    an optional custom name can be provided to override the default
    attribute value.
    for serialization to work, source needs to have its properties
    published / decorated
  *)
  function EZSerialize<T : TObject, IInterface>(const ASource : T;
    out JSON : String; out Error : String;
    const ACustomName : String = '') : Boolean;

  (*
    this method will attempt to deserialize "source" json and
    apply matched values to "destination". for mapping to work properly
    a destination needs to have it's properties published / decorated
  *)
  function EZDeserialize<T : TObject, IInterface>(const ASource : String;
    const ADestination : T; out Error : String) : Boolean;

implementation
uses
  fpjson,
  jsonparser;


function EZSerialize<T>(const ASource: T; out
  JSON: String; out Error: String; const ACustomName: String): Boolean;
begin
  Result := False;
  try
    //todo
  except on E : Exception do
    Error := E.Message;
  end;
end;

function EZDeserialize<T>(const ASource: String;
  const ADestination: T; out Error: String): Boolean;
begin
  Result := False;
  try
    //todo
  except on E : Exception do
    Error := E.Message;
  end;
end;

{ TNamedAttribute }

constructor TNamedAttribute.Create;
begin
  //hidden
end;

function TNamedAttribute.GetName: String;
begin
  Result := FName;
end;

constructor TNamedAttribute.Create(const AName: String);
begin
  FName := AName;
end;

end.

