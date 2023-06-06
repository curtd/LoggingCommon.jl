const LogLevelIntType = fieldtype(LogLevel, :level)

const NotSet = LogLevel(typemin(LogLevelIntType))

const All = NotSet + 1
if VERSION < v"1.8"
    const Debug = Logging.Debug
    const Info = Logging.Info 
    const Error = Logging.Error
    const Warn = Logging.Warn
end
const Trace = Debug - 1
const Notice = Info + 1 
const Critical = Error + 1 
const Alert = Error + 10
const Emergency = Error + 100

const Off = LogLevel(typemax(LogLevelIntType))

const Fatal = Off - 2
const AboveMax = Off - 1

for L in (:NotSet, :All, :Off, :Trace, :Notice, :Critical, :Alert, :Emergency, :AboveMax, :Fatal)
    L_name = string(L)
    @eval begin 
    @doc """
        $($L_name)


        Alias for [`$($L)`](@ref LogLevel)""" $L
    end
end

const symbol_to_log_levels = dictionary([
                                        :not_set => NotSet,
                                        :all => All,
                                        :trace => Trace, 
                                        :debug => Debug,
                                        :info => Info,
                                        :notice => Notice,
                                        :warn => Warn, 
                                        :error => Error,
                                        :critical => Critical,
                                        :alert => Alert,
                                        :emergency => Emergency,
                                        :fatal => Fatal,
                                        :above_max => AboveMax,
                                        :off => Off
                                    ])
                                    
const log_level_to_symbol = dictionary((v => k for (k,v) in pairs(symbol_to_log_levels)))

"""
    available_named_log_levels

Collection of named log levels as `Symbol`s.

Consists of $(available_named_log_levels)
"""
const available_named_log_levels = Set(keys(symbol_to_log_levels))

"""
    available_log_levels

Collection of named log levels as `LogLevel`s
"""
const available_log_levels = Set(values(symbol_to_log_levels))

const cached_levels = Dict{LogLevel, Symbol}()

"""
    nearest_log_level(input::LogLevel) -> Symbol 

Returns the first named log level `L` with `log_level(L) ≥ input`
"""
function nearest_log_level(input::LogLevel)
    return get!(cached_levels, input) do 
        log_level_to_symbol[findfirst(≥(input), keys(log_level_to_symbol))]
    end
end

"""
    log_level(level) -> LogLevel

Converts the input `level` to a `LogLevel` type
"""
function log_level end 

log_level(level::LogLevel) = level

log_level(level) = convert(LogLevel, level)

struct UnknownLogLevelException <: Exception
    l::Symbol
end

Base.showerror(io::IO, e::UnknownLogLevelException) = print(io, "Unknown log level $(e.l) - must be one of $(available_named_log_levels)")

"""
    is_valid_log_level(level::Symbol) -> Bool 

Returns `true` if `level` is a known log level 
"""
is_valid_log_level(l::Symbol) = l in available_named_log_levels

"""
    validate_log_level(level::Symbol)

Throws an `UnknownLogLevelException` if `level` is not a known named log level. Otherwise, returns `nothing`.
"""
function validate_log_level(l::Symbol) 
    !is_valid_log_level(l) && throw(UnknownLogLevelException(l))
    return nothing
end

function log_level(l::Symbol)
    validate_log_level(l)
    return symbol_to_log_levels[l]
end

"""
    NamedLogLevel(name::Symbol)

Represents a logging level with an associated `name`
"""
struct NamedLogLevel
    name::Symbol
    function NamedLogLevel(level::Symbol)
        validate_log_level(level)
        return new(level)
    end
end

NamedLogLevel(l::NamedLogLevel) = l

Base.string(l::NamedLogLevel) = string(l.name)

log_level(l::NamedLogLevel) = symbol_to_log_levels[l.name]

"""
    log_level_name(level) -> String 

Returns the name associated with `level` as a `String`
"""
log_level_name(l::NamedLogLevel) = string(l)

function log_level_name(l::Symbol)
    validate_log_level(l)
    return string(l)
end

Base.convert(::Type{LogLevel}, l::NamedLogLevel) = log_level(l)
