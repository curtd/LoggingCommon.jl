# LoggingCommon

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://curtd.github.io/LoggingCommon.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://curtd.github.io/LoggingCommon.jl/dev/)
[![Build Status](https://github.com/curtd/LoggingCommon.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/curtd/LoggingCommon.jl/actions/workflows/CI.yml?query=branch%3Amain)

Provides some definitions that are useful as the basis for creating a generic logging framework, slightly extending the types and methods introduced in [`Base.Logging`](https://docs.julialang.org/en/v1/stdlib/Logging/). 

## Log Message Levels
This package adds additional log level aliases to the standard ones from `Base.Logging`. In total, the available log levels are (in order) `NotSet`, `All`, `Trace`, `Debug`, `Info`, `Notice`, `Warn`, `Error`, `Critical`, `Alert`, `Emergency`, `Fatal`, `AboveMax`, and `Off`. 

These aliases can be represented as a `NamedLogLevel`, which maps a `Symbol` to a particular `Base.LogLevel` via the `log_level` function. 

```julia-repl
julia> using LoggingCommon

julia> l = NamedLogLevel(:alert); log_level(l)
LogLevel(2010)
```

## Log Records
The generic `LogRecord` type represents a generic logging record. It contains both the record itself, as well as static + runtime metatdata associated to it. This type can be used in a generic logging framework, such as [`LoggingExtras`](https://github.com/JuliaLogging/LoggingExtras.jl), to format log message outputs without extraneous logging boilerplate. 

Message records can be created via `message_log_record`, which associates a single `String` message to a log record. Stacktrace records can be created via `stacktrace_log_record`, which associates a `Base.StackTraces.StackTrace` (and an optional `Exception`) to a log record.  

For each log record, there are two types introduced representing metadata-values associated to a particular log record -- `StaticLogRecordMetadata` and `RuntimeLogRecordMetadata`. These types record log message information available at compile time (e.g., originating module, line number, etc., ) and at runtime (e.g., datetime, thread id, distributed worker id), respectively. 