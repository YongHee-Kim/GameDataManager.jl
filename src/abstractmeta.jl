"""
    AbstractMetaData

Thin wrapper for data to store cache and 'mtime' for the data file 
"""
abstract type AbstractMetaData end 

Base.getindex(x::AbstractMetaData, i) = getindex(x.data, i)

filepath(x::AbstractMetaData) = x.filepath

function isloaded(x::AbstractMetaData) 
    !ismissing(x.data)
end
function ismodified(x::AbstractMetaData)
    if isloaded(x)
        return x.mtime != mtime(filepath(x))
    else 
        return true 
    end
end
function update!(x::AbstractMetaData)
    if ismodified(x)
        loaddata!(x)
    end
    return x
end

mutable struct SchemaData <: AbstractMetaData
    filepath::AbstractString
    data::Union{Missing, JSONSchema.Schema}
    mtime::Float64 
end
function SchemaData(file)
    SchemaData(file, missing, 0.)
end
function loaddata!(x::SchemaData)
    x.data = JSONSchema.Schema(JSON.parsefile(x.filepath; use_mmap=false))
    x.mtime = mtime(x.filepath)
    return x
end
