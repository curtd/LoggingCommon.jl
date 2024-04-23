module LoggingCommon 

    using Dates, Dictionaries, Distributed, ForwardMethods, Logging, InternedStrings, PrecompileTools

    # Log levels 
    export NotSet, All, Trace,Notice, Critical, Alert, Emergency, Fatal, AboveMax, Off

    # Reexport Base.Logging levels 
    export Debug, Info, Warn, Error

    export UnknownLogLevelException

    export NamedLogLevel

    export log_level, log_level_name, is_valid_log_level, validate_log_level, nearest_log_level

    # Log records 
    export StaticLogRecordMetadata, RuntimeLogRecordMetadata, LogRecordData

    export AbstractLogRecord, LogRecord, MessageLogRecord, StacktraceLogRecord

    export message_log_record, stacktrace_log_record, add_record_data!

    export log_record_data, static_metadata, runtime_metadata, is_error_record

    # Part of the public API but not exported
    # 
    # Constants:
    #   available_log_levels, available_named_log_levels

    include("levels.jl")

    include("records.jl")

    include("precompile.jl")

end