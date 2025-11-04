function Result = IsFieldWithInformation(Struct, FieldName)
    if ~isfield(Struct, FieldName)
        Result = false;

    else
        if isempty(Struct.(FieldName))
            Result = false;
        else
            Result = true;
        end
    end
end