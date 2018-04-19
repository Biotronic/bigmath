import std.range : iota, retro;
import std.algorithm : among;
import std.stdio : writeln;
import std.meta : Repeat;
import biguintcore;
version(D_InlineAsm_X86)
{
    import biguintx86;
}
else
{
    import biguintnoasm;
}

struct Uint(size_t bits)
if (bits.isPow2 && bits > 64)
{
    enum digits = bits / 8 / BigDigit.sizeof;
    enum Uint min = Uint.init;
    enum Uint max = Uint([Repeat!(digits, BigDigit(-1))]);
    BigDigit[digits] data;
    
    this(ulong value)
    {
        this = value;
    }
    
    this(string value)
    {
        this = value;
    }
    
    private this(BigDigit[digits] value)
    {
        data = value;
    }
    
    ref Uint opAssign(string rhs)
    {
        biguintFromDecimal(data, rhs);
        return this;
    }

pure nothrow:
    Uint opUnary(string op)() const
    if (op.among("+","-"))
    {
        Uint result = void;
        static if (op == "-") {
            result.data[] = ~data[];
            multibyteIncrementAssign!'+'(result.data, 1);
        } else {
            result = this;
        }
        return result;
    }
    
    ref Uint opAssign(ulong rhs)
    {
        static if (is(BigDigit == ulong))
        {
            data[0] = rhs;
            data[1..$] = 0;
        }
        else
        {
            data[0] = rhs & 0xFFFF_FFFF;
            data[1] = rhs >> 32;
            data[2..$] = 0;
        }
        return this;
    }
    
    ref Uint opAssign(size_t rhsBits)(Uint!rhsBits rhs)
    if (rhsBits <= bits)
    {
        enum digs = digits - rhs.digits;
        data[0..rhs.digits] = rhs.data;
        data[rhs.digits..$] = 0;
        return this;
    }
    
    bool opEquals(size_t rhsBits)(Uint!rhsBits rhs) const
    if (rhsBits < bits)
    {
        foreach (i, e; data) {
            if (i >= rhs.digits && e == 0) continue;
            if (i <  rhs.digits && e == rhs.data[i]) continue;
            return false;
        }
        return true;
    }
    
    int opCmp(size_t rhsBits)(Uint!rhsBits rhs) const
    if (rhsBits < bits)
    {
        foreach (i; digits.iota.retro) {
            if (i >= rhs.digits && data[i] != 0) return 1;
            if (i <  rhs.digits && data[i] != rhs.data[i]) return data[i] - rhs.data[i];
        }
        return 0;
    }
    
    string toString() const
    {
        char [] buff = new char[20+10*digits];
        ptrdiff_t sofar = buff.length;
        
        BigDigit[] arr = data.dup;
        
        while (arr.length > 1)
        {
            uint rem = multibyteDivAssign(arr, 10_0000_0000, 0);
            itoaZeroPadded(buff[sofar-9 .. sofar], rem);
            sofar -= 9;
            if (arr[$-1] == 0 && arr.length > 1)
            {
                arr.length = arr.length - 1;
            }
        }
        itoaZeroPadded(buff[sofar-10 .. sofar], arr[0]);
        sofar -= 10;
        // and strip off the leading zeros
        while (sofar != buff.length-1 && buff[sofar] == '0')
            sofar++;
        return buff[sofar..$];
    }
}


// TODO: Replace with a library call
void itoaZeroPadded(char[] output, uint value)
    pure nothrow @safe @nogc
{
    for (auto i = output.length; i--;)
    {
        if (value < 10)
        {
            output[i] = cast(char)(value + '0');
            value = 0;
        }
        else
        {
            output[i] = cast(char)(value % 10 + '0');
            value /= 10;
        }
    }
}

template Uint(size_t bits)
if (bits.isPow2 && bits <= 64 && bits >= 8)
{
    static if (bits ==  8) alias Uint = ubyte;
    static if (bits == 16) alias Uint = ushort;
    static if (bits == 32) alias Uint = uint;
    static if (bits == 64) alias Uint = ulong;
}

bool isPow2(size_t x)
{
    return (x & (x - 1)) == 0;
}

unittest
{
    import std.conv : to;
    Uint!256 a;
    Uint!128 b = 1459;
    assert(a.sizeof == 32);
    a = b;
    static assert(!__traits(compiles, b = a));
    
    assert(a == b);
    assert(b == a);
    assert(a.to!string == "1459");
    assert(b.to!string == "1459");
    
    a = 200;
    b = 100;
    assert(a > b);
    
    a = "100000000000000000000";
    b = "200000000000000000000";
    assert(a < b);
    
    a = "100000000000000000000";
    b = "100000000000000000000";
    assert(!(a < b) && !(b < a));
}