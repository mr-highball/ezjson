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
  function EZSerialize<T>(const ASource : T;
    out JSON : String; out Error : String;
    const ACustomName : String = '') : Boolean;

  (*
    this method will attempt to deserialize "source" json and
    apply matched values to "destination". for mapping to work properly
    a destination needs to have it's properties published / decorated
  *)
  function EZDeserialize<T>(const ASource : String;
    const ADestination : T; out Error : String) : Boolean;

implementation
uses
  fpjson,
  jsonparser,
  Rtti,
  TypInfo;


function EZSerialize<T>(const ASource: T; out
  JSON: String; out Error: String; const ACustomName: String): Boolean;
type
  TAttrArray = TArray<TCustomAttribute>;
  TPropArray = TArray<TRttiProperty>;
var
  LObj,
  LInner : TJSONObject;
  LContext: TRttiContext;
  LType : TRttiType;
  LProp : TRttiProperty;
  LAttributes : TAttrArray;
  LProps : TPropArray;
  I, J: Integer;
  LName,
  LPropName : String;
  LFound: Boolean;
  LPropAttr: JsonProperty;
  LPropVal: TValue;
begin
  Result := False;
  JSON := '{}';

  //nil check
  if not Assigned(ASource) then
    Exit;

  //create objects
  LObj := TJSONObject.Create; //result object
  LContext := TRttiContext.Create; //gets property info
  try
    try
      //initialize a context

      //using the context get the type info
      LType := LContext.GetType(TypeInfo(ASource));

      (*
        for object / interfaces / records we will bundle the properties
        into a sub-object named with either the custom name, or the default
        name of the type.
        1.) if custom name is provided it's used
        2.) if no custom name but an object decorator is on, then that will be used
        3.) lastly, the default name will be used which is type name, minus
            the first character (ie. TObject would shorten to "Object")
      *)
      if LType.TypeKind in [tkObject, tkClass,  tkInterface, tkRecord, tkInterfaceRaw] then
      begin
        //with the type we need to fetch all attributes
        LAttributes := LType.GetAttributes;

        //simple check to bail early
        if Length(LAttributes) < 1 then
          Exit(True);

        //we don't require the json object attribute, but if one is provided
        //we'll use the name associated with it
        LName := '';

        if ACustomName = '' then
        begin
          //find properties and custom name
          for I := 0 to High(LAttributes) do
            if LAttributes[I] is JsonObject then
            begin
              LName := JsonObject(LAttributes[I]).Name;
              Break;
            end;

          //when source wasn't decorated with a name extract it from the classname
          if LName.IsEmpty then
            LName := IfThen<String>(
              not (LType.ClassName = ''), //make sure we have a name
              Copy(LType.ClassName, 2, Length(LType.ClassName) - 1), //either remove T or I
              'unnamed' //otherwise give a default name for the json object
            );
        end
        else
          LName := ACustomName;

        //construct and add the inner object with the name we found
        LInner := TJSONObject.Create;
        LObj.Add(LName, LInner); //handles freeing inner

        //get all the properties this type has
        LProps := LType.GetProperties;

        WriteLn('propCount = ', Length(LProps));

        //iterate properties and only add those that have a property decorator on them
        for I := 0 to High(LProps) do
        begin
          LFound := False;
          LProp := LProps[I];
          LAttributes := LProp.GetAttributes;

          if Length(LAttributes) < 1 then
            Continue;

          //opted in?
          for J := 0 to High(LAttributes) do
            if LAttributes[I] is JsonProperty then
            begin
              LFound := True;
              LPropAttr := JsonProperty(LAttributes[I]);
              Break;
            end;

          //didn't find a json property decorator, move to the next property
          if not LFound or (not LProp.IsReadable) then
            Continue;

          //get the value of this property so we can check for type and handle accordingly
          //LPropVal := LProp.GetValue(@LProp);

          WriteLn(1);
        end;
      end;

      //success
      Result := True;
    except on E : Exception do
      Error := E.Message;
    end;
  finally
    LObj.Free;
    LContext.Free;
  end;
end;

function EZDeserialize<T>(const ASource: String;
  const ADestination: T; out Error: String): Boolean;
begin
  Result := False;
  try
    try
      //todo

    except on E : Exception do
      Error := E.Message;
    end;
  finally
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

