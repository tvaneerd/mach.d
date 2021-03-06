# mach.text.numeric


This package provides functions for parsing and serializing numbers.

Of note are the `parsenumber` and `writenumber` functions, which are
generic implementations handling integer and floating point primitives of
any type.

``` D
assert("100".parsenumber!int == 100);
assert("1234.5".parsenumber!double == double(1234.5));
```

``` D
assert(int(200).writenumber == "200");
assert(double(456.789).writenumber == "456.789");
```


## mach.text.numeric.burger


This module implements Burger's algorithm, described by the paper
[Printing Floating-Point Numbers Quickly and Accurately](http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.67.4438&rep=rep1&type=pdf).
The original algorithm, written in C and permissively licensed, is © 1996
Robert G. Burger.
This D module was written by Sophie Kirschner, translated from the C written by
Robert Burger, and is licensed according to the terms of the
[mach library](https://github.com/pineapplemachine/mach.d),
of which this module is a part.

Here is the C code, written by Robert Burger, upon which this module is based:
https://web.archive.org/web/20100324060707/http://www.cs.indiana.edu/~burger/fp/free.c

Also thanks to the authors of this Python code, which proved invaluable in
filling the gaps in my understanding of the algorithm:
https://bugs.python.org/file8910/short_float_repr.diff


## mach.text.numeric.combined


This module implements the `parsenumber` and `writenumber` methods, which are
generic interfaces to the `parseint`, `parsefloat`, `writeint`, and `writefloat`
methods.
These methods accept either integers or floats as input, but do not offer the
same specialized configuration options as if the wrapped methods were called
directly.

Note that while the `parsefloat` method operates strictly upon numeric literals,
the `parsenumber` method, when parsing a floating point type, will recognize
the literals defined in the default `WriteFloatSettings` and return the special
values accordingly.

``` D
assert("100".parsenumber!int == 100);
assert("256".parsenumber!ushort == 256);
assert("1234.5".parsenumber!double == double(1234.5));
assert("1e20".parsenumber!double == double(1e20));
```

``` D
import mach.math.floats.properties : fisposinf, fisnan;
assert("infinity".parsenumber!double.fisposinf);
assert("nan".parsenumber!double.fisnan);
```


The `parsenumber` method, like `parseint` and `parsefloat`, throws a
`NumberParseException` when the input was malformed.

``` D
import mach.error.mustthrow : mustthrow;
mustthrow!NumberParseException({
    "some malformed input".parsenumber!int;
});
```


## mach.text.numeric.exceptions


This module implements the `NumberParseException` and `NumberWriteError`
exception types, which are thrown by some operations elsewhere in this package.


## mach.text.numeric.floats


This module implements the `writefloat` and `parsefloat` functions, which can
be used to serialize and deserialize floating point values as human-readable
strings in decimal notation.

The `writefloat` function optionally accepts a `WriteFloatSettings` object
as a template parameter, which defines aspects of behavior such as what to
output when the value is infinity or NaN, how to handle very large and
small inputs, and whether to always output a trailing `.0` even for integer
values.

The `parsefloat` function throws a `NumberParseException` when the input was
malformed.
Note that the `parsefloat` function does not accept string literals intended
to represent NaN or infinity; it parses only numeric literals.

``` D
assert(writefloat(0) == "0");
assert(writefloat(123.456) == "123.456");
assert(writefloat(double.infinity) == "infinity");
```

``` D
enum WriteFloatSettings settings = {
    PosInfLiteral: "positive infinity",
    NegInfLiteral: "negative infinity"
};
assert(writefloat!settings(double.infinity) == "positive infinity");
assert(writefloat!settings(-double.infinity) == "negative infinity");
```

``` D
assert("1234.5".parsefloat!double == double(1234.5));
assert("678e9".parsefloat!double == double(678e9));
```

``` D
import mach.error.mustthrow : mustthrow;
mustthrow!NumberParseException({
    "malformed input".parsefloat!double;
});
```


## mach.text.numeric.hexfloats


The `writehexfloat` and `parsehexfloat` functions can be used to write and
parse floats in a hexadecimal format.
For a description of this format, see the
[D language documentation](https://dlang.org/spec/lex.html#floatliteral)
and the [C99 standard](http://c0x.coding-guidelines.com/6.4.4.2.html).

The `parsehexfloat` function accepts an optional template parameter indicating
the floating point type to parse, i.e. `float`, `double`, or `real`.
If no such parameter is provided, then the function returns a double by default.

``` D
assert(writehexfloat(0x1.23abcp10) == "0x1.23abcp10");
assert(parsehexfloat!double("0x1.23abcp10") == double(0x1.23abcp10));
```


`parsehexfloat` throws a `ParseNumberException` when it receives a malformed
input string.

``` D
import mach.error.mustthrow : mustthrow;
mustthrow!NumberParseException({
    "malformed input".parsehexfloat;
});
```


## mach.text.numeric.integrals


This module provides a plethora of functions for parsing integrals from strings
and for writing them back again.
The most basic and common use cases are represented by the `parseint` and
`writeint` functions.

``` D
assert(1234.writeint == "1234");
assert("5678".parseint == 5678);
```

``` D
// Bad inputs provoke a `NumberParseException`.
import mach.error.mustthrow : mustthrow;
mustthrow!NumberParseException({
    "Not really a number".parseint;
});
```


Parsing functions provided by this module, such as `parseint`, may receive an
optional template parameter specifying the storage type.

``` D
import mach.error.mustthrow : mustthrow;
assert("100".parseint!ulong == 100);
mustthrow!NumberParseException({
    "-100".parseint!ulong; // Can't store a negative number in a ulong!
});
```


The `parsehex` and `writehex` functions can be used to read and write
hexadecimal strings.
Note these functions pad the output depending on the size of the input integral
type.

``` D
assert(ubyte(0xFF).writehex == "FF");
assert(ushort(0xFF).writehex == "00FF");
assert("80F0".parsehex == 0x80F0);
```


The functions in this module are capable of parsing and serializing numbers in
bases from unary up to and including base 64.
In addition to decimal and hexadecimal,
octal is supported via `parseoct` and `writeoct`,
padded binary via `parsebin` and `writebin`,
RFC 4648 base 32 via `parseb32` and `writeb32`,
and base 64 via `parseb64` and `writeb64`.

These functions are all aliases to instantiations of the `ParseBase`,
`WriteBase`, and `WriteBasePadded` templates.
These templates can be freely used to produce functions for parsing and
serializing bases 1 through 36 and base 64.
The basis of the functionality for those templates are the `ParseBaseGeneric`,
`WriteBaseGeneric`, and `WriteBasePaddedGeneric` functions, which may be used
to parse and serialize essentially any base when provided with functions for
determining the meaning of a given character.

``` D
assert(ubyte(127).writebin == "01111111");
assert("10110".parsebin == 22);
```

``` D
assert(10.writeoct == "12");
assert("12".parseoct == 10);
```

``` D
assert(24.WriteBase!3 == "220");
assert("220".ParseBase!3 == 24);
```


Note that `WriteBasePadded`, along with `writebin` and `writehex` which depend
on it, is not able to write negative numbers. When passing a negative number
to a padded serialization function, a `NumberWriteError` will result except
for when compiling in release mode. (In release mode the check is omitted, and
the function may produce nonsense data.)

``` D
import mach.error.mustthrow : mustthrow;
assert(byte(16).writehex == "10"); // Positive signed inputs ok.
mustthrow!NumberWriteError({
    byte(-16).writehex; // Negative inputs not ok.
});
```


