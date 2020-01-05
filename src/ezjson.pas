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
  SysUtils,
  fpjson,
  jsonparser;

type

  { TNamedAttribute }
  (*
    base attribute type for ezjson, offerring shared name property
  *)
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

  {$Region IGNOREME}
  (*
    serializes source and appends to AOutput json object
    note:
      this method was added due to a bug with fpc unable to recurse
      a generic function, but can a procedure.
      https://bugs.freepascal.org/view.php?id=36496

      also it was required to be defined in the type section because
      if only defined in implementation this occurs,
      https://bugs.freepascal.org/view.php?id=21310

      moral of the story... just don't use this method and stick with
      EZSerialize<T>() because hopefully this will go away sometime
  *)
  procedure SerializeObj<T>(const ASource : T; const AOutput : TJSONObject;
    out Success : Boolean; out Error : String; const ACustomName : String = '');
  {$EndRegion}
implementation
uses
  {%H-}Rtti,
  TypInfo;

procedure SerializeObj<T>(const ASource : T; const AOutput : TJSONObject;
  out Success : Boolean; out Error : String; const ACustomName : String = '');
type
  TAttrArray = TArray<TCustomAttribute>;
  TPropArray = TArray<TRttiProperty>;
var
  LInner , LJsonArrItem: TJSONObject;
  LContext: TRttiContext;
  LType : TRttiType;
  LProp : TRttiProperty;
  LAttributes : TAttrArray;
  LFallbackAttr : PAttributeTable;
  LProps : TPropArray;
  I, J, LPropCount: Integer;
  LName,
  LPropName,
  LError : String;
  LFound: Boolean;
  LPropAttr: JsonProperty;
  LPropVal, LArrVal: TValue;
  LJsonArr: TJSONArray;
  LSuccess : Boolean;
  LObjProp : TObject;
  LIntfProp : IInterface;
  LFallbackPropList: PPropList;
  LIntf : IInterface;
  LIntfObj : TInterfacedObject;

  (*
    hacky function that returns an interface reference from a raw pointer.
    this is put in place due to some "quirks" with generic types & interfaces.
    if someone sees a better way to do this... let me know.
  *)
  function GetInterfaceFromT(AInput : Pointer) : IInterface;
  begin
    Result := IInterface(AInput^);
  end;

  (*
    provided a prop info pointer, checks to see if the property is decorated
  *)
  function IsOptedIn(const AInfo : PPropInfo; out Name : String) : Boolean;
  var
    I : Integer;
    LAttr : TAttributeEntry;
  begin
    Result := False;
    Name := '';

    if not Assigned(AInfo) then
      Exit;

    if not Assigned(AInfo^.AttributeTable) or (AInfo^.AttributeTable^.AttributeCount < 1) then
      Exit;

    //simple class name comparison, could probably check type by casting
    //pointer, but this should work fine too and probably a little quicker
    for I := 0 to Pred(AInfo^.AttributeTable^.AttributeCount) do
      if AInfo^.AttributeTable^.AttributesList[I].AttrType^.Name = JsonProperty.ClassName then
      begin
        //get the attribute entry (useful for debug but not necessary)
        LAttr := AInfo^.AttributeTable^.AttributesList[I];

        //call the attribute proc, which returns a custom attribute
        //that we can cast to our json property (confirmed above with classname check)
        Name := JsonProperty(TCustomAttribute(LAttr.AttrProc)).Name;

        //default to the property name when no attribute name defined
        if Name.IsEmpty then
          Name := AInfo^.Name;

        Exit(True);
      end;
  end;

begin
  Success := False;

  LContext := TRttiContext.Create;
  try
    try
      //using the context get the type info
      LType := LContext.GetType(TypeInfo(ASource));

      if not Assigned(LType) then
      begin
        Error := 'SerializeObj::failed to determine type';
        Exit;
      end;

      (*
        for object / interfaces / records we will bundle the properties
        into a sub-object named with either the custom name, or the default
        name of the type.
        1.) if custom name is provided it's used
        2.) if no custom name but an object decorator is on, then that will be used
        3.) lastly, the default name will be used which is type name, minus
            the first character (ie. TObject would shorten to "Object")
      *)
      if LType.TypeKind in [tkObject, tkClass, tkRecord, tkInterface, tkInterfaceRaw] then
      begin
        {$Region object / intf}
        //nil check simply ignores source and returns true
        if not Assigned(ASource) then
        begin
          Success := True;
          Exit;
        end;

        //with the type we need to fetch all attributes
        LAttributes := LType.GetAttributes;

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
              not (LType.Name = ''), //make sure we have a name
              Copy(LType.Name, 2, Length(LType.Name) - 1), //either remove T or I
              'unnamed' //otherwise give a default name for the json object
            );
        end
        else
          LName := ACustomName;

        //for interfaces, we need to get the underlying object and recurse
        if LType.TypeKind in [tkInterfaceRaw, tkInterface] then
        begin
          //get interface reference via trickery (otherwise compiler yells)
          LIntf := GetInterfaceFromT(@ASource);

          //with the interface reference we get a tobject reference and recurse
          if not Supports(LIntf, TInterfacedObject, LIntfObj) then
            raise Exception.Create('SerializeObj::interface type cannot be serialized');

          //recurse with object reference
          SerializeObj<TInterfacedObject>(
            LIntfObj, //interface -> object
            AOutput,
            Success,
            Error,
            LName
          );

          //we're done here
          Exit;
        end;

        //construct and add the inner object with the name we found
        LInner := TJSONObject.Create;
        AOutput.Add(LName, LInner); //handles freeing inner

        //get all the properties this type has
        LProps := LType.GetProperties;

        (*
          sorry this is ugly, but while writing this, rtti is experimental,
          but I prefer to use it since it *should* be the most delphi like, therefore
          we have a fallback to typinfo method when the property count can't be determined
          from the rtti unit
        *)
        if Length(LProps) > 0 then
        begin
          {$Region RTTI}
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
              if LAttributes[J] is JsonProperty then
              begin
                LFound := True;
                LPropAttr := JsonProperty(LAttributes[J]);
                Break;
              end;

            //didn't find a json property decorator, move to the next property
            if not LFound or (not LProp.IsReadable) then
              Continue;

            //get the value of this property so we can check for type and handle accordingly
            LPropVal := LProp.GetValue(ASource);

            //write boolean type
            if LProp.PropertyType.TypeKind = tkBool then
              LInner.Add(LPropAttr.Name, LPropVal.AsBoolean)
            //handle all string types the same
            else if LProp.PropertyType.TypeKind in [tkString, tkAString, tkChar, tkLString, tkUChar, tkUString, tkVariant] then
              LInner.Add(LPropAttr.Name, LPropVal.AsString)
            //write int types
            else if LProp.PropertyType.TypeKind in [tkInteger, tkInt64] then
              LInner.Add(LPropAttr.Name, LPropVal.AsInt64)
            //handle floating types different than ints
            else if LProp.PropertyType.TypeKind in [tkFloat] then
              LInner.Add(LPropAttr.Name, LPropVal.AsExtended)
            //special logic for object / interface types
            else if LProp.PropertyType.TypeKind in [tkClass, tkObject, tkInterface, tkInterfaceRaw, tkRecord] then
            begin
              //special checks to find collection types
              //todo...


              //otherwise recurse
              if LProp.PropertyType.TypeKind = tkClass then
              begin
                //this code is here because LPropVal.AsObject is nil as of writing
                LObjProp := GetObjectProp(
                  {%H-}TObject(ASource),
                  PPropInfo(LProp.Handle)
                );

                SerializeObj<TObject>(
                  LObjProp, //LPropVal.AsObject,
                  LInner,
                  LSuccess,
                  LError,
                  LPropAttr.Name
                );

                if not LSuccess then
                  Exit;
              end
              else if LProp.PropertyType.TypeKind in [tkInterface, tkInterfaceRaw] then
              begin
                LIntfProp := GetInterfaceProp(
                  {%H-}TObject(ASource),
                  PPropInfo(LProp.Handle)
                );

                SerializeObj<IInterface>(
                  LIntfProp, //LPropVal.AsInterface,
                  LInner,
                  LSuccess,
                  LError,
                  LPropAttr.Name
                );

                if not LSuccess then
                  Exit;
              end
              else
                raise Exception.Create('unable to serialize [' + LPropAttr.Name + ']');;
            end
            //for array types we need iterate and serialize each value
            else if LProp.PropertyType.TypeKind in [tkArray] then
            begin
              (*
                below we can probably consolidate some of this code with the stuff
                above so we can share a little bit, but I wanted to make sure
                this was working first...
              *)

              //handle empty arrays
              if LPropVal.GetArrayLength < 1 then
                LInner.Add(LPropAttr.Name, TJSONArray.Create)
              else
              begin
                //initialize a json array to store items
                LJsonArr := TJSONArray.Create;
                LInner.Add(LPropAttr.Name, LJsonArr);

                //iterate the array
                for J := 0 to Pred(LPropVal.GetArrayLength) do
                begin
                  LArrVal := LPropVal.GetArrayElement(J);

                  if LArrVal.Kind = tkBool then
                    LJsonArr.Add(LArrVal.AsBoolean)
                  //handle all string types the same
                  else if LArrVal.Kind in [tkString, tkAString, tkChar, tkLString, tkUChar, tkUString, tkVariant] then
                    LJsonArr.Add(LArrVal.AsString)
                  //write int types
                  else if LArrVal.Kind in [tkInteger, tkInt64] then
                    LJsonArr.Add(LArrVal.AsInt64)
                  //handle floating types different than ints
                  else if LArrVal.Kind in [tkFloat] then
                    LJsonArr.Add(LArrVal.AsExtended)
                  //for object / interface types recurse
                  else if LArrVal.Kind in [tkClass, tkObject, tkInterface, tkInterfaceRaw, tkRecord] then
                  begin
                    //for arrays that contain objects or interfaces we can
                    //recurse to serialize. to my knowledge, records are not going
                    //work here, so those will result in an error being thrown
                    LJsonArrItem := TJSONObject.Create;
                    LJsonArr.Add(LJsonArrItem);

                    if LArrVal.Kind = tkClass then
                    begin
                      SerializeObj<TObject>(
                        LArrVal.AsObject,
                        LJsonArrItem,
                        LSuccess,
                        LError
                      );

                      if not LSuccess then
                        Exit;
                    end
                    else if LArrVal.Kind in [tkInterface, tkInterfaceRaw] then
                    begin
                      SerializeObj<IInterface>(
                        LArrVal.AsInterface,
                        LJsonArrItem,
                        LSuccess,
                        LError
                      );

                      if not LSuccess then
                        Exit;
                    end
                    else
                      raise Exception.Create('unable to serialize [' + LPropAttr.Name + ']');
                  end;
                end;
              end;
            end;
          end;
          {$EndRegion}
        end
        (*
          fallback method attempts to gather properties using the typinfo
          methods
        *)
        else
        begin
          {$Region typinfo fallback}
          if LType.TypeKind = tkClass then
          begin
            LPropCount := GetPropList({%H-}TObject(ASource), LFallbackPropList);

            //for opted in properties we need to add them to the inner object
            for I := 0 to Pred(LPropCount) do
            begin
              if not IsOptedIn(LFallbackPropList^[I], LName) then
                Continue;

              case LFallbackPropList^[I].PropType^.Kind of
                //handle simple types
                tkBool:
                  LInner.Add(LName, TJSONBoolean.Create(GetPropValue({%H-}TObject(ASource), LFallbackPropList^[I])));
                tkString, tkAString, tkChar, tkLString, tkUChar, tkUString, tkVariant:
                  LInner.Add(LName, TJSONString.Create(GetPropValue({%H-}TObject(ASource), LFallbackPropList^[I])));
                tkInteger, tkInt64:
                  LInner.Add(LName, Integer(GetPropValue({%H-}TObject(ASource), LFallbackPropList^[I])));
                tkFloat:
                  LInner.Add(LName, Extended(GetPropValue({%H-}TObject(ASource), LFallbackPropList^[I])));
                //handle complex types
                tkClass:
                  begin
                    LObjProp := GetObjectProp(
                      {%H-}TObject(ASource),
                      LFallbackPropList^[I]
                    );

                    SerializeObj<TObject>(
                      LObjProp, //LPropVal.AsObject,
                      LInner,
                      LSuccess,
                      LError,
                      LPropAttr.Name
                    );

                    if not LSuccess then
                      Exit;
                  end;
                tkInterface, tkInterfaceRaw:
                  begin
                    LIntfProp := GetInterfaceProp(
                      {%H-}TObject(ASource),
                      LFallbackPropList^[I]
                    );

                    SerializeObj<IInterface>(
                      LIntfProp, //LPropVal.AsInterface,
                      LInner,
                      LSuccess,
                      LError,
                      LPropAttr.Name
                    );

                    if not LSuccess then
                      Exit;
                  end;
                else
                  raise Exception.Create('unable to serialize [' + LName + ']');
              end;
            end;
          end
          else if LType.TypeKind in [tkInterface, tkInterfaceRaw] then
          begin

            //get interface reference via trickery (otherwise compiler yells)
            LIntf := GetInterfaceFromT(@ASource);

            //with the interface reference we get a tobject reference and recurse
            if not Supports(LIntf, TInterfacedObject, LIntfObj) then
              raise Exception.Create('SerializeObj::interface type cannot be serialized');

            //recurse with object reference
            SerializeObj<TInterfacedObject>(
              LIntfObj, //interface -> object
              LInner, //use inner here since we are gathering props
              LSuccess,
              LError
            );

            if not LSuccess then
              raise Exception.Create('SerializeObject::' + LError);
          end
          else
            raise Exception.Create('SerializeObj::other types not implemented');
          {$EndRegion}
        end;
        {$EndRegion}
      end
      else
        raise Exception.Create('SerializeObj::other types not implemented');

      //yay
      Success := True;
    except on E : Exception do
      Error := E.Message;
    end;
  finally
    LContext.Free;
  end;
end;

function EZSerialize<T>(const ASource: T; out
  JSON: String; out Error: String; const ACustomName: String): Boolean;
var
  LObj : TJSONObject;
begin
  Result := False;
  JSON := '{}';

  //create result object
  LObj := TJSONObject.Create;
  try
    try
      //serialize source to dest object
      SerializeObj<T>(
        ASource,
        LObj,
        Result,
        Error,
        ACustomName
      );

      //write the json
      JSON := LObj.AsJSON;

      //success
      Result := True;
    except on E : Exception do
      Error := E.Message;
    end;
  finally
    LObj.Free;
  end;
end;

function EZDeserialize<T>(const ASource: String;
  const ADestination: T; out Error: String): Boolean;
type
  TAttrArray = TArray<TCustomAttribute>;
  TPropArray = TArray<TRttiProperty>;
var
  LData , LJsonProp: TJSONData;
  LObj : TJSONObject;
  LContext: TRttiContext;
  LType : TRttiType;
  LIntf : IInterface;
  LintfObj : TInterfacedObject;
  I : Integer;

  //same as serialize, need to trick compiler to get interface
  function GetInterfaceFromT(AInput : Pointer) : IInterface;
  begin
    Result := IInterface(AInput^);
  end;

  (*
    given a property name and an object, will try to find a matching opted-in
    property, then set the value accordingly
  *)
  function SetProperty(const AProperty: String; const AObj : TObject;
    const AValue : Variant; const AType : TJSONtype) : Boolean;
  var
    LContext : TRttiContext;
    LType : TRttiType;
    LAttributes : TAttrArray;
    LProp : TRttiProperty;
    LProps : TPropArray;
    LPropInfo : PPropInfo;
    I, J : Integer;
    LFound : Boolean;
    LError : String;
    LTypAttributes : PAttributeTable;
  begin
    Result := False;
    LContext := TRttiContext.Create;
    try
      //get the type so we can fetch attributes / properties
      LType := LContext.GetType(TypeInfo(AObj));
      LAttributes := LType.GetAttributes;

      //special case is that since we serialize objects inside of an
      //inner "wrapper" object, then we need to check that
      if AType = jtObject then
      begin
        //see if the "property" is the object we're working with
        if Pos(AProperty.ToLower, LowerCase(AObj.ClassName)) > 0 then
        begin
          if EZDeserialize<TObject>(
            TJSONObject({%H-}Pointer(PtrInt(AValue))^).AsJSON,
            AObj,
            LError
          ) then
            Exit(True)
          else
            Exit;
        end
        //lastly check to make sure we don't have a jsonobject attribute with this name
        //if so we can bail early by recursing
        else
        begin
          //rtti unit approach first since most delphi like
          if Length(LAttributes) > 0 then
          begin
            for I := 0 to High(LAttributes) do
              if LAttributes[I] is JsonObject then
                if JsonObject(LAttributes[I]).Name.ToLower = AProperty.ToLower then
                begin
                  if EZDeserialize<TObject>(
                    TJSONObject({%H-}Pointer(PtrInt(AValue))^).AsJSON,
                    AObj,
                    LError
                  ) then
                    Exit(True)
                  else
                    Exit;
                end;
          end
          //fallback typinfo approach in case rtti unit doesn't report
          //any attributes (as of writing, this is the case)
          else
          begin
            LTypAttributes := GetAttributeTable(TypeInfo(AObj));

            if Assigned(LTypAttributes) or (LTypAttributes^.AttributeCount < 1) then
            begin
              for I := 0 to Pred(LTypAttributes^.AttributeCount) do
              begin
                //get the property info
                LPropInfo := GetPropInfo(LTypAttributes^.AttributesList[I].AttrType, LTypAttributes^.AttributesList[I].AttrType^.Name);

                //with the propinfo we can...
                //todo...
              end;
            end;
          end;
        end;
      end;

      //otherwise, this is a normal property that needs to be set, so fetch
      //the properties from the type
      LProps := LType.GetProperties;
      LFound := False;

      //iterate to find a match, and try to set if found
      for I := 0 to High(LProps) do
      begin
        LAttributes := LProps[I].GetAttributes;

        //no attributes, no dice
        if Length(LAttributes) < 1 then
          Continue;

        //see if we can find the property attribute (opted-in)
        for J := 0 to High(LAttributes) do
          if LAttributes[J] is JsonProperty then
            if JsonProperty(LAttributes[J]).Name.ToLower = AProperty.ToLower then
            begin
              LProp := LProps[I];
              LFound := True;
              Break;
            end;

        //for now we'll operate under the assumption that "extra" properties
        //can exist in the source json, and not on our object representations.
        //this may change in the future, but seems like a safe bet
        if not LFound then
          Continue;

        //now that we've made all the checks, we can attempt to set the value
        case AType of
          //simple types we can just use the variant version of set prop
          jtBoolean, jtNumber, jtString:
            begin
              SetPropValue(AObj, LProp.Name, AValue);
              Break;
            end;
          //todo object types...
          jtObject:
            begin
            end;
          //otherwise, we cannot handle this case
          else
            Exit;
        end;
      end;


      //success
      Result := True;
    finally
      LContext.Free;
    end;
  end;

begin
  Result := False;

  //check to see if we have valid json
  LData := GetJSON(ASource);
  if not Assigned(LData) then
  begin
    Error := 'EZDeserialize::invalid source json';
    Exit;
  end;

  //input needs to be a json object for us to deserialize
  if not (LData is TJSONObject) then
  begin
    Error := 'EZDeserialize::json is not an object';
    LData.Free;
    Exit;
  end;

  //cast to object to make things easier to work with
  LObj := TJSONObject(LData);
  LContext := TRttiContext.Create;
  try
    try
      //we can't deserialize if the input source has no properties, but
      //in this case don't fail, just bail early
      if LObj.Count < 1 then
        Exit(True);

      //using the context get the type info
      LType := LContext.GetType(TypeInfo(ADestination));

      if not Assigned(LType) then
      begin
        Error := 'EZDeserialize::failed to determine type';
        Exit;
      end;

      //we need to ensure input is either an object / record / interface
      if LType.TypeKind in [tkClass, tkObject, tkRecord] then
      begin
        //iterate json object's properties
        for I := 0 to Pred(LObj.Count) do
        begin
          LJsonProp := LObj.Items[I];

          //depending on the type of property handle things differently
          case LJsonProp.JSONType of
            //simple types can be passed through just like they are
            jtBoolean, jtNumber, jtString:
              begin
                if not SetProperty(
                  LObj.Names[I],
                  TObject(ADestination),
                  LJsonProp.Value,
                  LJsonProp.JSONType
                ) then
                  raise Exception.Create('EZDeserialize::unable to deserialize ' + LObj.Names[I]);
              end;
            //for object types we need to just pass the entire
            jtObject:
              begin
                if not SetProperty(
                  LObj.Names[I],
                  TObject(ADestination),
                  {%H-}PtrInt(@LJsonProp), //cast to pointer
                  LJsonProp.JSONType //is json object
                ) then
                  raise Exception.Create('EZDeserialize::unable to deserialize ' + LObj.Names[I]);
              end;
            //move on for nulls
            jtNull:
              Continue;
            else
              raise Exception.Create('EZDeserialize::invalid json property');
          end;
        end;
      end
      //for interface we need get the underlying object and recurse
      else if LType.TypeKind in [tkInterface, tkInterfaceRaw] then
      begin
        LIntf := GetInterfaceFromT(@ASource);

        //with the interface reference we get a tobject reference and recurse
        if not Supports(LIntf, TInterfacedObject, LIntfObj) then
          raise Exception.Create('EZDeserialize::interface type cannot be serialized');

        //recurse with object reference
        Result := EZDeserialize<TInterfacedObject>(
          ASource, //results in a second parse... but that's ok for now
          LIntfObj, //interface -> object
          Error
        );

        Exit;
      end
      //unable to deserialize with this type
      else
        raise Exception.Create('EZDeserialize::invalid destination');

      //success
      Result := True;
    except on E : Exception do
      Error := E.Message;
    end;
  finally
    LData.Free;
    LContext.Free;
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

