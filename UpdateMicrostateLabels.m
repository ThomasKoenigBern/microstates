function [NewLabels, NewColors] = UpdateMicrostateLabels(OldLabels,TemplateLabels,SortOrder,OldColor,TemplateColor)
    nOldLabels      = sum(~cellfun(@isempty,OldLabels));
    nTemplateLabels = sum(~cellfun(@isempty,TemplateLabels));
    ToCopy = SortOrder<= nOldLabels;
    ToKeep = SortOrder > nTemplateLabels;
    
    
    if  nOldLabels == nTemplateLabels
        NewLabels = TemplateLabels;
        if nargin > 3
            NewColors = TemplateColor;
        end
            
        
    elseif nTemplateLabels > nOldLabels
        NewLabels = TemplateLabels(ToCopy);
        if nargin > 3
            NewColors = TemplateColor(ToCopy,:);
        end

    else
        NewLabels(1:nTemplateLabels) = TemplateLabels;

        % Delara 10/19/22 change: keep old labels if they were from sorting
        % by other template maps. otheriwse, update the generic labels to
        % reflect their new position in the order
        ToKeepIndices = find(ToKeep);
        for i=1:numel(ToKeepIndices)
            labelIndex = ToKeepIndices(i);
            if ~contains(OldLabels(labelIndex), sprintf('MS_%i', nOldLabels))
                NewLabels{nTemplateLabels+i} = OldLabels{labelIndex};
            else
                NewLabels{nTemplateLabels+i} = sprintf('MS_%i.%i', nOldLabels, nTemplateLabels+i);
            end
        end
%         NewLabels((nTemplateLabels+1):nOldLabels) = OldLabels(ToKeep);

        if nargin > 3
            NewColors(1:nTemplateLabels ,:) = TemplateColor;

            % same change for colors
            defaultColors = lines(nOldLabels);
            for i=1:numel(ToKeepIndices)
                labelIndex = ToKeepIndices(i);
                if ~contains(OldLabels(labelIndex), sprintf('MS_%i', nOldLabels))
                    NewColors(nTemplateLabels+i, :) = OldColor(labelIndex, :);
                else
                    NewColors(nTemplateLabels+i, :) = defaultColors(nTemplateLabels+i, :);
                end
            end
%             NewColors((nTemplateLabels+1:nOldLabels),:) = OldColor(ToKeep,:);
        end
    end
