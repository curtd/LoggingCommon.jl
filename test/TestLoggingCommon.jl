module TestLoggingCommon 
    using LoggingCommon
    using LoggingCommon.Logging, LoggingCommon.Dates
    using TestingUtilities, Test 

    @testset "Levels" begin 
        @test_cases begin 
            input      |    output 
            :not_set   |    NotSet 
            :all       |    All 
            :trace     |    Trace 
            :debug     |    Debug 
            :info      |    Info 
            :notice    |    Notice 
            :warn      |    Warn 
            :error     |    Error 
            :critical  |    Critical 
            :alert     |    Alert 
            :emergency |    Emergency
            :fatal     |    Fatal 
            :above_max |    AboveMax 
            :off       |    Off 
            @test is_valid_log_level(input)
            @test isnothing(validate_log_level(input))
            @test log_level(NamedLogLevel(input)) == output
            @test convert(LogLevel, NamedLogLevel(input)) == output
        end
        @test_throws UnknownLogLevelException validate_log_level(NamedLogLevel(:bad_level))
        @test_cases begin 
            input      |  output 
            Info       |  :info 
            Info - 1   |  :info 
            NotSet     |  :not_set 
            NotSet + 1 |  :all 
            All + 1    |  :trace
            AboveMax   |  :above_max                
            Off        |  :off
            @test nearest_log_level(input) == output
        end
    end
    @testset "Records" begin 
        @testset "Utilties" begin 
            @test_cases begin 
                input         | output 
                Main          | "Main"
                Main.Test     | "Test"
                LoggingCommon | "LoggingCommon"
                @test LoggingCommon.module_str_trim_main(input) == output
            end
        end
        @testset "StaticLogRecordMetadata" begin 
            r = StaticLogRecordMetadata("source", LogLevel(0), "level_name", "filename", 1, "group", "id")
            @test log_level(r) == LogLevel(0)
            @test log_level_name(r) == "level_name"
            r = StaticLogRecordMetadata("source", NamedLogLevel(:info), "filename", 1, "group", "id")
            @test log_level(r) == Info
            @test log_level_name(r) == "info"
            
        end
        @testset "RuntimeLogRecordMetadata" begin 
            datetime = DateTime(2023, 1, 1)
            thread_id = 2
            worker_id = 2
            r = RuntimeLogRecordMetadata(; datetime, thread_id, worker_id)
            @Test r.thread_id == thread_id 
            @Test r.worker_id == worker_id
            @Test r.datetime == datetime 
            s = RuntimeLogRecordMetadata()
            sleep(0.01)
            @Test s.thread_id == Threads.threadid()
            @Test s.worker_id == 1
            @Test s.datetime < Dates.now()
        end
        @testset "LogRecordData" begin 
            d = LogRecordData()
            @Test isnothing(Base.iterate(d))
            @Test isempty(Base.pairs(d)) 
            @Test isempty(d)
            @Test length(d) == 0 
            d = LogRecordData(:a => 1)
            @Test Base.pairs(d) |> collect == [:a => 1]
            @Test Base.iterate(d) == (:a => 1, 1)
            @Test Base.iterate(d, 1) |> isnothing
            @Test !isempty(d)
            @Test length(d) == 1

            d = LogRecordData(:a => 1, :b => String)
            @Test length(d) == 2
            for (i, (k,v)) in enumerate(d)
                if i == 1
                    @Test k == :a 
                    @Test v == 1
                else
                    @Test k == :b 
                    @Test v == String 
                end
            end
            d = log_record_data(("a" => 1, "b" => 2); exclude="a")
            @Test collect(d) == ["b" => 2]
            @Test d == log_record_data(String, ("a" => 1, "b" => 2); exclude="a")
        end
        @testset "message_log_record" begin 
            static = StaticLogRecordMetadata(Main, NamedLogLevel(:info), "a.jl", 1, "group", "id")
            runtime_meta = RuntimeLogRecordMetadata()
            record = message_log_record(static, "Message"; runtime_meta)
            @test static_metadata(record) == static
            @test runtime_metadata(record) == runtime_meta
            @test log_level(record) == Info
            @test log_level_name(record) == "info"
            @test !is_error_record(record)
            @test isempty(log_record_data(record))

            add_record_data!(record, :a => "1")
            @Test log_record_data(record) |> collect == [:a => "1"]
            add_record_data!(record, :b => true)
            @Test log_record_data(record) |> collect == [:a => "1", :b => true]

            static = StaticLogRecordMetadata(Main, NamedLogLevel(:error), "a.jl", 1, "group", "id")
            record = message_log_record(static, "Error message", :a => 1, :b => String)
            @test static_metadata(record) == static
            @test log_level(record) == Error
            @test log_level_name(record) == "error"
            @test is_error_record(record)
            @test !isempty(log_record_data(record))
            for (i, (k, v)) in enumerate(log_record_data(record))
                if i == 1
                    @test k == :a 
                    @test v == 1 
                else
                    @test k == :b 
                    @test v == String 
                end
            end
        end
        @testset "stacktrace_log_record" begin 
            static = StaticLogRecordMetadata(Main, NamedLogLevel(:info), "a.jl", 1, "group", "id")
            runtime_meta = RuntimeLogRecordMetadata()
            f = () -> begin 
                try 
                    error()
                catch 
                    return catch_backtrace()
                end
            end
            bt = f()
            record = stacktrace_log_record(static, bt; runtime_meta)
            @test static_metadata(record) == static
            @test runtime_metadata(record) == runtime_meta
            @test log_level(record) == Info
            @test log_level_name(record) == "info"
            @test is_error_record(record)
            @test isempty(log_record_data(record))
            @test isnothing(record.record.exception)
            exception = ErrorException("")

            record = stacktrace_log_record(static, bt; exception, runtime_meta)
            @test record.record.exception == exception
        end
    end
end