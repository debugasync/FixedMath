-- FixedMath / Tests

-- Variables
local FixedMath = require(script.Parent)

local Fixed = FixedMath.Fixed
local Vec3 = FixedMath.Vec3
local Hash = FixedMath.Hash
local Random = FixedMath.Random

local Abs = math.abs
local Sin = math.sin
local Cos = math.cos
local Atan2 = math.atan2
local Sqrt = math.sqrt
local Format = string.format


-- Constants
local One = Fixed.One
local ExpectedDigest = 0


-- Namespaces
local Tests = {}


-- Accuracy
do
    Tests.Accuracy = function()
        local WorstSin = 0
        local WorstCos = 0
        local WorstAtan = 0
        local WorstSqrt = 0
        local WorstMul = 0

        for i = -2000, 2000 do
            local Angle = Fixed.Div(Fixed.FromInt(i) * 4, Fixed.FromInt(1000))
            local Sine, Cosine = Fixed.SinCos(Angle)
            local Real = Fixed.ToNumber(Angle)

            local SinError = Abs(Sin(Real) - Fixed.ToNumber(Sine))
            local CosError = Abs(Cos(Real) - Fixed.ToNumber(Cosine))

            if SinError > WorstSin then
                WorstSin = SinError
            end

            if CosError > WorstCos then
                WorstCos = CosError
            end
        end

        local Generator = Random.New(20260715)

        for i = 1, 4000 do
            local X = Random.NextRange(Generator, Fixed.FromInt(-64), Fixed.FromInt(64))
            local Y = Random.NextRange(Generator, Fixed.FromInt(-64), Fixed.FromInt(64))

            if X ~= 0 or Y ~= 0 then
                local Got = Fixed.ToNumber(Fixed.Atan2(Y, X))
                local Real = Atan2(Fixed.ToNumber(Y), Fixed.ToNumber(X))
                local AtanError = Abs(Real - Got)

                if AtanError > WorstAtan then
                    WorstAtan = AtanError
                end
            end

            local Value = Random.NextRange(Generator, 0, Fixed.FromInt(4096))
            local SqrtError = Abs(Sqrt(Fixed.ToNumber(Value)) - Fixed.ToNumber(Fixed.Sqrt(Value)))

            if SqrtError > WorstSqrt then
                WorstSqrt = SqrtError
            end

            local LeftValue = Random.NextRange(Generator, Fixed.FromInt(-128), Fixed.FromInt(128))
            local RightValue = Random.NextRange(Generator, Fixed.FromInt(-128), Fixed.FromInt(128))
            local MulError = Abs(
                Fixed.ToNumber(LeftValue) * Fixed.ToNumber(RightValue)
                    - Fixed.ToNumber(Fixed.Mul(LeftValue, RightValue))
            )

            if MulError > WorstMul then
                WorstMul = MulError
            end
        end

        print(Format("sin   %.8f  (%.2f lsb)", WorstSin, WorstSin * One))
        print(Format("cos   %.8f  (%.2f lsb)", WorstCos, WorstCos * One))
        print(Format("atan2 %.8f  (%.2f lsb)", WorstAtan, WorstAtan * One))
        print(Format("sqrt  %.8f  (%.2f lsb)", WorstSqrt, WorstSqrt * One))
        print(Format("mul   %.8f  (%.2f lsb)", WorstMul, WorstMul * One))
    end
end


-- Simulation
do
    Tests.Simulate = function(Steps, Count)
        local Generator = Random.New(1337)
        local Gravity = Vec3.New(0, Fixed.FromNumber(-0.35), 0)
        local Delta = Fixed.FromNumber(0.05)
        local Bounce = Fixed.FromNumber(-0.6)
        local Ground = Fixed.FromInt(0)

        local Positions = {}
        local Velocities = {}

        for i = 1, Count do
            Positions[i] = Vec3.New(
                Random.NextRange(Generator, Fixed.FromInt(-32), Fixed.FromInt(32)),
                Random.NextRange(Generator, Fixed.FromInt(8), Fixed.FromInt(64)),
                Random.NextRange(Generator, Fixed.FromInt(-32), Fixed.FromInt(32))
            )

            Velocities[i] = Vec3.New(
                Random.NextRange(Generator, Fixed.FromInt(-4), Fixed.FromInt(4)),
                0,
                Random.NextRange(Generator, Fixed.FromInt(-4), Fixed.FromInt(4))
            )
        end

        for Step = 1, Steps do
            for i = 1, Count do
                local Velocity = Vec3.Add(Velocities[i], Vec3.Scale(Gravity, Delta))
                local Position = Vec3.Add(Positions[i], Vec3.Scale(Velocity, Delta))

                if Position.Y < Ground then
                    Position.Y = Ground
                    Velocity.Y = Fixed.Mul(Velocity.Y, Bounce)

                    local Spin = Fixed.Atan2(Velocity.Z, Velocity.X)
                    local Sine, Cosine = Fixed.SinCos(Spin + Fixed.QuarterPi)

                    Velocity.X = Fixed.Mul(Velocity.X, Cosine)
                    Velocity.Z = Fixed.Mul(Velocity.Z, Sine)
                end

                Velocities[i] = Velocity
                Positions[i] = Position
            end
        end

        local Digest = Hash.New()

        for i = 1, Count do
            Hash.PushVec3(Digest, Positions[i])
            Hash.PushVec3(Digest, Velocities[i])
        end

        return Hash.Digest(Digest), Positions, Velocities
    end
end


-- Determinism
do
    Tests.Determinism = function()
        local First = Tests.Simulate(600, 64)
        local Second = Tests.Simulate(600, 64)

        print(Format("digest a  %08x", First))
        print(Format("digest b  %08x", Second))
        print("repeatable", First == Second)

        if ExpectedDigest ~= 0 then
            print("matches expected", First == ExpectedDigest)
        end

        return First
    end
end


-- Run
do
    Tests.Run = function()
        print("FixedMath accuracy")
        Tests.Accuracy()

        print("FixedMath determinism")
        Tests.Determinism()
    end
end

return Tests
