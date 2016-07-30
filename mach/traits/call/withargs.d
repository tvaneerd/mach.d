module mach.traits.call.withargs;

private:

import mach.traits.call.callable;

public:
    


/// Determine whether some type can be called with the given argument types.
template isCallableWith(alias T, Args...){
    static if(isCallable!T){
        enum bool isCallableWith = is(typeof((){Args args = Args.init; T(args);}));
    }else{
        enum bool isCallableWith = false;
    }
}
/// ditto
template isCallableWith(T, Args...){
    static if(isCallable!T){
        enum bool isCallableWith = is(typeof((){Args args = Args.init; T(args);}));
    }else{
        enum bool isCallableWith = false;
    }
}

/// Get the return type of a callable when invoked with the given argument types.
template ReturnTypeWith(alias T, Args...) if(isCallableWith!(T, Args)){
    alias ReturnTypeWith = typeof({Args args = Args.init; return T(args);}());
}
/// ditto
template ReturnTypeWith(T, Args...) if(isCallableWith!(T, Args)){
    alias ReturnTypeWith = typeof({Args args = Args.init; return T(args);}());
}



template ReturnsWith(alias T, Ret, Args...){
    enum bool ReturnsWith = ReturnsWith!(CallableType!T, Ret, Args);
}
template ReturnsWith(T, Ret, Args...){
    static if(isCallableWith!(T, Args)){
        enum bool ReturnsWith = is(ReturnTypeWith!(CallableType!T, Args) == Ret);
    }else{
        enum bool ReturnsWith = false;
    }
}



unittest{
    void fn1(){}
    void fn2(int x){}
    int fn3(){return 0;}
    int fn4(int x){return 0;}
    static assert(isCallableWith!(fn1));
    static assert(isCallableWith!(typeof(fn1)));
    static assert(isCallableWith!(fn2, int));
    static assert(isCallableWith!(fn3));
    static assert(isCallableWith!(fn4, int));
    static assert(!isCallableWith!(fn1, int));
    static assert(!isCallableWith!(fn1, int, int));
    static assert(!isCallableWith!(fn2));
    static assert(!isCallableWith!(fn2, int, int));
    static assert(!isCallableWith!(int));
    static assert(!isCallableWith!(int, int));
}
unittest{
    int function(int x) fptr;
    int delegate(int x) del;
    static assert(isCallableWith!(fptr, int));
    static assert(isCallableWith!(del, int));
    static assert(!isCallableWith!(fptr));
    static assert(!isCallableWith!(del));
    static assert(!isCallableWith!(fptr, string));
    static assert(!isCallableWith!(del, string));
}
unittest{
    alias del0 = int delegate(ref int);
    alias del1 = int delegate(ref int) @system;
    alias del2 = int delegate(ref int) pure @nogc;
    static assert(isCallableWith!(del0, int));
    static assert(isCallableWith!(del1, int));
    static assert(isCallableWith!(del2, int));
}
unittest{
    struct OneCall{static void opCall(int x){}}
    struct TwoCalls{static void opCall(int x){} static void opCall(int x, int y){}}
    static assert(isCallableWith!(OneCall, int));
    static assert(isCallableWith!(TwoCalls, int));
    static assert(isCallableWith!(TwoCalls, int, int));
    static assert(!isCallableWith!(OneCall));
    static assert(!isCallableWith!(OneCall, int, int));
    static assert(!isCallableWith!(TwoCalls));
    static assert(!isCallableWith!(TwoCalls, string));
}

unittest{
    static void sfunc(){}
    void fn1(){}
    int fn2(){return 1;}
    int function(int x) fptr;
    int delegate(int x) del;
    auto fn1ptr = &fn1;
    struct OpCall{static void opCall(int x){} static int opCall(string x){return 0;}}
    static assert(is(ReturnTypeWith!(fn1) == void));
    static assert(is(ReturnTypeWith!(fn2) == int));
    static assert(is(ReturnTypeWith!(fptr, int) == int));
    static assert(is(ReturnTypeWith!(OpCall, int) == void));
    static assert(is(ReturnTypeWith!(OpCall, string) == int));
    static assert(ReturnsWith!(fn1, void));
    static assert(ReturnsWith!(fptr, int, int));
    static assert(!ReturnsWith!(fn1, int));
    static assert(!ReturnsWith!(fptr, int, int, int));
}