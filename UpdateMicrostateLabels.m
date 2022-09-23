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
        NewLabels((nTemplateLabels+1):nOldLabels) = OldLabels(ToKeep);
        if nargin > 3
            NewColors(1:nTemplateLabels ,:) = TemplateColor;
            NewColors((nTemplateLabels+1:nOldLabels),:) = OldColor(ToKeep,:);
        end
    end
