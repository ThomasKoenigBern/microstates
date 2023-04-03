function [parentIdx, parentSetnames] = FindParentSets(AllEEG, ChildSet)
    parentSets = find(arrayfun(@(x) isfield(AllEEG(x).msinfo, 'children'), 1:numel(AllEEG)));
    parentSets = parentSets(arrayfun(@(x) ~isempty(AllEEG(x).msinfo.children), parentSets));

    parentIdx = [];
    for i=1:numel(parentSets)
        childIdx = FindChildSets(AllEEG, parentSets(i));
        if matches(AllEEG(ChildSet).setname, {AllEEG(childIdx).setname})
            parentIdx = [parentIdx parentSets(i)];
        end
    end

    parentSetnames = {AllEEG(parentIdx).setname};
end