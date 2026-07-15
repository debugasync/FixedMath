# FixedMath

Deterministic fixed point math for Luau. Feed the same inputs on two different machines and you get exactly the same bits out, which is the one thing floats can't promise and the whole reason this exists.

If you've never hit the problem it's easy to miss why it matters. Floats are *almost* consistent across devices, but not quite, and `math.sin` is worse because nothing in the spec pins down how it's implemented. That tiny disagreement is harmless right up until two clients are each running the same simulation and expecting to land on the same answer. Then the error compounds a little more every tick, and eventually one player sees an enemy standing where the other player sees empty floor. There's no patching that after the fact, so you have to not drift in the first place. Doing the whole simulation in integers gets you there, since integers are the same everywhere.

There are a pile of rollback and lockstep *tutorials* floating around the DevForum and, as far as I could find, no actual library for the math underneath them. So, here.

## format

Everything is Q16.16: a plain Luau number holding an integer that's been scaled by 65536. I went with Q16.16 mostly because the range and resolution were easy to reason about in my head, not because I benchmarked a bunch of layouts.

- range is roughly -32768 to 32767
- resolution is 1/65536 (~0.0000153)
- a value is just a number, no tables, no metatables, no allocation

The scale isn't arbitrary. It's picked so a multiply stays inside the exact integer range of a double. If you just write `Left * Right` on two Q16.16 raws you blow past 2^53 and the result quietly stops being reproducible, which defeats the entire point, so `Fixed.Mul` splits both sides into 16-bit halves and recombines them. The FNV hash multiply does the same dance for the same reason.

## accuracy

Measured against the native float versions. "lsb" is one unit of least precision, 1/65536, so anything under 1.0 is as tight as the format can physically get.

| op | max error | lsb |
| --- | --- | --- |
| mul | 0.0000151 | 0.99 |
| div | 0.0000153 | 1.00 |
| sqrt | 0.0000153 | 1.00 |
| sin | 0.0000140 | 0.91 |
| cos | 0.0000140 | 0.92 |
| atan2 | 0.0000140 | 0.92 |

Trig is CORDIC. Because CORDIC is nothing but adds and shifts, carrying extra precision costs basically nothing, so it runs at 30 fractional bits internally and rounds back to 16 on the way out. Run it at Q16.16 the whole way and you get about 12 lsb of error instead, which is bad enough to see. `Atan2` also normalizes its inputs before it starts iterating, and if you skip that the last few iterations shift down to zero and the angle just accumulates garbage, about 76 lsb of it, which took me a minute to figure out.

`Tests.Run()` reprints that table and dumps a simulation digest if you want to check it yourself.

## install

wally:

```toml
[dependencies]
FixedMath = "debugasync/fixedmath@0.1.0"
```

or just drop `src` into ReplicatedStorage as a ModuleScript named `FixedMath`.

## use

```lua
local FixedMath = require(game.ReplicatedStorage.FixedMath)
local Fixed = FixedMath.Fixed
local Vec3 = FixedMath.Vec3

local Speed = Fixed.FromNumber(12.5)
local Delta = Fixed.FromNumber(1 / 60)

local Position = Vec3.New(0, Fixed.FromInt(10), 0)
local Velocity = Vec3.Scale(Vec3.New(Fixed.One, 0, 0), Speed)

Position = Vec3.Add(Position, Vec3.Scale(Velocity, Delta))

print(Fixed.ToString(Position.X))
print(Vec3.ToVector3(Position))
```

`FromNumber` and `ToNumber` are your only crossings back to floats. Use them at the edges, authoring a constant, handing a final position to the renderer, and nowhere in between. The moment a float sneaks into the middle of the sim you've put the drift right back.

## random

`math.random` is useless here since every client would roll its own sequence. There's an xorshift32 generator instead, seeded explicitly so everyone rolls the same numbers:

```lua
local Random = FixedMath.Random
local Generator = Random.New(1337)

local Roll = Random.NextRange(Generator, 0, Fixed.One)
local Index = Random.NextInt(Generator, 1, 6)
```

## hashing

When you want to prove two machines actually agree, hash the state and compare. It's FNV-1a over the raw integers:

```lua
local Hash = FixedMath.Hash
local Digest = Hash.New()

for i = 1, #Entities do
    Hash.PushVec3(Digest, Entities[i].Position)
    Hash.PushVec3(Digest, Entities[i].Velocity)
end

print(Hash.ToString(Digest))
```

Different digests means they diverged, and the earliest tick where they differ is where your bug is.

## api

`Fixed` FromInt ToInt FromNumber ToNumber FromFraction Saturate Add AddSat Sub SubSat Negate Abs Sign Min Max Clamp Mul MulSat Div DivSat Mod Floor Ceil Round Fraction Lerp InverseLerp Approach Sqrt PowInt SinCos Sin Cos Tan Atan2 Atan Asin Acos ToString

`Vec2` New FromNumbers Zero Clone Add Sub Negate Scale Divide Dot Cross MagnitudeSquared Magnitude Unit Distance Lerp Rotate Angle Equals ToString

`Vec3` New FromNumbers Zero Clone Add Sub Negate Scale Divide Dot Cross MagnitudeSquared Magnitude Unit Distance Lerp Equals ToVector3 FromVector3 ToString

`Hash` New Reset PushInt PushFixed PushVec2 PushVec3 Digest ToString Multiply

`Random` New Clone Next NextFixed NextRange NextInt NextSign NextUnit2

## limitations

- The range is small. ±32768 with 16 fractional bits is fine for most gameplay coordinates but a big open world or a squared distance will overflow, and nothing bounds-checks unless you reach for the `Sat` variants.
- `MagnitudeSquared` in particular overflows way before the vector does, because squaring burns through the range fast. Bit me once already.
- It's slower than native floats. Obviously.
- The determinism only holds if the *whole* loop stays fixed point. One stray float, one `math.random`, and it's gone. This is the mistake everyone makes first.
- Still no exp or log. Haven't needed them, and hyperbolic CORDIC is a whole other thing I didn't feel like writing yet.

## license

MIT
