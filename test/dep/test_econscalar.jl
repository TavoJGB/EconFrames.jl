# Tests for EconScalar type

function test_econscalar_construction()
    @testset "EconScalar Construction" begin
        # Basic construction
        s1 = EconScalar(100.0, Annual(), Household())
        @test s1.value == 100.0
        @test frequency(s1) == Annual()
        @test subject(s1) == Household()
        
        # Different frequencies
        s2 = EconScalar(50.0, Quarterly(), Individual())
        @test frequency(s2) == Quarterly()
        @test subject(s2) == Individual()
        
        # Integer values
        s3 = EconScalar(42, Annual(), Household())
        @test s3.value == 42
        @test s3 isa EconScalar{Int, Annual, Household}
    end
end

function test_econscalar_arithmetic()
    @testset "EconScalar Arithmetic" begin
        s1 = EconScalar(100.0, Annual(), Household())
        s2 = EconScalar(50.0, Annual(), Household())
        
        # Addition
        s3 = s1 + s2
        @test s3.value == 150.0
        @test frequency(s3) == Annual()
        @test subject(s3) == Household()
        
        # Subtraction
        s4 = s1 - s2
        @test s4.value == 50.0
        
        # Multiplication
        s5 = s1 * s2
        @test s5.value == 5000.0
        
        # Division
        s6 = s1 / s2
        @test s6.value == 2.0
        
        # Scalar operations
        s7 = s1 + 10
        @test s7.value == 110.0
        
        s8 = s1 * 2
        @test s8.value == 200.0
        
        # Negation
        s9 = -s1
        @test s9.value == -100.0
    end
end

function test_econscalar_comparison()
    @testset "EconScalar Comparison" begin
        s1 = EconScalar(100.0, Annual(), Household())
        s2 = EconScalar(50.0, Annual(), Household())
        s3 = EconScalar(100.0, Annual(), Household())
        
        # Equality
        @test s1 == s3
        @test s1 != s2
        @test s1 == 100.0
        @test 100.0 == s1
        
        # Ordering
        @test s2 < s1
        @test s1 > s2
        @test s1 >= s3
        @test s2 <= s1
        
        # isequal
        @test isequal(s1, s3)
        @test !isequal(s1, s2)
    end
end
