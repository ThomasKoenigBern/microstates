function childIdx = FindChildSets(AllEEG, MeanSets)  
    childIdx = [];

    for s=1:numel(MeanSets)
        childNames = AllEEG(MeanSets(s)).msinfo.children;
        if isempty(childNames);     continue;   end
        newChildIdx = find(matches({AllEEG.setname}, childNames));
        if isempty(newChildIdx)
            fprintf('Could not find children of %s for resorting\n', AllEEG(MeanSets(s)).setname);
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

end