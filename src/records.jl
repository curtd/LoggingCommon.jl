function module_str_trim_main(_module::Module)
    name = fullname(_module)
    if first(name) == :Main && length(name) > 1
        return join(name[2:end], '.')
    else
        return join(name, '.')
    end
end

"""
    StaticLogRecordMetadata(source::String, level::LogLevel, level_name::String, filename::Union{String,Nothing}, line_num::Int [, group=nothing] [, id=nothing])

Components of a generic log record that are known at compile time
"""
struct StaticLogRecordMetadata
    source::String
    level::LogLevel
    level_name::String
    filename::String
    line_num::Int
    group::Any
    id::Any
end

log_level(meta::StaticLogRecordMetadata) = meta.level
log_level_name(meta::StaticLogRecordMetadata) = meta.level_name

_filename(line::LineNumberNode) = !isnothing(line.file) ? string(line.file) : nothing

function StaticLogRecordMetadata(source::AbstractString, level::LogLevel, level_name::String, filename::Union{String, Nothing}, line_num::Int, group=nothing, id=nothing) 
    return StaticLogRecordMetadata(string(source), level, something(level_name, ""), something(filename, "?"), line_num, group, id)
end

StaticLogRecordMetadata(source::AbstractString, level, lnn::LineNumberNode, args...) = StaticLogRecordMetadata(source, level, "", _filename(lnn), lnn.line, args...)

StaticLogRecordMetadata(source::AbstractString, level::LogLevel, filename::Union{LineNumberNode, String, Nothing}, line_num::Union{LineNumberNode, Int}, args...) = StaticLogRecordMetadata(source, level, nearest_log_level(level), filename, line_num, args...)

StaticLogRecordMetadata(source::AbstractString, level::NamedLogLevel,  args...) = StaticLogRecordMetadata(source, log_level(level), string(level), args...)

StaticLogRecordMetadata(source::Module, args...) = StaticLogRecordMetadata(module_str_trim_main(source), args...)

"""
    RuntimeLogRecordMetadata(datetime::DateTime, thread_id::Int, worker_id::Int)

    RuntimeLogRecordMetadata(; datetime=Dates.now(), thread_id::Int=Threads.threadid(), worker_id::Int=_worker_id())

Components of a generic log record which are known at runtime
"""
struct RuntimeLogRecordMetadata 
    datetime::DateTime
    thread_id::Int
    worker_id::Int
end

function RuntimeLogRecordMetadata(; datetime::DateTime=Dates.now(), thread_id::Int=Threads.threadid(), worker_id::Int=Distributed.myid())
    return RuntimeLogRecordMetadata(datetime, thread_id, worker_id)
end

"""
    LogRecordData(data)

    LogRecordData(args::Pair{Symbol, <:Any}...)

A type representing an optional collection of `key => value` pairs attached to a log record.
"""
struct LogRecordData 
    data::Union{Nothing,Vector{Pair{Symbol, Any}}}
    function LogRecordData(d; exclude::Union{Symbol,Vector{Symbol}}=Symbol[])
        if !isnothing(d) && !isempty(d)
            _exclude = exclude isa Symbol ? [exclude] : exclude
            return new([convert(Pair{Symbol,Any}, di) for di in d if first(di) ∉ _exclude])
        else
            return new(nothing)
        end
    end
end
Base.isempty(l::LogRecordData) = isnothing(l.data) || isempty(l.data)
Base.length(l::LogRecordData) = isnothing(l.data) ? 0 : length(l.data)
Base.pairs(l::LogRecordData) = isnothing(l.data) ? pairs((;)) : l.data
Base.iterate(l::LogRecordData) = isnothing(l.data) ? nothing : iterate(l.data)
Base.iterate(l::LogRecordData, st) = isnothing(st) ? nothing : iterate(l.data, st)

function LogRecordData(args::Pair{Symbol, <:Any}...) 
    if !isempty(args)
        return LogRecordData(collect(args))
    else
        return LogRecordData(nothing)
    end
end

"""
    AbstractLogRecord 

Abstract supertype of all log records 
"""
abstract type AbstractLogRecord end 

"""
    log_record_data(record)

Returns the `key` => `value` pairs associated with `record`
"""
log_record_data(::AbstractLogRecord) = nothing

"""
    static_metadata(record) 

Returns the `StaticLogRecordMetadata` associated with `record` or `nothing` if it is not present
"""
static_metadata(::AbstractLogRecord) = nothing

"""
    runtime_metadata(record)

Returns the `RuntimeLogRecordMetadata` associated with `record` or `nothing` if it is not present
"""
runtime_metadata(::AbstractLogRecord) = nothing

"""
    is_error_record(record)

Returns `true` if `record` is a log record associated with an error/exception, `false` otherwise.
"""
is_error_record(record) = false 

for (f, default) in ((:log_level, :NotSet), (:log_level_name, ""))
    @eval begin 
        function $f(r::AbstractLogRecord)
            static = static_metadata(r)
            return !isnothing(static) ? $f(static) : $default
        end
    end
end


"""
    LogRecord(static_meta, runtime_meta, record, data)

    LogRecord(static_meta, runtime_meta, record, args...)

    LogRecord(static_meta, record, args...; runtime_meta=RuntimeLogRecordMetadata())

A log record with an associated `StaticLogRecordMetadata`, `RuntimeLogRecordMetadata`, `LogRecordData` and an underlying `record`. If `data` is not provided, it is constructed from `args...`. 

# Arguments 
- `static_meta::StaticLogRecordMetadata` - Static log record metadata 
- `runtime_meta::RuntimeLogRecordMetadata` - Runtime log record metadata 
- `record::AbstractLogRecord` - Underlying record
- `data::LogRecordData` - Optional `key` => `value` pairs attached to record. Constructed from `args...` if not provided. 

"""
struct LogRecord{R} <: AbstractLogRecord
    static_meta::StaticLogRecordMetadata
    runtime_meta::RuntimeLogRecordMetadata
    data::LogRecordData
    record::R
end

function Base.getproperty(l::LogRecord, name::Symbol)
    if name === :static_meta || name === :runtime_meta || name === :data || name === :record
        return getfield(l, name)
    else
        return getproperty(getfield(l, :record), name)
    end
end

LogRecord(static_meta::StaticLogRecordMetadata, runtime_meta::RuntimeLogRecordMetadata, record::AbstractLogRecord, data::LogRecordData) = LogRecord{typeof(record)}(static_meta, runtime_meta, data, record)

LogRecord(static_meta::StaticLogRecordMetadata, runtime_meta::RuntimeLogRecordMetadata,  record::AbstractLogRecord, args::Pair{Symbol, <:Any}...) = LogRecord(static_meta, runtime_meta, record, LogRecordData(args...))

LogRecord(static_meta::StaticLogRecordMetadata, record::AbstractLogRecord, args...;  runtime_meta::RuntimeLogRecordMetadata=RuntimeLogRecordMetadata()) = LogRecord(static_meta, runtime_meta, record, args...)

is_error_record(r::LogRecord) = log_level(r) ≥ Error || is_error_record(r.record) 
log_record_data(r::LogRecord) = r.data
static_metadata(r::LogRecord) = r.static_meta
runtime_metadata(r::LogRecord) = r.runtime_meta

"""
    MessageLogRecord(message::AbstractString)

A type representing a log record with an associated `message` 

"""
struct MessageLogRecord <: AbstractLogRecord
    message::AbstractString
end

"""
    message_log_record(static_meta::StaticLogRecordMetadata, message::AbstractString, data; [runtime_meta = RuntimeLogRecordMetadata()])
"""
message_log_record(static_meta::StaticLogRecordMetadata,  message::AbstractString, args...; kwargs...) = LogRecord(static_meta, MessageLogRecord(message), args...; kwargs...)


"""
   StacktraceLogRecord(static_meta, runtime_meta, exception, stacktrace, data)
   StacktraceLogRecord(static_meta, stacktrace, data; runtime_meta=RuntimeLogRecordMetadata(), exception=nothing)
   StacktraceLogRecord(static_meta, stacktrace, args...; runtime_meta=RuntimeLogRecordMetadata(), exception=nothing)

An `AbstractLogRecord` type with an associated stacktrace and optional exception and a collection of key-value `data`. 

# Arguments 
- `static_meta::StaticLogRecordMetadata` - Static log record metadata 
- `runtime_meta[_metadata]::RuntimeLogRecordMetadata` - Runtime log record metadata 
- `exception::Union{Nothing,Exception}` - Exception for log record
- `stacktrace::Base.StackTraces.StackTrace` - Stacktrace for log record
- `data::LogRecordData` - Optional `key` => `value` pairs attached to record. Constructed from `args...` if not provided.
"""
struct StacktraceLogRecord <: AbstractLogRecord 
    exception::Union{Nothing,Exception}
    stacktrace::Base.StackTraces.StackTrace
end

stacktrace_log_record(static_meta::StaticLogRecordMetadata,  stacktrace::Base.StackTraces.StackTrace, args...; exception::Union{Nothing,Exception}=nothing, kwargs...) = LogRecord(static_meta, StacktraceLogRecord(exception, stacktrace), args...; kwargs...)

stacktrace_log_record(static_meta::StaticLogRecordMetadata, bt::Vector, args...; kwargs...) = stacktrace_log_record(static_meta, stacktrace(bt), args...; kwargs...)

is_error_record(r::StacktraceLogRecord) = true