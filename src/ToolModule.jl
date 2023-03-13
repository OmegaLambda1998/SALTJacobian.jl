module ToolModule

# External Packages
using CodecZlib
using Tar

# Internal Packages

# Exports
export uncompress
export compress
export ensure_list
export readpath

# Uncompress if source is compressed, otherwise just return source
function uncompress(source)
    if occursin(".tar.gz", source)
        source = open(source) do tar_gz
            tar = GzipDecompressorStream(tar_gz)
            s = readdir(Tar.extract(tar), join=true)[1]
            close(tar)
            return s
        end
    end
    return source
end

# Compress source into .tar.gz
#TODO Optionally allow for parent directory to be defined
function compress(source, dest; parent=false)
    open(dest, write=true) do tar_gz
        tar = GzipCompressorStream(tar_gz)
        if parent
            predicate = f(x) = contains(x, source) && !contains(x, ".tar.gz")
            Tar.create(predicate, dirname(source), tar)
        else
            Tar.create(source, tar)
        end
        close(tar)
    end
end

# Ensure input is a list
function ensure_list(list)
    if typeof(list) <: Vector
        return list
    end
    return [list]
end

# Read lines of a path, handling zipped paths
function readpath(path)
    if splitext(path)[end] == ".gz"
        f = GzipDecompressorStream # Decompress gzipped file
    else
        f = x -> x # Anonymous function which does nothing
    end
    lines = open(f, path) do io
        l = readlines(io)
        return l
    end
    return lines
end

end
