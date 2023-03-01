function [NewLabels, NewColors] = UpdateMicrostateLabels(OldLabels,TemplateLabels,SortOrder,TemplateColor)
    nOldLabels      = sum(~cellfun(@isempty,OldLabels));
    nTemplateLabels = sum(~cellfun(@isempty,TemplateLabels));
    
    % Number of colors that are not gray is the number of maps with
    % valid assignments/labels
    nAssignedLabels = sum(~arrayfun(@(x) all(TemplateColor(x,:) == [.75 .75 .75]), 1:nTemplateLabels));
    nCopiedLabels = min(nAssignedLabels, nOldLabels);
    ToCopy = SortOrder <= nCopiedLabels;

    if nOldLabels < nAssignedLabels
        NewLabels(1:nCopiedLabels) = TemplateLabels(ToCopy);
        if nargin > 3
            NewColors(1:nCopiedLabels,:) = TemplateColor(ToCopy, :);
        end
    else
        NewLabels(1:nCopiedLabels) = TemplateLabels(1:nCopiedLabels);
        if nargin > 3
            NewColors(1:nCopiedLabels,:) = TemplateColor(1:nCopiedLabels,:);
        end
    end

    % Change labels of unsorted maps to the generic labels
    nGenericLabels = nOldLabels - nCopiedLabels;
    if nGenericLabels > 0
        NewLabels((nCopiedLabels+1):nOldLabels) = arrayfun(@(x) sprintf('MS_%i.%i', nOldLabels, nCopiedLabels+x), 1:nGenericLabels, ...
            'UniformOutput', false);

        if nargin > 3
            % Change colors of unsorted maps to gray
            NewColors((nCopiedLabels+1):nOldLabels, :) = repmat(.75, nGenericLabels, 3);
        end
    end
end
