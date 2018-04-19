module bigfloat;

import core.bitop;
import std.array;
import std.exception;
import std.stdio;
import std.algorithm;
import std.traits;
import std.meta;
import std.math;
import std.bitmanip;
import biguintcore;

version(D_InlineAsm_X86)
{
    import biguintx86;
}
else
{
    import biguintnoasm;
}

private template ScaledFloatRep(T)
if (isFloatingPoint!T)
{
    static if (is(Unqual!T == float))
        alias ScaledFloatRep = FloatRep;
    else static if (is(Unqual!T == double))
        alias ScaledFloatRep = DoubleRep;
    else
        static assert(false, "No XRep for type "~T.stringof);
}

struct BigFloat(size_t bits)
if (bits % (BigDigit.sizeof*8) == 0 && bits > 0)
{
    private enum digits = bits / (BigDigit.sizeof*8);
    bool nan;
    bool sign;
    long exponent;
    immutable(BigDigit)[] fraction;
    
    private BigDigit[] createFraction(ulong value)
    {
        static if (BigDigit.sizeof == ulong.sizeof)
            return [Repeat!(digits-1, 0), value];
        else
            return [Repeat!(digits-2, 0), (value >> 32) & 0xFFFF_FFFF, value & 0xFFFF_FFFF];
    }
    
    this(long value)
    {
        sign = value < 0;
        exponent = cast(long)log2(value);
        value = abs(value);
        fraction = createFraction(cast(ulong)abs(value)).adjustFraction(digits, &exponent).assumeUnique;
    }
    
    this(T)(T value)
    if (isFloatingPoint!T)
    {
        auto a = ScaledFloatRep!T(value);
        sign = a.sign;
        exponent = a.exponent - a.bias;
        ulong frac = cast(ulong)a.fraction << (63 - a.fractionBits) | 0x8000_0000_0000_0000;
        fraction = createFraction(frac);
    }
    
    T opCast(T)() const
    if (isFloatingPoint!T)
    {
        ScaledFloatRep!T result;
        result.sign = sign;
        ulong frac = fraction[$-1];
        static if (BigDigit.sizeof != ulong.sizeof)
        {
            frac <<= 32;
            frac |= fraction[$-2];
        }
        result.fraction = (frac & 0x7FFF_FFFF_FFFF_FFFF) >> (63-result.fractionBits);
        result.exponent = cast(typeof(result.exponent))(exponent + result.bias);
        
        return result.value;
    }
    
    BigFloat opUnary(string op)() const
    if (op.among("+", "-"))
    {
        BigFloat result = this;
        result.sign = sign == (op == "+");
        return result;
    }
    
    BigFloat opBinary(string op, size_t bits2)(BigFloat!bits2 rhs) const
    if (bits >= bits2)
    {
        BigFloat result;
             static if (op == "+")
        {
        }
        else static if (op == "-")
        {
        }
        else static if (op == "*")
        {
            result.sign = sign != rhs.sign;
            result.exponent = exponent + rhs.exponent;
            
            BigDigit[digits*2] frac;
            mulInternal(frac, fraction, rhs.fraction);
            
            result.fraction = frac.adjustFraction(digits, &result.exponent).assumeUnique;
        }
        else static if (op == "/")
        {
            result.sign = sign == rhs.sign;
        }
        else static if (op == "^^")
        {
            result.nan = sign;
        }
        return result;
    }
    
    string toStringa() const
    {
        import std.conv : to;
        return (cast(float)this).to!string;
    }
}

BigDigit[] adjustFraction(BigDigit[] arr, size_t digits, long* exponent)
{
    while (arr.back == 0)
        arr.popBack();
    arr = arr[$-digits..$];
    
    BigDigit[] data = new BigDigit[digits];
    auto bits = bsr(arr[$-1]);
    multibyteShl(data, arr, BigDigit.sizeof*8 - bits);
    *exponent += bits;
    
    return data;
}

//pure nothrow @safe
unittest
{
    const BigFloat!128 a =  2.5;
    const BigFloat!128 b = -14;
    const c = a * b;
    const BigFloat!128 d = -35;
    writeln(a, " * ", b, " = ", c, " (expect ", d, ")");
    assert(c == d);
}

pure nothrow @safe
unittest
{
    const BigFloat!128 a =  3.14;
    const BigFloat!128 b = -3.14;
    assert( a != b);
    assert( a == a);
    assert(-a == b);
}