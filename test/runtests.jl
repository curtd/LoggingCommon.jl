using Test 

using LoggingCommon

if VERSION ≥ v"1.9"
    using Aqua
    Aqua.test_all(LoggingCommon)
end

include("TestLoggingCommon.jl")