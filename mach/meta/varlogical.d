module mach.meta.varlogical;

private:

/++ Docs: mach.meta.varlogical

This module implements the `varany`, `varall`, and `varnone` functions,
which perform logical operations upon their variadic arguments.

Each function accepts an optional predicate function; by default,
arguments are themselves evaluated for truthiness or falsiness.

+/

unittest{ /// Example
    assert(varany(false, true));
    assert(!varany(false, false));
}

unittest{ /// Example
    assert(varall(true, true));
    assert(!varall(true, false));
}

unittest{ /// Example
    assert(varnone(false, false));
    assert(!varnone(false, true));
}

unittest{ /// Example
    alias even = (n) => (n % 2 == 0);
    assert(varany!even(1, 2, 3));
    assert(!varall!even(1, 2, 3));
    assert(!varnone!even(1, 2, 3));
}

public:



/// Get whether any passed arguments evaluate true.
/// When no arguments are passed, the function returns false.
/// Short-circuits when the first true value is found.
auto varany(alias pred = (x) => (x), Args...)(auto ref Args args){
    foreach(i, _; Args){
        if(pred(args[i])) return true;
    }
    return false;
}

/// Get whether all passed arguments evaluate true.
/// When no arguments are passed, the function returns true.
/// Short-circuits when the first false value is found.
auto varall(alias pred = (x) => (x), Args...)(auto ref Args args){
    foreach(i, _; Args){
        if(!pred(args[i])) return false;
    }
    return true;
}

/// Get whether no passed arguments evaluate true.
/// When no arguments are passed, the function returns true.
auto varnone(alias pred = (x) => (x), Args...)(auto ref Args args){
    foreach(i, _; Args){
        if(pred(args[i])) return false;
    }
    return true;
}



unittest{
    assert(varany(true));
    assert(varany(true, true, true));
    assert(varany(true, true, false));
    assert(!varany());
    assert(!varany(false));
    assert(!varany(null));
    assert(varany!(n => n > 0)(-1, 0, 1));
    assert(!varany!(n => n > 0)(-1, 0, -2));
}
unittest{
    assert(varall());
    assert(varall(true));
    assert(varall(true, true, true));
    assert(!varall(false));
    assert(!varall(true, true, false));
    assert(!varall(true, true, false, null));
}
unittest{
    assert(varnone());
    assert(varnone(false));
    assert(varnone(false, false, false));
    assert(!varnone(true));
    assert(!varnone(true, true));
    assert(!varnone(true, true, false));
    assert(!varnone(true, null, false));
}
