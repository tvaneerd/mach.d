module mach.text.json.serialize;

private:

import mach.meta : Aliases;
import mach.traits : isIntegral, isFloatingPoint, isCharacter, isString;
import mach.traits : isBoolean, isArray, isStaticArray, isAssociativeArray;
import mach.traits : ArrayElementType, ArrayKeyType, ArrayValueType;
import mach.traits : isClass, isPointer, Unqual, isCharString, isDString;
import mach.traits : isEnumType, getenummember, enummembername, NoSuchEnumMemberException;
import mach.traits : hasAttribute;
import mach.range : map, asarray;
import mach.text.utf : utf8encode, utfdecode;
import mach.text.parse.numeric : parseint, writeint, parsefloat, writefloat;

import mach.text.json.attributes;
import mach.text.json.exceptions;
import mach.text.json.parse;
import mach.text.json.value;

public:



private enum DefaultMaxDepth = 32;



/// Get a json object from an arbitrary input.
/// Should just magically work for all primitives, for most associative arrays
/// (depends on the key type), and for the simpler user-defined structs and
/// classes.
/// To define a serialization method for structs and classes where the auto-
/// magical serialization isn't handling it correctly, implement a `tojson`
/// method returning a `JsonValue` object.
/// Automagical serialization will not work for types containing pointers.
/// The `maxdepth` argument is primarily intended to guard against cyclic
/// references; depth is incremented when serializing a class.
JsonValue jsonserialize(size_t maxdepth = DefaultMaxDepth, T)(
    auto ref T value, in size_t depth = 0
){
    static if(isPointer!T){
        static assert(false, "Cannot serialize types with indirection.");
    }else static if(is(T == typeof(null))){
        return JsonValue(null);
    }else static if(isBoolean!T){
        return jsonserializeboolean(value);
    }else static if(isIntegral!T || isFloatingPoint!T){
        return jsonserializenumber(value);
    }else static if(isCharacter!T){
        return jsonserializecharacter(value);
    }else static if(isString!T){
        return jsonserializestring(value);
    }else static if(isArray!T){
        return jsonserializearray!maxdepth(value, depth);
    }else static if(isAssociativeArray!T){
        return jsonserializearray!maxdepth(value, depth);
    }else static if(isEnumType!T){
        return jsonserializeenum(value);
    }else static if(is(typeof({JsonValue v = value.tojson;}))){
        return value.tojson;
    }else{
        return jsonserializetype!maxdepth(value, depth);
    }
}



/// Get a value of the given type from a json object.
T jsondeserialize(T)(in JsonValue value){
    static if(isPointer!T){
        static assert(false, "Cannot deserialize types with indirection.");
    }else static if(isBoolean!T){
        return jsondeserializeboolean!T(value);
    }else static if(isIntegral!T || isFloatingPoint!T){
        return jsondeserializenumber!T(value);
    }else static if(isCharacter!T){
        return jsondeserializecharacter!T(value);
    }else static if(isStaticArray!T){
        return jsondeserializestaticarrayof!(ArrayElementType!T, T.length)(value);
    }else static if(isString!T){
        return jsondeserializestring!T(value);
    }else static if(isArray!T){
        return jsondeserializearrayof!(ArrayElementType!T)(value);
    }else static if(isAssociativeArray!T){
        return jsondeserializearrayof!(ArrayKeyType!T, ArrayValueType!T)(value);
    }else static if(isString!T){
        return jsondeserializestring!T(value);
    }else static if(isEnumType!T){
        return jsondeserializeenum!T(value);
    }else static if(is(typeof({JsonValue v = value.fromjson;}))){
        return value.fromjson;
    }else{
        return jsondeserializetype!T(value);
    }
}



/// Get a json object from an arbitrary user-defined struct or class.
auto jsonserializetype(size_t maxdepth = DefaultMaxDepth, T)(
    auto ref T value, in size_t depth = 0
){
    static if(isClass!T){
        if(value is null) return JsonValue(null);
    }
    if(depth > maxdepth) throw new JsonSerializationDepthException();
    JsonValue obj = JsonValue(JsonValue.Type.Object);
    foreach(index, Type; typeof(T.tupleof)){
        enum name = __traits(identifier, T.tupleof[index]);
        static if(!hasAttribute!(JsonSerializeSkip, T.tupleof[index])){
            obj[name] = jsonserialize!maxdepth(
                value.tupleof[index], depth + isClass!T
            );
        }
    }
    return obj;
}

/// Get an arbitrary user-defined struct or class from a json object.
auto jsondeserializetype(T)(in JsonValue value){
    static if(isClass!T){
        if(value.type is JsonValue.Type.Null) return cast(T) null;
    }
    Unqual!T makenew(){
        static if(isClass!T){
            static assert(is(typeof({new Unqual!T;})),
                "Cannot deserialize class unless it has a constructor " ~
                "accepting no arguments."
            );
            auto result = new Unqual!T;
        }else{
            Unqual!T result;
        }
        return result;
    }
    if(value.type is JsonValue.Type.Object){
        // Ideal case: Object with fields with names and types
        // corresponding to those of the desired type.
        auto result = makenew();
        foreach(index, Type; typeof(T.tupleof)){
            enum name = __traits(identifier, T.tupleof[index]);
            if(name in value){
                result.tupleof[index] = jsondeserialize!Type(value[name]);
            }
        }
        return cast(T) result;
    }else if(value.type is JsonValue.Type.Array){
        // Acceptable case: Array with elements corresponding to
        // fields of the desired type.
        auto result = makenew();
        size_t jsonindex = 0;
        foreach(index, Type; typeof(T.tupleof)){
            enum name = __traits(identifier, T.tupleof[index]);
            if(jsonindex < value.length){
                result.tupleof[index] = jsondeserialize!Type(value[jsonindex++]);
            }else{
                break;
            }
        }
        return cast(T) result;
    }else{
        auto make(Args...)(Args args){
            static if(isClass!T) return new T(args);
            else return T(args);
        }
        // Finally: Try constructing the desired type with primitives.
        static if(is(typeof(make("")))){
            if(value.type is JsonValue.Type.String) return make(value.store.stringval);
        }
        static if(is(typeof(make(""d)))){
            if(value.type is JsonValue.Type.String){
                return make(cast(dstring) value.store.stringval.utfdecode.asarray);
            }
        }
        foreach(Float; Aliases!(double, real, float)){
            static if(is(typeof({Float f; make(f);}))){
                if(value.type is JsonValue.Type.Integer){
                    return make(cast(Float) value.store.integerval);
                }else if(value.type is JsonValue.Type.Float){
                    return make(cast(Float) value.store.floatval);
                }
            }
        }
        foreach(Int; Aliases!(
            long, int, short, byte, ulong, uint, ushort, ubyte, dchar, char
        )){
            static if(is(typeof({Int i; make(i);}))){
                if(value.type is JsonValue.Type.Integer){
                    return make(cast(Int) value.store.integerval);
                }
            }
        }
        throw new JsonDeserializationTypeException();
    }
}



/// Get a json object from an enum member.
auto jsonserializeenum(T)(T value) if(isEnumType!T){
    return JsonValue(enummembername(value));
}

/// Get an enum member from a json object.
auto jsondeserializeenum(T)(in JsonValue value){
    if(value.type is JsonValue.Type.String){
        try{
            return getenummember!T(value.store.stringval);
        }catch(NoSuchEnumMemberException!T e){
            throw new JsonDeserializationValueException("enum member", e);
        }
    }else{
        throw new JsonDeserializationTypeException("enum member");
    }
}



/// Get a json object from a boolean primitive.
auto jsonserializeboolean(T)(T boolean) if(isBoolean!T){
    return JsonValue(boolean);
}

/// Get a boolean primitive from a json object.
auto jsondeserializeboolean(T = bool)(in JsonValue value) if(isBoolean!T){
    if(value.type is JsonValue.Type.Boolean){
        return value.store.booleanval;
    }else if(value.type is JsonValue.Type.Null){
        return cast(T) false;
    }else if(value.type is JsonValue.Type.Integer){
        return cast(T)(value.store.integerval != 0);
    }else{
        throw new JsonDeserializationTypeException("boolean");
    }
}



/// Get a json object from a numeric primitive.
auto jsonserializenumber(T)(T number) if(isIntegral!T || isFloatingPoint!T){
    return JsonValue(number);
}

/// Get a numeric primitive from a json object.
auto jsondeserializenumber(T)(in JsonValue value) if(isIntegral!T || isFloatingPoint!T){
    if(value.type is JsonValue.Type.Integer){
        return cast(T) value.store.integerval;
    }else if(value.type is JsonValue.Type.Float){
        return cast(T) value.store.floatval;
    // TODO: Actually implement parsefloat
    //}else if(value.type is JsonValue.Type.String){
    //    static if(isIntegral!T) return value.store.stringval.parseint!T;
    //    else return cast(T)(value.store.stringval.parsefloat);
    }
    static if(isFloatingPoint!T){
        if(value.type is JsonValue.Type.Null){
            return T.nan;
        }
    }
    throw new JsonDeserializationTypeException("number");
}



/// Get a json object from a character.
/// TODO: Support wchars (here and elsewhere in the module)
auto jsonserializecharacter(T)(T value) if(isCharacter!T){
    static if(is(T : char)){
        return JsonValue(cast(string)[value]);
    }else static if(is(T : dchar)){
        return JsonValue(value.utf8encode.toString);
    }else{
        assert(false,
            "Unable to serialize character of type " ~ T.stringof ~ "."
        );
    }
}

/// Get a string literal from a json object.
auto jsondeserializecharacter(T)(in JsonValue value) if(isCharacter!T){
    if(value.type is JsonValue.Type.String){
        static if(is(T : char)){
            if(value.store.stringval.length != 1){
                throw new JsonDeserializationValueException("character");
            }
            return cast(T) value.store.stringval[0];
        }else static if(is(T : dchar)){
            auto dstr = value.store.stringval.utfdecode.asarray;
            if(dstr.length != 1){
                throw new JsonDeserializationValueException("character");
            }
            return cast(T) dstr[0];
        }else{
            // TODO: Work with wchar
            assert(false,
                "Unable to deserialize character of type " ~ T.stringof ~ "."
            );
        }
    }else if(value.type is JsonValue.Type.Integer){
        return cast(T) value.store.integerval;
    }else{
        throw new JsonDeserializationTypeException("character");
    }
}



/// Get a json object from a string literal.
/// TODO: Support wstrings (here and elsewhere in the module)
auto jsonserializestring(T)(T str) if(isString!T){
    static if(isCharString!T){
        return JsonValue(str);
    }else static if(isDString!T){
        return JsonValue(cast(string) str.utf8encode.asarray);
    }else{
        static assert(false,
            "Unable to serialize string literal of type " ~ T.stringof ~ "."
        );
    }
}

/// Get a string literal from a json object.
auto jsondeserializestring(T)(in JsonValue value) if(isString!T){
    if(value.type is JsonValue.Type.String){
        static if(is(T : string)){
            return cast(T) value.store.stringval;
        }else static if(is(T : dstring)){
            return cast(T) value.store.stringval.utfdecode.asarray;
        }else{
            // TODO: Support wstring
            assert(false,
                "Unable to deserialize string literal of type " ~ T.stringof ~ "."
            );
        }
    }else{
        throw new JsonDeserializationTypeException("string");
    }
}



/// Get a json object from an array.
auto jsonserializearray(size_t maxdepth = DefaultMaxDepth, T)(
    T[] array, in size_t depth = 0
){
    return JsonValue(array.map!(e => jsonserialize!maxdepth(e, depth)).asarray);
}

/// Get an array of a particular type from a json object.
auto jsondeserializearrayof(T)(in JsonValue value){
    if(value.type is JsonValue.Type.Array){
        return value.store.arrayval.map!(e => jsondeserialize!T(e)).asarray;
    }else if(value.type is JsonValue.Type.String){
        static if(is(T : char)){
            return cast(T[]) value.store.stringval;
        }else static if(is(T : dchar)){
            return cast(T[]) value.store.stringval.utfdecode.asarray;
        }
    }
    throw new JsonDeserializationTypeException("array");
}

/// ditto
auto jsondeserializestaticarrayof(T, size_t size)(in JsonValue value){
    if(value.type is JsonValue.Type.Array){
        if(value.length != size){
            throw new JsonDeserializationValueException("static array");
        }
        T[size] result;
        for(size_t i = 0; i < size; i++){
            result[i] = value.store.arrayval[i].jsondeserialize!T;
        }
        return result;
    }
    throw new JsonDeserializationTypeException("static array");
}



/// Get a json object from an assocative array.
/// TODO: There should really be a general way to determine if a type can be
/// mapped to a unique string and parsed back exactly, since that's pretty
/// much the requirement for usage as a key in an associative array here.
auto jsonserializearray(size_t maxdepth = DefaultMaxDepth, K, V)(
    V[K] array, in size_t depth = 0
){
    alias UK = Unqual!K;
    static if(is(UK == string)){
        alias tokey = k => k;
    }else static if(is(UK == dstring)){
        alias tokey = k => k.utf8encode;
    }else static if(is(UK == char)){
        alias tokey = k => cast(string)[k];
    }else static if(is(UK == dchar)){
        alias tokey = k => k.utf8encode.toString();
    }else static if(isIntegral!K){
        alias tokey = k => k.writeint;
    }else static if(isFloatingPoint!K){
        alias tokey = k => k.writefloat;
    }else static if(isEnumType!K){
        alias tokey = k => k.enummembername;
    }else{
        static assert(false,
            "Unable to serialize associative array with key type " ~ K.stringof ~ "."
        );
    }
    auto serialized = JsonValue(JsonValue.Type.Object);
    foreach(key, value; array){
        serialized[tokey(key)] = jsonserialize!maxdepth(value, depth);
    }
    return serialized;
}

/// Get an associative array of a particular type from a json object.
auto jsondeserializearrayof(K, V)(in JsonValue value){
    if(value.type !is JsonValue.Type.Object){
        throw new JsonDeserializationTypeException("associative array");
    }
    alias UK = Unqual!K;
    static if(is(UK == string)){
        alias tokey = k => k;
    }else static if(is(UK == dstring)){
        alias tokey = k => k.utfdecode.asarray;
    }else static if(is(UK == char)){
        alias tokey = (k){
            if(k.length != 1) throw new JsonDeserializationValueException("character");
            return k[0];
        };
    }else static if(is(UK == dchar)){
        alias tokey = (k){
            auto str = k.utfdecode.asarray;
            if(str.length != 1) throw new JsonDeserializationValueException("character");
            return str[0];
        };
    }else static if(isIntegral!K){
        alias tokey = k => k.parseint!K;
    // TODO: make parsefloat work
    //}else static if(isFloatingPoint!K){
    //    alias tokey = k => k.parsefloat;
    }else static if(isEnumType!K){
        alias tokey = (k){
            try{
                return getenummember!K(k);
            }catch(NoSuchEnumMemberException!K e){
                throw new JsonDeserializationValueException("enum member", e);
            }
        };
    }else{
        static assert(false,
            "Unable to deserialize associative array with key type " ~ K.stringof ~ "."
        );
    }
    V[K] deserialized;
    foreach(key, value; value.store.objectval){
        deserialized[tokey(key)] = jsondeserialize!V(value);
    }
    return deserialized;
}



version(unittest){
    private:
    import mach.test;
    
    enum TestEnum{First, Second, Third}
    
    struct EmptyStruct{}
    class EmptyClass{}
    struct IntsTest{int x, y, z;}
    struct WithEnumTest{TestEnum x;}
    class ClassTest{
        int x, y, z;
        this(){}
        this(int x, int y, int z){this.x = x; this.y = y; this.z = z;}
    }
    struct MixedTest{
        int x, y;
        double f = 0;
        string str;
        dstring dstr;
        int[] dints;
        int[4] sints;
        string[string] aa;
        TestEnum e;
    }
    class NestSuccessTest{
        int x, y;
        IntsTest ints;
        WithEnumTest withenum;
        MixedTest mixed;
        override bool opEquals(Object o){
            auto t = cast(NestSuccessTest) o;
            return(
                this.x == t.x && this.y == t.y && this.ints == t.ints &&
                this.withenum == t.withenum && this.mixed == t.mixed
            );
        }
    }
    class NestFailureTest{
        NestFailureTest nest;
    }
    struct CustomTest{
        int x;
        JsonValue tojson() const{return JsonValue(this.x);}
        typeof(this) fromjson(in JsonValue value){
            assert(value.type is JsonValue.Type.Integer);
            return CustomTest(cast(int) value);
        }
    }
    struct SkipTest{
        int x;
        @JsonSerializeSkip() int y;
    }
}
unittest{
    tests("Json serialization", {
        tests("Primitives", {
            tests("Booleans", {
                auto s = bool(true).jsonserialize;
                testis(s.type, JsonValue.Type.Boolean);
                auto b = s.jsondeserialize!bool;
                testeq(b, true);
                testeq(JsonValue(0).jsondeserialize!bool, false);
                testeq(JsonValue(1).jsondeserialize!bool, true);
                testeq(JsonValue(-1).jsondeserialize!bool, true);
            });
            tests("Integers", {
                foreach(T; Aliases!(long, int, short, byte, ulong, uint, ushort, ubyte)){
                    auto n = T(0);
                    auto s = n.jsonserialize;
                    testis(s.type, JsonValue.Type.Integer);
                    auto i = s.jsondeserialize!T;
                    testeq(i, 0);
                }
            });
            tests("Floats", {
                foreach(T; Aliases!(double, float, real)){
                    auto n = T(1.25);
                    auto s = n.jsonserialize;
                    testis(s.type, JsonValue.Type.Float);
                    auto i = s.jsondeserialize!T;
                    testeq(i, 1.25);
                }
            });
            tests("Characters", {
                foreach(T; Aliases!(char, dchar)){
                    auto s = T('x').jsonserialize;
                    testis(s.type, JsonValue.Type.String);
                    testeq(s.store.stringval, "x");
                    auto i = s.jsondeserialize!T;
                    testeq(i, 'x');
                    testeq(JsonValue(cast(uint) 'x').jsondeserialize!T, 'x');
                }
                testeq('ツ'.jsonserialize.jsondeserialize!dchar, 'ツ');
            });
            tests("Strings", {
                {
                    auto s = "hello".jsonserialize;
                    testis(s.type, JsonValue.Type.String);
                    string str = s.jsondeserialize!string;
                    testeq(str, "hello");
                }{
                    testeq("".jsonserialize.jsondeserialize!string, "");
                    testeq("x".jsonserialize.jsondeserialize!string, "x");
                }{
                    auto s = "hello"d.jsonserialize;
                    testis(s.type, JsonValue.Type.String);
                    dstring str = s.jsondeserialize!dstring;
                    testeq(str, "hello"d);
                }{
                    testeq(""d.jsonserialize.jsondeserialize!dstring, ""d);
                    testeq("x"d.jsonserialize.jsondeserialize!dstring, "x"d);
                    testeq("!אツ😃"d.jsonserialize.jsondeserialize!dstring, "!אツ😃"d);
                }
            });
            tests("Arrays", {
                foreach(array; [[], [0], [0, 1, 2]]){
                    auto s = array.jsonserialize;
                    testis(s.type, JsonValue.Type.Array);
                    testeq(s.length, array.length);
                    int[] d = s.jsondeserialize!(int[]);
                    testeq(d, array);
                }
                foreach(array; [[], ["hi"], ["hello", "world"]]){
                    auto s = array.jsonserialize;
                    testis(s.type, JsonValue.Type.Array);
                    testeq(s.length, array.length);
                    string[] d = s.jsondeserialize!(string[]);
                    testeq(d, array);
                }
                {
                    int[4] array = [0, 1, 2, 3];
                    auto s = array.jsonserialize;
                    testis(s.type, JsonValue.Type.Array);
                    testeq(s.length, array.length);
                    int[4] d = s.jsondeserialize!(int[4]);
                    testeq(d, array);
                }
            });
            tests("Associative arrays", {
                // TODO: More thoroughly test different key types
                tests("String keys", {
                    string[string] emptyaa;
                    foreach(array; [emptyaa, ["a": "apple"], ["x": "x", "y": "y", "z": "z"]]){
                        auto s = array.jsonserialize;
                        testis(s.type, JsonValue.Type.Object);
                        testeq(s.length, array.length);
                        string[string] d = s.jsondeserialize!(string[string]);
                        testeq(d, array);
                    }
                });
                tests("Integer keys", {
                    int[int] emptyaa;
                    foreach(array; [emptyaa, [0:0], [0:1, 2:3, 4:5]]){
                        auto s = array.jsonserialize;
                        testis(s.type, JsonValue.Type.Object);
                        testeq(s.length, array.length);
                        int[int] d = s.jsondeserialize!(int[int]);
                        testeq(d, array);
                    }
                });
            });
            tests("Enums", {
                enum Enum{First, Second, Third}
                testeq(Enum.First.jsonserialize.jsondeserialize!Enum, Enum.First);
                testeq(Enum.Second.jsonserialize.jsondeserialize!Enum, Enum.Second);
                testeq(Enum.Third.jsonserialize.jsondeserialize!Enum, Enum.Third);
                testfail({JsonValue("NonExistent").jsondeserialize!Enum;});
            });
        });
        tests("Empty type", {
            EmptyStruct x;
            EmptyStruct y = x.jsonserialize.jsondeserialize!EmptyStruct;
            EmptyClass z;
            EmptyClass w = z.jsonserialize.jsondeserialize!EmptyClass;
        });
        tests("Structs", {
            MixedTest mixed1 = {
                x: 10, y: 11, f: 2.5,
                str: "hi", dstr: "hello"d,
                dints: [0, 1], sints: [0, 1, 2, 3],
                aa: ["x": "y", "z": "w"],
                e: TestEnum.Third
            };
            MixedTest mixed2 = {
                x: 55, y: -20, f: -5,
                str: "!אツ😃", dstr: "!אツ😃"d,
                dints: [-5, -6, -6, -7, -8, -5, 0, 1], sints: [0, 2, 2, -3],
                e: TestEnum.First
            };
            foreach(value; Aliases!(
                IntsTest(0, 0, 0), IntsTest(1, 2, 3),
                WithEnumTest(TestEnum.First), WithEnumTest(TestEnum.Second),
                mixed1, mixed2
            )){
                testeq(value.jsonserialize.jsondeserialize!(typeof(value)), value);
            }
        });
        tests("Classes", {
            ClassTest a = new ClassTest(0, 0, 0);
            testeq(a.jsonserialize.jsondeserialize!ClassTest.x, 0);
            ClassTest b = new ClassTest(1, 2, 3);
            testeq(b.jsonserialize.jsondeserialize!ClassTest.x, 1);
            ClassTest c = null;
            JsonValue value = c.jsonserialize;
            testis(value.type, JsonValue.Type.Null);
            testis(value.jsondeserialize!ClassTest, null);
        });
        tests("Nesting", {
            NestSuccessTest a = new NestSuccessTest();
            testeq(a.jsonserialize.jsondeserialize!NestSuccessTest, a);
            NestFailureTest b = new NestFailureTest();
            b.nest = b;
            testfail({b.jsonserialize;});
        });
        tests("Custom to/from json", {
            CustomTest custom = CustomTest(10);
            JsonValue value = custom.jsonserialize;
            testis(value.type, JsonValue.Type.Integer);
            testeq(value.jsondeserialize!CustomTest, custom);
        });
        tests("Skip UDA", {
            SkipTest skip = SkipTest(1, 2);
            JsonValue value = skip.jsonserialize;
            test("x" in value);
            testf("y" in value);
        });
        tests("Arrays", {
            struct Test{
                int[4][] x;
                int[4][char] y;
            }
            Test empty;
            JsonValue value = empty.jsonserialize;
            auto encoded = value.encode;
            testeq(encoded, `{"x":[],"y":{}}`);
            enum json = `{"x": [[1, 2, 3, 4]], "y": {"a": [1, 2, 3, 4]}}`;
            Test filled = json.parsejson.jsondeserialize!Test;
            testeq(filled, Test([[1, 2, 3, 4]], ['a': [1, 2, 3, 4]]));
        });
        tests("Array of enums", {
            enum Enum{First, Second, Third}
            auto array = [Enum.First, Enum.Second, Enum.Third];
            JsonValue value = array.jsonserialize;
            testis(value.type, JsonValue.Type.Array);
            testeq(value.length, 3);
            testeq(value.jsondeserialize!(Enum[]), array);
        });
        tests("Associative array enum key", {
            enum Enum{First, Second, Third}
            int[Enum] array = [Enum.First: 1, Enum.Second: 2, Enum.Third: 3];
            testeq(array.jsonserialize.jsondeserialize!(int[Enum]), array);
            testfail({
                JsonValue(["First": 1, "Nope": 2]).jsondeserialize!(int[Enum]);
            });
        });
    });
}
