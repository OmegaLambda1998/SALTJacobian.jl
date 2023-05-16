@testset verbose = true "Arguments" begin
    @testset verbose = true "Batch Mode" begin
        args = String["--batch"]
        @testset "Invalid Arguments" begin
            # Missing --yaml
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Must specify a yaml path via --yaml/-y when in batch mode") main(args)
            push!(args, "--yaml")
            push!(args, joinpath(@__DIR__, "Outputs/arg_tests/batch_mode_invalid/batch_mode_invalid.yaml"))

            # Missing --output
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Must specify an output directory via --output/-o when in batch mode") main(args)
            push!(args, "--output")
            push!(args, "Outputs/arg_tests/batch_mode_invalid/")

            # Missing --jacobian
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Must specify a pretrained jacobian matrix via --jacobian/-j when in batch mode") main(args)
            push!(args, "--jacobian")
            push!(args, "does_not_exist.fits")

            # --jacobian does not exist
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Pretrained jacobian matrix does_not_exist.fits does not exist") main(args)
            args[end] = "Inputs/arg_tests/batch_mode_invalid_jacobian.fits"

            # Missing --base
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Must specify a base (unperturbed) surface via --base/-b when in batch mode") main(args)
            push!(args, "--base")
            push!(args, "does_not_exist")

            # --base does not exist
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Base surface does_not_exist does not exist") main(args)
            args[end] = "Inputs/arg_tests/batch_mode_invalid_base_surface/"

            # Missing --trainopt
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("Must specify trainopt via --trainopt/-t when in batch mode") main(args)
            push!(args, "--trainopt")
            args = vcat(args, "\"MAGSHIFT Instrument Filter 0.01\"")
        end
    end

    @testset verbose = true "Input Mode" begin
        @testset "Invalid Arguments" begin
            args = String[]
            @test_throws ArgumentError main(args)
            @test_throws ArgumentError("If not working in batch mode, must specify an input file!") main(args)
        end
    end
end
