"""
    SubDataFrame{<:AbstractDataFrame,<:AbstractIndex,<:AbstractVector{Int}} <: AbstractDataFrame

A view of an `AbstractDataFrame`. It is returned by a call to the `view` function
on an `AbstractDataFrame` if a collections of rows and columns are specified.

A `SubDataFrame` is an `AbstractDataFrame`, so expect that most
DataFrame functions should work. Such methods include `describe`,
`summary`, `nrow`, `size`, `by`, `stack`, and `join`.

Indexing is just like a `DataFrame` except that it is possible to create a
`SubDataFrame` with duplicate columns. All such columns will have a reference
to the same entry in the parent `DataFrame`.

If the selection of columns in a parent data frame is passed as `:` (a colon)
then `SubDataFrame` will always have all columns from the parent,
even if they are added or removed after its creation.

# Examples
```julia
df = DataFrame(a = repeat([1, 2, 3, 4], outer=[2]),
               b = repeat([2, 1], outer=[4]),
               c = randn(8))
sdf1 = view(df, 2:3) # column subsetting
sdf2 = @view df[end:-1:1, [1,3]]  # row and column subsetting
sdf3 = groupby(df, :a)[1]  # indexing a GroupedDataFrame returns a SubDataFrame
```
"""
struct SubDataFrame{D<:AbstractDataFrame,S<:AbstractIndex,T<:AbstractVector{Int}} <: AbstractDataFrame
    parent::D
    colindex::S
    rows::T # maps from subdf row indexes to parent row indexes
end

Base.@propagate_inbounds function SubDataFrame(parent::DataFrame, rows::AbstractVector{Int}, cols)
    @boundscheck if !checkindex(Bool, axes(parent, 1), rows)
        throw(BoundsError(parent, (rows, cols)))
    end
    SubDataFrame(parent, SubIndex(index(parent), cols), rows)
end
Base.@propagate_inbounds SubDataFrame(parent::DataFrame, ::Colon, cols) =
    SubDataFrame(parent, axes(parent, 1), cols)
@inline SubDataFrame(parent::DataFrame, row::Integer, cols) =
    throw(ArgumentError("invalid row index: $row of type $(typeof(row))"))

Base.@propagate_inbounds function SubDataFrame(parent::DataFrame, rows::AbstractVector{<:Integer}, cols)
    if any(x -> x isa Bool, rows)
        throw(ArgumentError("invalid row index of type `Bool`"))
    end
    return SubDataFrame(parent, convert(Vector{Int}, rows), cols)
end

Base.@propagate_inbounds function SubDataFrame(parent::DataFrame, rows::AbstractVector{Bool}, cols)
    if length(rows) != nrow(parent)
        throw(ArgumentError("invalid length of `AbstractVector{Bool}` row index" *
                            " (got $(length(rows)), expected $(nrow(parent)))"))
    end
    return SubDataFrame(parent, findall(rows), cols)
end

Base.@propagate_inbounds function SubDataFrame(parent::DataFrame, rows::AbstractVector, cols)
    if !all(x -> (x isa Integer) && !(x isa Bool), rows)
        throw(ArgumentError("only `Integer` indices are accepted in `rows`"))
    end
    return SubDataFrame(parent, convert(Vector{Int}, rows), cols)
end

Base.@propagate_inbounds SubDataFrame(sdf::SubDataFrame, rowind, cols) =
    SubDataFrame(parent(sdf), rows(sdf)[rowind], parentcols(index(sdf), cols))
Base.@propagate_inbounds SubDataFrame(sdf::SubDataFrame, rowind::Bool, cols) =
    throw(ArgumentError("invalid row index of type Bool"))
Base.@propagate_inbounds SubDataFrame(sdf::SubDataFrame, rowind, ::Colon) =
    if index(sdf) isa Index # sdf was created using : as row selector
        SubDataFrame(parent(sdf), rows(sdf)[rowind], :)
    else
        SubDataFrame(parent(sdf), rows(sdf)[rowind], parentcols(index(sdf), :))
    end
Base.@propagate_inbounds SubDataFrame(sdf::SubDataFrame, rowind::Bool, ::Colon) =
    throw(ArgumentError("invalid row index of type Bool"))
Base.@propagate_inbounds SubDataFrame(sdf::SubDataFrame, ::Colon, cols) =
    SubDataFrame(parent(sdf), rows(sdf), parentcols(index(sdf), cols))
@inline SubDataFrame(sdf::SubDataFrame, ::Colon, ::Colon) = sdf

rows(sdf::SubDataFrame) = getfield(sdf, :rows)
Base.parent(sdf::SubDataFrame) = getfield(sdf, :parent)
Base.parentindices(sdf::SubDataFrame) = (rows(sdf), parentcols(index(sdf)))

Base.@propagate_inbounds Base.view(adf::AbstractDataFrame, rowinds, colind::ColumnIndex) =
    view(adf[!, colind], rowinds)
Base.@propagate_inbounds Base.view(adf::AbstractDataFrame, ::typeof(!), colind::ColumnIndex) =
    view(adf[!, colind], :)
@inline Base.view(adf::AbstractDataFrame, rowinds, colind::Bool) =
    throw(ArgumentError("invalid column index $colind of type `Bool`"))
Base.@propagate_inbounds Base.view(adf::AbstractDataFrame, rowinds,
                                   colinds::MultiColumnIndex) =
    SubDataFrame(adf, rowinds, colinds)
Base.@propagate_inbounds Base.view(adf::AbstractDataFrame, rowinds::typeof(!),
                                   colinds::MultiColumnIndex) =
    SubDataFrame(adf, :, colinds)
Base.@propagate_inbounds Base.view(adf::AbstractDataFrame, rowinds::Not,
                                   colinds::MultiColumnIndex) =
    SubDataFrame(adf, axes(adf, 1)[rowinds], colinds)

##############################################################################
##
## AbstractDataFrame interface
##
##############################################################################

index(sdf::SubDataFrame) = getfield(sdf, :colindex)

nrow(sdf::SubDataFrame) = ncol(sdf) > 0 ? length(rows(sdf))::Int : 0
ncol(sdf::SubDataFrame) = length(index(sdf))

Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, rowind::Integer, colind::ColumnIndex) =
    parent(sdf)[rows(sdf)[rowind], parentcols(index(sdf), colind)]
Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, rowind::Bool, colind::ColumnIndex) =
    throw(ArgumentError("invalid row index of type Bool"))

Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, rowinds::Union{AbstractVector, Not},
                                       colind::ColumnIndex) =
    parent(sdf)[rows(sdf)[rowinds], parentcols(index(sdf), colind)]
Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, ::Colon, colind::ColumnIndex) =
    parent(sdf)[rows(sdf), parentcols(index(sdf), colind)]
Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, ::typeof(!), colind::ColumnIndex) =
    view(parent(sdf), rows(sdf), parentcols(index(sdf), colind))

Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, rowinds::Union{AbstractVector, Not},
                                       colinds::MultiColumnIndex) =
    parent(sdf)[rows(sdf)[rowinds], parentcols(index(sdf), colinds)]
Base.@propagate_inbounds Base.getindex(sdf::SubDataFrame, ::Colon,
                                       colinds::MultiColumnIndex) =
    parent(sdf)[rows(sdf), parentcols(index(sdf), colinds)]
Base.@propagate_inbounds Base.getindex(df::SubDataFrame, row_ind::typeof(!),
                                       col_inds::MultiColumnIndex) =
    select(df, col_inds, copycols=false)


Base.@propagate_inbounds function Base.setindex!(sdf::SubDataFrame, val::Any, idx::CartesianIndex{2})
    setindex!(sdf, val, idx[1], idx[2])
end
Base.@propagate_inbounds function Base.setindex!(sdf::SubDataFrame, val::Any, ::Colon, colinds::Any)
    parent(sdf)[rows(sdf), parentcols(index(sdf), colinds)] = val
    return sdf
end
Base.@propagate_inbounds function Base.setindex!(sdf::SubDataFrame, val::Any, ::typeof(!), colinds::Any)
    throw(ArgumentError("setting index of SubDataFrame using ! as row selector is not allowed"))
end
Base.@propagate_inbounds function Base.setindex!(sdf::SubDataFrame, val::Any, rowinds::Any, colinds::Any)
    parent(sdf)[rows(sdf)[rowinds], parentcols(index(sdf), colinds)] = val
    return sdf
end
Base.@propagate_inbounds Base.setindex!(sdf::SubDataFrame, val::Any, rowinds::Bool, colinds::Any) =
    throw(ArgumentError("invalid row index of type Bool"))

##############################################################################
##
## Miscellaneous
##
##############################################################################

Base.copy(sdf::SubDataFrame) = parent(sdf)[rows(sdf), parentcols(index(sdf), :)]

Base.delete!(df::SubDataFrame, ind) =
    throw(ArgumentError("SubDataFrame does not support deleting rows"))

function DataFrame(sdf::SubDataFrame; copycols::Bool=true)
    if copycols
        sdf[:, :]
    else
        DataFrame(eachcol(sdf), _names(sdf), copycols=false)
    end
end

Base.convert(::Type{DataFrame}, sdf::SubDataFrame) = DataFrame(sdf)
