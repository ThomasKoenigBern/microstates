function [MSMaps, com] = ManualSort(MSMaps, SortOrder, NewLabels, nClasses, ClassRange)
    com = '';
    
    if numel(nClasses) > 1        
        errordlg2('Only one cluster solution can be chosen for manual sorting.', 'Sort microstate maps error');
        return;
    end

    if nClasses > max(ClassRange) || nClasses < min(ClassRange)
        warningMessage = sprintf(['The specified set to sort does not contain a %i microstate solution. Valid ' ...
            ' class numbers to sort are in the range %i-%i.'], nClasses, max(ClassRange), min(ClassRange));
        errordlg2(warningMessage, 'Sort microstate maps error');
        return;
    end

    % Validate SortOrder
    sortOrderSign = sign(SortOrder(:)');
    absSortOrder = abs(SortOrder(:)');
    if (numel(absSortOrder) ~= nClasses)
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if numel(unique(absSortOrder)) ~= nClasses
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if any(unique(absSortOrder) ~= unique(1:nClasses))
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    % Validate NewLabels
    if numel(NewLabels) ~= nClasses
        MSMaps = [];
        errordlg2('Invalid manual map labels given', 'Sort microstate maps error');
        return;
    end

    % Manual sort    
    if ~all(SortOrder == 1:nClasses) || ~all(string(NewLabels) == string(MSMaps(nClasses).Labels))
        SortOrder = absSortOrder;
        MSMaps(nClasses).Maps = MSMaps(nClasses).Maps(SortOrder,:).*repmat(sortOrderSign',1,size(MSMaps(nClasses).Maps,2));
        MSMaps(nClasses).Labels = NewLabels(:)';
        MSMaps(nClasses).ColorMap = getColors(nClasses);
        if numel(MSMaps(nClasses).ExpVar) > 1
            MSMaps(nClasses).ExpVar = MSMaps(nClasses).ExpVar(SortOrder);
        end
        if isfield(MSMaps(nClasses), 'SharedVar')
            MSMaps(nClasses).SharedVar = MSMaps(nClasses).SharedVar(SortOrder);
        end        
        if ~all(SortOrder == 1:nClasses)
            MSMaps(nClasses).SortMode = 'manual';
            MSMaps(nClasses).SortedBy = 'user';
            MSMaps(nClasses).SpatialCorrelation = [];
        end
    end
end