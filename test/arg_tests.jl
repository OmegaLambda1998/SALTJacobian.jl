@testset verbose = true "Arguments" begin
    @testset verbose = true "Batch Mode" begin
        args = String["--batch"]
        @testset "Invalid Arguments" begin
            # Missing --yaml
            @test_throws ArgumentError main(args)
            @test_throws "Must specify a yaml path" main(args)
            push!(args, "--yaml")
            push!(args, "Outputs/arg_tests/batch_mode_invalid/batch_mode_invalid.yaml")

            # Missing --output
            @test_throws ArgumentError main(args)
            @test_throws "Must specify an output directory" main(args)
            push!(args, "--output")
            push!(args, "Outputs/arg_tests/batch_mode_invalid/")
            
            # Missing --jacobian
            @test_throws ArgumentError main(args)
            @test_throws "Must specify a pretrained jacobian matrix" main(args)
            push!(args, "--jacobian")
            push!(args, "does_not_exist.fits")

            # --jacobian does not exist
            @test_throws ArgumentError main(args)
            @test_throws "does not exist" main(args)
            args[end] = "Inputs/arg_tests/batch_mode_invalid_jacobian.fits"

            # Missing --base
            @test_throws ArgumentError main(args)
            @test_throws "Must specify a base (unperturbed) surface" main(args)
            push!(args, "--base")
            push!(args, "does_not_exist")

            # --base does not exist
            @test_throws ArgumentError main(args)
            @test_throws "does not exist" main(args)
            args[end] = "Inputs/arg_tests/batch_mode_invalid_base_surface/"

            # Missing --trainopt
            @test_throws ArgumentError main(args)
            @test_throws "Must specify trainopt" main(args)
            push!(args, "--trainopt")
            args = vcat(args, "\"MAGSHIFT Instrument Filter 0.01\"")
        end
    end

    @testset verbose = true "Input Mode" begin
        @testset "Invalid Arguments" begin
            args = String[]
            @test_throws ArgumentError main(args)
            @test_throws "must specify an input file" main(args)
        end
    end
end
