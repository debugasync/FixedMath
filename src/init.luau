-- FixedMath

-- Variables
local Floor = math.floor
local Bxor = bit32.bxor
local Lshift = bit32.lshift
local Rshift = bit32.rshift
local Format = string.format


-- Constants
local FractionBits = 16
local One = 65536
local Half = 32768

local RawMax = 2147483647
local RawMin = -2147483648

local Pi = 205887
local TwoPi = 411774
local HalfPi = 102944
local QuarterPi = 51472

local CordicDown = 16384
local CordicRound = 8192
local CordicNorm = 549755813888
local CordicGain = 652032874

local CordicAtan = {
    843314857,
    497837829,
    263043837,
    133525159,
    67021687,
    33543516,
    16775851,
    8388437,
    4194283,
    2097149,
    1048576,
    524288,
    262144,
    131072,
    65536,
    32768,
    16384,
    8192,
    4096,
    2048,
    1024,
    512,
    256,
    128,
    64,
    32,
    16,
    8,
    4,
    2,
    1
}

local CordicShift = {
    1,
    2,
    4,
    8,
    16,
    32,
    64,
    128,
    256,
    512,
    1024,
    2048,
    4096,
    8192,
    16384,
    32768,
    65536,
    131072,
    262144,
    524288,
    1048576,
    2097152,
    4194304,
    8388608,
    16777216,
    33554432,
    67108864,
    134217728,
    268435456,
    536870912,
    1073741824
}

local CordicSteps = #CordicAtan

local HashBasis = 2166136261
local HashPrime = 16777619
local HashWrap = 4294967296


-- Namespaces
local FixedMath = {}

local Fixed = {}
local Vec2 = {}
local Vec3 = {}
local Hash = {}
local Random = {}


-- Fixed
do
    Fixed.Bits = FractionBits
    Fixed.One = One
    Fixed.Zero = 0
    Fixed.Half = Half
    Fixed.Epsilon = 1
    Fixed.Max = RawMax
    Fixed.Min = RawMin

    Fixed.Pi = Pi
    Fixed.TwoPi = TwoPi
    Fixed.HalfPi = HalfPi
    Fixed.QuarterPi = QuarterPi

    Fixed.FromInt = function(Value)
        return Value * One
    end

    Fixed.ToInt = function(Value)
        return Floor(Value / One)
    end

    Fixed.FromNumber = function(Value)
        return Floor(Value * One + 0.5)
    end

    Fixed.ToNumber = function(Value)
        return Value / One
    end

    Fixed.FromFraction = function(Numerator, Denominator)
        if Denominator == 0 then
            return Numerator >= 0 and RawMax or RawMin
        end

        local Sign = 1

        if Numerator < 0 then
            Numerator = -Numerator
            Sign = -Sign
        end

        if Denominator < 0 then
            Denominator = -Denominator
            Sign = -Sign
        end

        local Result = Floor((Numerator * One) / Denominator)

        return Sign < 0 and -Result or Result
    end

    Fixed.Saturate = function(Value)
        if Value > RawMax then
            return RawMax
        end

        if Value < RawMin then
            return RawMin
        end

        return Value
    end

    Fixed.Add = function(Left, Right)
        return Left + Right
    end

    Fixed.AddSat = function(Left, Right)
        return Fixed.Saturate(Left + Right)
    end

    Fixed.Sub = function(Left, Right)
        return Left - Right
    end

    Fixed.SubSat = function(Left, Right)
        return Fixed.Saturate(Left - Right)
    end

    Fixed.Negate = function(Value)
        return -Value
    end

    Fixed.Abs = function(Value)
        return Value < 0 and -Value or Value
    end

    Fixed.Sign = function(Value)
        if Value > 0 then
            return One
        end

        if Value < 0 then
            return -One
        end

        return 0
    end

    Fixed.Min = function(Left, Right)
        return Left < Right and Left or Right
    end

    Fixed.Max = function(Left, Right)
        return Left > Right and Left or Right
    end

    Fixed.Clamp = function(Value, Low, High)
        if Value < Low then
            return Low
        end

        if Value > High then
            return High
        end

        return Value
    end

    Fixed.Mul = function(Left, Right)
        local Sign = 1

        if Left < 0 then
            Left = -Left
            Sign = -Sign
        end

        if Right < 0 then
            Right = -Right
            Sign = -Sign
        end

        local LeftHigh = Floor(Left / One)
        local LeftLow = Left - LeftHigh * One
        local RightHigh = Floor(Right / One)
        local RightLow = Right - RightHigh * One

        local Result = LeftHigh * RightHigh * One
            + LeftHigh * RightLow
            + LeftLow * RightHigh
            + Floor((LeftLow * RightLow) / One)

        return Sign < 0 and -Result or Result
    end

    Fixed.MulSat = function(Left, Right)
        return Fixed.Saturate(Fixed.Mul(Left, Right))
    end

    Fixed.Div = function(Left, Right)
        if Right == 0 then
            return Left >= 0 and RawMax or RawMin
        end

        local Sign = 1

        if Left < 0 then
            Left = -Left
            Sign = -Sign
        end

        if Right < 0 then
            Right = -Right
            Sign = -Sign
        end

        local Result = Floor((Left * One) / Right)

        return Sign < 0 and -Result or Result
    end

    Fixed.DivSat = function(Left, Right)
        return Fixed.Saturate(Fixed.Div(Left, Right))
    end

    Fixed.Mod = function(Value, Divisor)
        if Divisor == 0 then
            return 0
        end

        return Value % Divisor
    end

    Fixed.Floor = function(Value)
        return Value - Value % One
    end

    Fixed.Ceil = function(Value)
        local Fraction = Value % One

        if Fraction == 0 then
            return Value
        end

        return Value + (One - Fraction)
    end

    Fixed.Round = function(Value)
        local Shifted = Value + Half

        return Shifted - Shifted % One
    end

    Fixed.Fraction = function(Value)
        return Value % One
    end

    Fixed.Lerp = function(From, To, Alpha)
        return From + Fixed.Mul(To - From, Alpha)
    end

    Fixed.InverseLerp = function(From, To, Value)
        if From == To then
            return 0
        end

        return Fixed.Div(Value - From, To - From)
    end

    Fixed.Approach = function(Current, Target, Step)
        if Current < Target then
            return Fixed.Min(Current + Step, Target)
        end

        if Current > Target then
            return Fixed.Max(Current - Step, Target)
        end

        return Target
    end

    Fixed.Sqrt = function(Value)
        if Value <= 0 then
            return 0
        end

        local Widened = Value * One
        local Guess = Widened
        local Refined = Floor((Guess + 1) / 2)

        while Refined < Guess do
            Guess = Refined
            Refined = Floor((Guess + Floor(Widened / Guess)) / 2)
        end

        return Guess
    end

    Fixed.PowInt = function(Value, Exponent)
        if Exponent == 0 then
            return One
        end

        local Inverse = Exponent < 0

        if Inverse then
            Exponent = -Exponent
        end

        local Result = One
        local Base = Value

        while Exponent > 0 do
            if Exponent % 2 == 1 then
                Result = Fixed.Mul(Result, Base)
            end

            Base = Fixed.Mul(Base, Base)
            Exponent = Floor(Exponent / 2)
        end

        if Inverse then
            return Fixed.Div(One, Result)
        end

        return Result
    end

    Fixed.ToString = function(Value)
        local Sign = Value < 0 and "-" or ""

        if Value < 0 then
            Value = -Value
        end

        local Whole = Floor(Value / One)
        local Fraction = Floor(((Value - Whole * One) * 1000000) / One)

        return Format("%s%d.%06d", Sign, Whole, Fraction)
    end
end


-- Trigonometry
do
    Fixed.SinCos = function(Angle)
        Angle = Angle % TwoPi

        if Angle > Pi then
            Angle -= TwoPi
        end

        local Negate = false

        if Angle > HalfPi then
            Angle = Pi - Angle
            Negate = true
        elseif Angle < -HalfPi then
            Angle = -Pi - Angle
            Negate = true
        end

        local X = CordicGain
        local Y = 0
        local Residual = Angle * CordicDown

        for i = 1, CordicSteps do
            local Shift = CordicShift[i]
            local StepX = Floor(X / Shift)
            local StepY = Floor(Y / Shift)

            if Residual >= 0 then
                X -= StepY
                Y += StepX
                Residual -= CordicAtan[i]
            else
                X += StepY
                Y -= StepX
                Residual += CordicAtan[i]
            end
        end

        if Negate then
            X = -X
        end

        return Floor((Y + CordicRound) / CordicDown), Floor((X + CordicRound) / CordicDown)
    end

    Fixed.Sin = function(Angle)
        local Sine, _ = Fixed.SinCos(Angle)

        return Sine
    end

    Fixed.Cos = function(Angle)
        local _, Cosine = Fixed.SinCos(Angle)

        return Cosine
    end

    Fixed.Tan = function(Angle)
        local Sine, Cosine = Fixed.SinCos(Angle)

        return Fixed.Div(Sine, Cosine)
    end

    Fixed.Atan2 = function(Y, X)
        if X == 0 and Y == 0 then
            return 0
        end

        local Offset = 0

        if X < 0 then
            Offset = Y >= 0 and Pi or -Pi
            X = -X
            Y = -Y
        end

        local Scale = X > 0 and X or -X
        local Height = Y > 0 and Y or -Y

        if Height > Scale then
            Scale = Height
        end

        while Scale < CordicNorm do
            X += X
            Y += Y
            Scale += Scale
        end

        local Angle = 0

        for i = 1, CordicSteps do
            local Shift = CordicShift[i]
            local StepX = Floor(X / Shift)
            local StepY = Floor(Y / Shift)

            if Y >= 0 then
                X += StepY
                Y -= StepX
                Angle += CordicAtan[i]
            else
                X -= StepY
                Y += StepX
                Angle -= CordicAtan[i]
            end
        end

        return Floor((Angle + CordicRound) / CordicDown) + Offset
    end

    Fixed.Atan = function(Value)
        return Fixed.Atan2(Value, One)
    end

    Fixed.Asin = function(Value)
        if Value >= One then
            return HalfPi
        end

        if Value <= -One then
            return -HalfPi
        end

        return Fixed.Atan2(Value, Fixed.Sqrt(One - Fixed.Mul(Value, Value)))
    end

    Fixed.Acos = function(Value)
        if Value >= One then
            return 0
        end

        if Value <= -One then
            return Pi
        end

        return Fixed.Atan2(Fixed.Sqrt(One - Fixed.Mul(Value, Value)), Value)
    end
end


-- Vec2
do
    Vec2.New = function(X, Y)
        return {X = X or 0, Y = Y or 0}
    end

    Vec2.FromNumbers = function(X, Y)
        return {X = Fixed.FromNumber(X), Y = Fixed.FromNumber(Y)}
    end

    Vec2.Zero = function()
        return {X = 0, Y = 0}
    end

    Vec2.Clone = function(Vector)
        return {X = Vector.X, Y = Vector.Y}
    end

    Vec2.Add = function(Left, Right)
        return {X = Left.X + Right.X, Y = Left.Y + Right.Y}
    end

    Vec2.Sub = function(Left, Right)
        return {X = Left.X - Right.X, Y = Left.Y - Right.Y}
    end

    Vec2.Negate = function(Vector)
        return {X = -Vector.X, Y = -Vector.Y}
    end

    Vec2.Scale = function(Vector, Scalar)
        return {X = Fixed.Mul(Vector.X, Scalar), Y = Fixed.Mul(Vector.Y, Scalar)}
    end

    Vec2.Divide = function(Vector, Scalar)
        return {X = Fixed.Div(Vector.X, Scalar), Y = Fixed.Div(Vector.Y, Scalar)}
    end

    Vec2.Dot = function(Left, Right)
        return Fixed.Mul(Left.X, Right.X) + Fixed.Mul(Left.Y, Right.Y)
    end

    Vec2.Cross = function(Left, Right)
        return Fixed.Mul(Left.X, Right.Y) - Fixed.Mul(Left.Y, Right.X)
    end

    Vec2.MagnitudeSquared = function(Vector)
        return Fixed.Mul(Vector.X, Vector.X) + Fixed.Mul(Vector.Y, Vector.Y)
    end

    Vec2.Magnitude = function(Vector)
        return Fixed.Sqrt(Vec2.MagnitudeSquared(Vector))
    end

    Vec2.Unit = function(Vector)
        local Length = Vec2.Magnitude(Vector)

        if Length == 0 then
            return {X = 0, Y = 0}
        end

        return {X = Fixed.Div(Vector.X, Length), Y = Fixed.Div(Vector.Y, Length)}
    end

    Vec2.Distance = function(Left, Right)
        return Vec2.Magnitude(Vec2.Sub(Left, Right))
    end

    Vec2.Lerp = function(From, To, Alpha)
        return {X = Fixed.Lerp(From.X, To.X, Alpha), Y = Fixed.Lerp(From.Y, To.Y, Alpha)}
    end

    Vec2.Rotate = function(Vector, Angle)
        local Sine, Cosine = Fixed.SinCos(Angle)

        return {
            X = Fixed.Mul(Vector.X, Cosine) - Fixed.Mul(Vector.Y, Sine),
            Y = Fixed.Mul(Vector.X, Sine) + Fixed.Mul(Vector.Y, Cosine)
        }
    end

    Vec2.Angle = function(Vector)
        return Fixed.Atan2(Vector.Y, Vector.X)
    end

    Vec2.Equals = function(Left, Right)
        return Left.X == Right.X and Left.Y == Right.Y
    end

    Vec2.ToString = function(Vector)
        return Format("(%s, %s)", Fixed.ToString(Vector.X), Fixed.ToString(Vector.Y))
    end
end


-- Vec3
do
    Vec3.New = function(X, Y, Z)
        return {X = X or 0, Y = Y or 0, Z = Z or 0}
    end

    Vec3.FromNumbers = function(X, Y, Z)
        return {X = Fixed.FromNumber(X), Y = Fixed.FromNumber(Y), Z = Fixed.FromNumber(Z)}
    end

    Vec3.Zero = function()
        return {X = 0, Y = 0, Z = 0}
    end

    Vec3.Clone = function(Vector)
        return {X = Vector.X, Y = Vector.Y, Z = Vector.Z}
    end

    Vec3.Add = function(Left, Right)
        return {X = Left.X + Right.X, Y = Left.Y + Right.Y, Z = Left.Z + Right.Z}
    end

    Vec3.Sub = function(Left, Right)
        return {X = Left.X - Right.X, Y = Left.Y - Right.Y, Z = Left.Z - Right.Z}
    end

    Vec3.Negate = function(Vector)
        return {X = -Vector.X, Y = -Vector.Y, Z = -Vector.Z}
    end

    Vec3.Scale = function(Vector, Scalar)
        return {
            X = Fixed.Mul(Vector.X, Scalar),
            Y = Fixed.Mul(Vector.Y, Scalar),
            Z = Fixed.Mul(Vector.Z, Scalar)
        }
    end

    Vec3.Divide = function(Vector, Scalar)
        return {
            X = Fixed.Div(Vector.X, Scalar),
            Y = Fixed.Div(Vector.Y, Scalar),
            Z = Fixed.Div(Vector.Z, Scalar)
        }
    end

    Vec3.Dot = function(Left, Right)
        return Fixed.Mul(Left.X, Right.X) + Fixed.Mul(Left.Y, Right.Y) + Fixed.Mul(Left.Z, Right.Z)
    end

    Vec3.Cross = function(Left, Right)
        return {
            X = Fixed.Mul(Left.Y, Right.Z) - Fixed.Mul(Left.Z, Right.Y),
            Y = Fixed.Mul(Left.Z, Right.X) - Fixed.Mul(Left.X, Right.Z),
            Z = Fixed.Mul(Left.X, Right.Y) - Fixed.Mul(Left.Y, Right.X)
        }
    end

    Vec3.MagnitudeSquared = function(Vector)
        return Fixed.Mul(Vector.X, Vector.X)
            + Fixed.Mul(Vector.Y, Vector.Y)
            + Fixed.Mul(Vector.Z, Vector.Z)
    end

    Vec3.Magnitude = function(Vector)
        return Fixed.Sqrt(Vec3.MagnitudeSquared(Vector))
    end

    Vec3.Unit = function(Vector)
        local Length = Vec3.Magnitude(Vector)

        if Length == 0 then
            return {X = 0, Y = 0, Z = 0}
        end

        return {
            X = Fixed.Div(Vector.X, Length),
            Y = Fixed.Div(Vector.Y, Length),
            Z = Fixed.Div(Vector.Z, Length)
        }
    end

    Vec3.Distance = function(Left, Right)
        return Vec3.Magnitude(Vec3.Sub(Left, Right))
    end

    Vec3.Lerp = function(From, To, Alpha)
        return {
            X = Fixed.Lerp(From.X, To.X, Alpha),
            Y = Fixed.Lerp(From.Y, To.Y, Alpha),
            Z = Fixed.Lerp(From.Z, To.Z, Alpha)
        }
    end

    Vec3.Equals = function(Left, Right)
        return Left.X == Right.X and Left.Y == Right.Y and Left.Z == Right.Z
    end

    Vec3.ToVector3 = function(Vector)
        return Vector3.new(
            Fixed.ToNumber(Vector.X),
            Fixed.ToNumber(Vector.Y),
            Fixed.ToNumber(Vector.Z)
        )
    end

    Vec3.FromVector3 = function(Value)
        return {
            X = Fixed.FromNumber(Value.X),
            Y = Fixed.FromNumber(Value.Y),
            Z = Fixed.FromNumber(Value.Z)
        }
    end

    Vec3.ToString = function(Vector)
        return Format(
            "(%s, %s, %s)",
            Fixed.ToString(Vector.X),
            Fixed.ToString(Vector.Y),
            Fixed.ToString(Vector.Z)
        )
    end
end


-- Hash
do
    Hash.Multiply = function(State, Prime)
        local High = Floor(State / One)
        local Low = State - High * One

        return ((High * Prime % One) * One + Low * Prime) % HashWrap
    end

    Hash.New = function()
        return {State = HashBasis, Count = 0}
    end

    Hash.Reset = function(Digest)
        Digest.State = HashBasis
        Digest.Count = 0
    end

    Hash.PushInt = function(Digest, Value)
        local Remaining = Value % HashWrap
        local State = Digest.State

        for i = 1, 4 do
            local Byte = Remaining % 256
            Remaining = Floor(Remaining / 256)

            State = Hash.Multiply(Bxor(State, Byte), HashPrime)
        end

        Digest.State = State
        Digest.Count += 1

        return State
    end

    Hash.PushFixed = function(Digest, Value)
        return Hash.PushInt(Digest, Value)
    end

    Hash.PushVec2 = function(Digest, Vector)
        Hash.PushInt(Digest, Vector.X)

        return Hash.PushInt(Digest, Vector.Y)
    end

    Hash.PushVec3 = function(Digest, Vector)
        Hash.PushInt(Digest, Vector.X)
        Hash.PushInt(Digest, Vector.Y)

        return Hash.PushInt(Digest, Vector.Z)
    end

    Hash.Digest = function(Digest)
        return Digest.State
    end

    Hash.ToString = function(Digest)
        return Format("%08x", Digest.State)
    end
end


-- Random
do
    Random.Seed = 2463534242

    Random.New = function(Seed)
        local State = Floor(Seed or Random.Seed) % HashWrap

        if State == 0 then
            State = Random.Seed
        end

        return {State = State, Count = 0}
    end

    Random.Clone = function(Generator)
        return {State = Generator.State, Count = Generator.Count}
    end

    Random.Next = function(Generator)
        local State = Generator.State

        State = Bxor(State, Lshift(State, 13))
        State = Bxor(State, Rshift(State, 17))
        State = Bxor(State, Lshift(State, 5))

        Generator.State = State
        Generator.Count += 1

        return State
    end

    Random.NextFixed = function(Generator)
        return Rshift(Random.Next(Generator), 16)
    end

    Random.NextRange = function(Generator, Low, High)
        return Low + Fixed.Mul(High - Low, Random.NextFixed(Generator))
    end

    Random.NextInt = function(Generator, Low, High)
        local Span = High - Low + 1

        if Span <= 0 then
            return Low
        end

        return Low + Random.Next(Generator) % Span
    end

    Random.NextSign = function(Generator)
        return Random.Next(Generator) % 2 == 0 and One or -One
    end

    Random.NextUnit2 = function(Generator)
        local Angle = Random.NextRange(Generator, 0, TwoPi)
        local Sine, Cosine = Fixed.SinCos(Angle)

        return {X = Cosine, Y = Sine}
    end
end


-- Exports
FixedMath.Fixed = Fixed
FixedMath.Vec2 = Vec2
FixedMath.Vec3 = Vec3
FixedMath.Hash = Hash
FixedMath.Random = Random

return FixedMath
