function module_str_trim_main(_module::Module)
    name = fullname(_module)
    if first(name) == :Main && length(name) > 1
        return join(name[2:length(name)], '.')
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
    function StaticLogRecordMetadata(source::String, level::LogLevel, level_name::String, filename::String, line_num::Int, group, id)
        return new(intern(source), level, intern(level_name), intern(filename), line_num, group, id)
    end
end
@define_interface StaticLogRecordMetadata interface=equality

log_level(meta::StaticLogRecordMetadata) = meta.level
log_level_name(meta::StaticLogRecordMetadata) = meta.level_name

_filename(line::LineNumberNode) = !isnothing(line.file) ? string(line.file) : nothing

function StaticLogRecordMetadata(source::AbstractString, level::LogLevel, level_name::String, filename::Union{String, Nothing}, line_num::Union{Int, Nothing}, group=nothing, id=nothing) 
    return StaticLogRecordMetadata(string(source), level, level_name, something(filename, i""), something(line_num, 0), group, id)
end

StaticLogRecordMetadata(source::AbstractString, level::LogLevel, lnn::LineNumberNode, args...) = StaticLogRecordMetadata(source, level, i"", _filename(lnn), lnn.line, args...)

StaticLogRecordMetadata(source::AbstractString, level::LogLevel, filename::Union{String, Nothing}, line_num, args...) = StaticLogRecordMetadata(source, level, string(nearest_log_level(level)), filename, line_num, args...)

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
@define_interface RuntimeLogRecordMetadata interface=equality
function RuntimeLogRecordMetadata(; datetime::DateTime=Dates.now(), thread_id::Int=Threads.threadid(), worker_id::Int=Distributed.myid())
    return RuntimeLogRecordMetadata(datetime, thread_id, worker_id)
end

"""
    LogRecordData(data)

    LogRecordData(args::Pair{<:Any, <:Any}...)

A type representing an optional collection of `key => value` pairs attached to a log record. 

`data` must be an iterable collection where each element is a `Pair`
"""
struct LogRecordData{K}
    data::Dictionary{K, Any}
    LogRecordData{K}() where {K} = new(Dictionary{K, Any}())
end
@define_interface LogRecordData interface=equality
@forward_methods LogRecordData field=data Base.isempty(_) Base.length(_) Base.pairs(_) Base.get(_, key, default) Base.haskey(_, key)
Base.eltype(::Type{LogRecordData{K}}) where {K} = Pair{K, Any} 
Base.iterate(d::LogRecordData) = iterate(pairs(d.data))
Base.iterate(d::LogRecordData, st) = iterate(pairs(d.data), st)
Base.collect(d::LogRecordData) = collect(pairs(d.data))
Base.@propagate_inbounds Base.getindex(d::LogRecordData, key) = getindex(d.data, key)

"""
    add_record_data!(r, data::Pair)

Adds the `data := key => value` pair to `r`
"""
add_record_data!(d::LogRecordData{K}, data::Pair{K, <:Any}) where {K}  = (set!(d.data, first(data), last(data)); nothing)

add_record_data!(d::LogRecordData{K}, data::Pair) where {K} = add_record_data!(d, convert(K, first(data))::K => last(data))

function _log_record_data(KeyType, kv_pairs; exclude=())
    d = LogRecordData{KeyType}()
    _exclude = (exclude isa Tuple || exclude isa Vector) ? exclude : (exclude,)
    for (k, v) in kv_pairs 
        if k ∉ _exclude
            set!(d.data, k, v)
        end
    end
    return d
end
key_type(::Type{Pair{K, V}}) where {K, V} = K

"""
    log_record_data([KeyType], kv_pairs; [exclude=()]) -> LogRecordData

Returns a `LogRecordData` from the input `key::KeyType => value` pairs.

If `KeyType` is not provided, it will be inferred from a set of non-empty `kv_pairs`.
"""
log_record_data(KeyType::Type, kv_pairs; kwargs...) = _log_record_data(KeyType, kv_pairs; kwargs...)

function log_record_data(kv_pairs; kwargs...) 
    KT = mapfoldl(key_type ∘ typeof, promote_type, kv_pairs; init=Union{})
    return log_record_data(KT, kv_pairs; kwargs...)
end

"""
    log_record_data() -> LogRecordData{Symbol}

"""
log_record_data() = _log_record_data(Symbol, ())

LogRecordData(::Nothing; kwargs...) = _log_record_data(Symbol, (); kwargs...)
LogRecordData(data; kwargs...) = log_record_data(data; kwargs...)
LogRecordData(args::Pair...; kwargs...) = log_record_data(args; kwargs...)



"""
    AbstractLogRecord 

Abstract supertype of all log records 
"""
abstract type AbstractLogRecord end 

"""
    log_record_data(record)

Returns an iterator over the `key` => `value` pairs associated with `record`
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
@define_interface LogRecord interface=equality
@forward_methods LogRecord field=data add_record_data!(_, data)

Base.propertynames(::LogRecord{R}) where {R} = (fieldnames(LogRecord)..., fieldnames(R)...)

function Base.getproperty(l::LogRecord, name::Symbol)
    if name === :static_meta || name === :runtime_meta || name === :data || name === :record
        return getfield(l, name)
    else
        return getproperty(getfield(l, :record), name)
    end
end

LogRecord(static_meta::StaticLogRecordMetadata, runtime_meta::RuntimeLogRecordMetadata, record::AbstractLogRecord, data::LogRecordData) = LogRecord{typeof(record)}(static_meta, runtime_meta, data, record)

LogRecord(static_meta::StaticLogRecordMetadata, runtime_meta::RuntimeLogRecordMetadata,  record::AbstractLogRecord, arg1::Pair{<:Any,<:Any}, args::Pair{<:Any, <:Any}...) = LogRecord(static_meta, runtime_meta, record, log_record_data((arg1, args...)))

LogRecord(static_meta::StaticLogRecordMetadata, runtime_meta::RuntimeLogRecordMetadata, record::AbstractLogRecord, DataKeyType::Type=Symbol) = LogRecord(static_meta, runtime_meta, record, log_record_data(DataKeyType, ()))

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
@define_interface MessageLogRecord interface=equality

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
@define_interface StacktraceLogRecord interface=equality

stacktrace_log_record(static_meta::StaticLogRecordMetadata, stacktrace::Base.StackTraces.StackTrace, args...; exception::Union{Nothing,Exception}=nothing, kwargs...) = LogRecord(static_meta, StacktraceLogRecord(exception, stacktrace), args...; kwargs...)

stacktrace_log_record(static_meta::StaticLogRecordMetadata, bt::Vector, args...; kwargs...) = stacktrace_log_record(static_meta, stacktrace(bt), args...; kwargs...)

is_error_record(r::StacktraceLogRecord) = true