# Tests for EconVariable type

function test_econvariable_construction()
    @testset "EconVariable Construction" begin
        # Basic construction
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        v1 = EconVariable(data, Annual(), Household())
        
        @test length(v1) == 5
        @test v1[1] == 1.0
        @test v1[end] == 5.0
        @test frequency(v1) == Annual()
        @test subject(v1) == Household()
        
        # Different frequencies and subjects
        v2 = EconVariable([10, 20, 30], Quarterly(), Individual())
        @test length(v2) == 3
        @test frequency(v2) == Quarterly()
        @test subject(v2) == Individual()
    end
end

function test_econvariable_arithmetic()
    @testset "EconVariable Arithmetic" begin
        v1 = EconVariable([10.0, 20.0, 30.0], Annual(), Household())
        v2 = EconVariable([5.0, 10.0, 15.0], Annual(), Household())
        
        # Addition
        v3 = v1 + v2
        @test v3.data == [15.0, 30.0, 45.0]
        @test frequency(v3) == Annual()
        
        # Subtraction
        v4 = v1 - v2
        @test v4.data == [5.0, 10.0, 15.0]
        
        # Multiplication
        v5 = v1 * v2
        @test v5.data == [50.0, 200.0, 450.0]
        
        # Division
        v6 = v1 / v2
        @test v6.data == [2.0, 2.0, 2.0]
        
        # Scalar operations
        v7 = v1 + 10
        @test v7.data == [20.0, 30.0, 40.0]
        
        v8 = v1 * 2
        @test v8.data == [20.0, 40.0, 60.0]
    end
end

function test_econvariable_broadcasting()
    @testset "EconVariable Broadcasting" begin
        v = EconVariable([10.0, 20.0, 30.0], Annual(), Household())
        
        # Broadcasting with scalars
        v2 = v .* 2
        @test v2.data == [20.0, 40.0, 60.0]
        @test v2 isa EconVariable
        @test frequency(v2) == Annual()
        
        v3 = v .+ 5
        @test v3.data == [15.0, 25.0, 35.0]
        
        # Broadcasting with vectors
        v4 = v .* [1, 2, 3]
        @test v4.data == [10.0, 40.0, 90.0]
    end
end

function test_econvariable_statistics()
    @testset "EconVariable Statistics" begin
        v = EconVariable([10.0, 20.0, 30.0, 40.0, 50.0], Annual(), Household())
        
        # Mean
        m = mean(v)
        @test m isa EconScalar
        @test m.value == 30.0
        @test frequency(m) == Annual()
        @test subject(m) == Household()
        
        # Median
        med = median(v)
        @test med.value == 30.0
        
        # Standard deviation
        s = std(v)
        @test s.value ≈ 15.811388300841896
        
        # Sum
        sum_v = sum(v)
        @test sum_v.value == 150.0
        
        # Min/Max
        min_v = minimum(v)
        @test min_v.value == 10.0
        
        max_v = maximum(v)
        @test max_v.value == 50.0
        
        # Quantile
        q = quantile(v, 0.5)
        @test q.value == 30.0
    end
end
