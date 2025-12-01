# Tests for MonetaryScalar type

function test_monetaryscalar_construction()
    @testset "MonetaryScalar Construction" begin
        # Nominal USD
        s1 = MonetaryScalar(50000.0, Annual(), Household(), NominalUSD())
        @test s1.value == 50000.0
        @test frequency(s1) == Annual()
        @test subject(s1) == Household()
        @test currency(s1) isa NominalUSD
        
        # Nominal EUR
        s2 = MonetaryScalar(40000.0, Quarterly(), Individual(), NominalEUR())
        @test currency(s2) isa NominalEUR
        
        # Real USD
        s3 = MonetaryScalar(55000.0, Annual(), Household(), RealUSD{1990}())
        @test currency(s3) isa RealUSD{1990}
        @test base_date(currency(s3)) == 1990
    end
end

function test_monetaryscalar_arithmetic()
    @testset "MonetaryScalar Arithmetic" begin
        s1 = MonetaryScalar(100.0, Annual(), Household(), NominalUSD())
        s2 = MonetaryScalar(50.0, Annual(), Household(), NominalUSD())
        
        # Addition
        s3 = s1 + s2
        @test s3.value == 150.0
        @test currency(s3) isa NominalUSD
        
        # Subtraction
        s4 = s1 - s2
        @test s4.value == 50.0
        
        # Multiplication
        s5 = s1 * 2
        @test s5.value == 200.0
        @test currency(s5) isa NominalUSD
        
        # Division
        s6 = s1 / 2
        @test s6.value == 50.0
    end
end

function test_monetaryscalar_currency()
    @testset "MonetaryScalar Currency" begin
        # Nominal currencies
        s_nom_usd = MonetaryScalar(1000.0, Annual(), Household(), NominalUSD())
        s_nom_eur = MonetaryScalar(900.0, Annual(), Household(), NominalEUR())
        
        @test currency(s_nom_usd) isa NominalCurrency
        @test currency(s_nom_eur) isa NominalCurrency
        
        # Real currencies
        s_real_usd = MonetaryScalar(1000.0, Annual(), Household(), RealUSD{2000}())
        s_real_eur = MonetaryScalar(900.0, Annual(), Household(), RealEUR{2000}())
        
        @test currency(s_real_usd) isa RealCurrency
        @test currency(s_real_eur) isa RealCurrency
        @test base_date(currency(s_real_usd)) == 2000
        @test base_date(currency(s_real_eur)) == 2000
    end
end
