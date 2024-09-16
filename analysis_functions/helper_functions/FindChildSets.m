function [childIdx, childSetnames] = FindChildSets(AllEEG, MeanSets)  
    childIdx = [];

    for s=1:numel(MeanSets)
        childNames = AllEEG(MeanSets(s)).msinfo.children;
        if isempty(childNames);     continue;   end
        setnames = {AllEEG.setname};
        isEmpty = cellfun(@isempty,setnames);
        if any(isEmpty)
            setnames(isEmpty) = {''};
        end
        newChildIdx = find(matches(setnames, childNames));
        if isempty(newChildIdx)
            continue;
        end

        for c=1:numel(newChildIdx)
            if isfield(AllEEG(newChildIdx(c)).msinfo, 'children')                
                newChildIdx = [newChildIdx FindChildSets(AllEEG, newChildIdx(c))];
            end
        end

        childIdx = [childIdx newChildIdx];
    end

    childIdx = sort(childIdx, 'ascend');
    childSetnames = {AllEEG(childIdx).setname};
end