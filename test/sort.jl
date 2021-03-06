module TestSort

using DataFrames, Random, Test, CategoricalArrays

@testset "standard tests" begin
    dv1 = [9, 1, 8, missing, 3, 3, 7, missing]
    dv2 = [9, 1, 8, missing, 3, 3, 7, missing]
    dv3 = Vector{Union{Int, Missing}}(1:8)
    cv1 = CategoricalArray(dv1, ordered=true)

    d = DataFrame(dv1 = dv1, dv2 = dv2, dv3 = dv3, cv1 = cv1)

    @test sortperm(d) == sortperm(dv1)
    @test sortperm(d[:, [:dv3, :dv1]]) == sortperm(dv3)
    @test sort(d, :dv1)[!, :dv3] == sort(d, "dv1")[!, "dv3"] == sortperm(dv1)
    @test sort(d, :dv2)[!, :dv3] == sortperm(dv1)
    @test sort(d, :cv1)[!, :dv3] == sortperm(dv1)
    @test sort(d, [:dv1, :cv1])[!, :dv3] == sortperm(dv1)
    @test sort(d, [:dv1, :dv3])[!, :dv3] == sortperm(dv1)

    df = DataFrame(rank=rand(1:12, 1000),
                   chrom=rand(1:24, 1000),
                   pos=rand(1:100000, 1000))

    @test issorted(sort(df))
    @test issorted(sort(df, rev=true), rev=true)
    @test issorted(sort(df, [:chrom,:pos])[:, [:chrom,:pos]])
    @test issorted(sort(df, ["chrom", "pos"])[:, ["chrom", "pos"]])

    ds = sort(df, [order(:rank, rev=true),:chrom,:pos])
    @test issorted(ds, [order(:rank, rev=true),:chrom,:pos])
    @test issorted(ds, rev=(true, false, false))

    ds = sort(df, [order("rank", rev=true), "chrom", "pos"])
    @test issorted(ds, [order("rank", rev=true), "chrom", "pos"])
    @test issorted(ds, rev=(true, false, false))

    ds2 = sort(df, [:rank, :chrom, :pos], rev=(true, false, false))
    @test issorted(ds2, [order(:rank, rev=true), :chrom, :pos])
    @test issorted(ds2, rev=(true, false, false))

    @test ds2 == ds

    ds2 = sort(df, ["rank", "chrom", "pos"], rev=(true, false, false))
    @test issorted(ds2, [order("rank", rev=true), "chrom", "pos"])
    @test issorted(ds2, rev=(true, false, false))

    @test ds2 == ds

    sort!(df, [:rank, :chrom, :pos], rev=(true, false, false))
    @test issorted(df, [order(:rank, rev=true), :chrom, :pos])
    @test issorted(df, rev=(true, false, false))

    @test df == ds

    sort!(df, ["rank", "chrom", "pos"], rev=(true, false, false))
    @test issorted(df, [order("rank", rev=true), "chrom", "pos"])
    @test issorted(df, rev=(true, false, false))

    @test df == ds

    @test_throws ArgumentError sort(df, (:rank, :chrom, :pos))

    df = DataFrame(x = [3, 1, 2, 1], y = ["b", "c", "a", "b"])
    @test !issorted(df, :x)
    @test issorted(sort(df, :x), :x)

    df = DataFrame(x = [3, 1, 2, 1], y = ["b", "c", "a", "b"])
    @test !issorted(df, "x")
    @test issorted(sort(df, "x"), "x")

    x = DataFrame(a=1:3,b=3:-1:1,c=3:-1:1)
    @test issorted(x)
    @test !issorted(x, [:b,:c])
    @test !issorted(x[:, 2:3], [:b,:c])
    @test issorted(sort(x,[2,3]), [:b,:c])
    @test issorted(sort(x[:, 2:3]), [:b,:c])

    x = DataFrame(a=1:3,b=3:-1:1,c=3:-1:1)
    @test issorted(x)
    @test !issorted(x, ["b","c"])
    @test !issorted(x[:, 2:3], ["b","c"])
    @test issorted(sort(x,[2,3]), ["b","c"])
    @test issorted(sort(x[:, 2:3]), ["b","c"])

    # Check that columns that shares the same underlying array are only permuted once PR#1072
    df = DataFrame(a=[2,1])
    df.b = df.a
    sort!(df, :a)
    @test df == DataFrame(a=[1,2],b=[1,2])

    x = DataFrame(x=[1,2,3,4], y=[1,3,2,4])
    sort!(x, :y)
    @test x.y == [1,2,3,4]
    @test x.x == [1,3,2,4]

    @test_throws ArgumentError sort(x, by=:x)

    Random.seed!(1)
    # here there will be probably no ties
    df_rand1 = DataFrame(rand(100, 4), :auto)
    # but here we know we will have ties
    df_rand2 = copy(df_rand1)
    df_rand2.x1 = shuffle([fill(1, 50); fill(2, 50)])
    df_rand2.x4 = shuffle([fill(1, 50); fill(2, 50)])

    # test sorting by 1 column
    for df_rand in [df_rand1, df_rand2]
        # testing sort
        for n1 in names(df_rand)
            # passing column name
            @test sort(df_rand, n1) == df_rand[sortperm(df_rand[:, n1]),:]
            # passing vector with one column name
            @test sort(df_rand, [n1]) == df_rand[sortperm(df_rand[:, n1]),:]
            # passing vector with two column names
            for n2 in setdiff(names(df_rand), [n1])
                @test sort(df_rand, [n1,n2]) ==
                      df_rand[sortperm(collect(zip(df_rand[:, n1],
                                                   df_rand[:, n2]))),:]
            end
        end
        # testing if sort! is consistent with issorted and sort
        ref_df = df_rand
        for n1 in names(df_rand)
            df_rand = copy(ref_df)
            @test sort!(df_rand, n1) == sort(ref_df, n1)
            @test issorted(df_rand, n1)
            df_rand = copy(ref_df)
            @test sort!(df_rand, [n1]) == sort(ref_df, [n1])
            @test issorted(df_rand, [n1])
            for n2 in setdiff(names(df_rand), [n1])
                df_rand = copy(ref_df)
                @test sort!(df_rand, [n1, n2]) == sort(ref_df, [n1, n2])
                @test issorted(df_rand, n1)
                @test issorted(df_rand, [n1, n2])
            end
        end
    end
end

@testset "non standard selectors" begin
    Random.seed!(1234)
    df = DataFrame(rand(1:2, 1000, 4), :auto)
    for f in [sort, sort!, sortperm, issorted]
        @test f(df) == f(df, :) == f(df, All()) == f(df, Cols(:)) == f(df, r"x") ==
              f(df, Between(1, 4)) == f(df, Not([]))
    end
end

@testset "view kwarg test" begin
    df = DataFrame(rand(3,4), :auto)
    @test sort(df) isa DataFrame
    @inferred sort(df)
    @test sort(view(df, 1:2, 1:2)) isa DataFrame
    @test sort(df, view=false) isa DataFrame
    @test sort(view(df, 1:2, 1:2), view=false) isa DataFrame
    @test sort(df, view=true) isa SubDataFrame
    @test sort(df, view=true) == sort(df)
    @test sort(view(df, 1:2, 1:2), view=true) isa SubDataFrame
    @test sort(view(df, 1:2, 1:2), view=true) == sort(view(df, 1:2, 1:2))
end

end # module
