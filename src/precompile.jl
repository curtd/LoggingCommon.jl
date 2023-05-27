@setup_workload begin 
    @compile_workload begin 
        for L in (Info, NamedLogLevel(:info), :info)
            log_level(L)
        end
        nearest_log_level(Info)
        log_level(:info)
        log_level(NamedLogLevel(:info))
        static_meta = StaticLogRecordMetadata(Main, NamedLogLevel(:info), "a.jl", 1, nothing, nothing)
        runtime_meta = RuntimeLogRecordMetadata()
        record = message_log_record(static_meta, "Hi"; runtime_meta)
        
        st = Base.StackTraces.StackTrace()
        exception = ErrorException("")
        stacktrace_log_record(static_meta, st; exception, runtime_meta)
    end
end
