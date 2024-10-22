% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."

function  MSMaps = ManualSort(MSMaps, SortOrder, NewLabels, nClasses, ClassRange)
    
    if numel(nClasses) > 1        
        error('Only one cluster solution can be chosen for manual sorting.');
    end

    if nClasses > max(ClassRange) || nClasses < min(ClassRange)
        error(['The specified set to sort does not contain a %i microstate solution. Valid ' ...
            ' class numbers to sort are in the range %i-%i.'], nClasses, max(ClassRange), min(ClassRange));
    end

    % Validate SortOrder
    if ~isempty(SortOrder)
        sortOrderSign = sign(SortOrder(:)');
        absSortOrder = abs(SortOrder(:)');
        if (numel(absSortOrder) ~= nClasses)
            MSMaps = [];
            if ~isempty(findobj('Tag', 'InteractiveSort'))
                errordlg2('Invalid manual sort order provided','Sort microstate maps error');
                return;
            else
                error('Invalid manual sort order provided');
            end
        end
    
        if numel(unique(absSortOrder)) ~= nClasses
            MSMaps = [];
            if ~isempty(findobj('Tag', 'InteractiveSort'))
                errordlg2('Invalid manual sort order provided','Sort microstate maps error');
                return;
            else
                error('Invalid manual sort order provided');
            end
        end
    
        if any(unique(absSortOrder) ~= unique(1:nClasses))
            MSMaps = [];
            if ~isempty(findobj('Tag', 'InteractiveSort'))
                errordlg2('Invalid manual sort order provided','Sort microstate maps error');
                return;
            else
                error('Invalid manual sort order provided');
            end
        end
    end

    % Validate NewLabels
    if numel(NewLabels) ~= nClasses
        MSMaps = [];
        if ~isempty(findobj('Tag', 'InteractiveSort'))
            errordlg2('Invalid manual map labels provided','Sort microstate maps error');
            return;
        else
            error('Invalid manual map labels provided');
        end
    end

    % Reorder maps
    if ~isempty(SortOrder)
        SortOrder = absSortOrder;
        MSMaps(nClasses).Maps = MSMaps(nClasses).Maps(SortOrder,:).*repmat(sortOrderSign',1,size(MSMaps(nClasses).Maps,2));

        if numel(MSMaps(nClasses).ExpVar) > 1
            MSMaps(nClasses).ExpVar = MSMaps(nClasses).ExpVar(SortOrder);
        end
        if isfield(MSMaps(nClasses), 'SharedVar')
            MSMaps(nClasses).SharedVar = MSMaps(nClasses).SharedVar(SortOrder);
        end     
    end

    % Assign new labels
    MSMaps(nClasses).Labels = NewLabels(:)';

    % Assign new colors
    letters1 = 'A':'Z';
    letters2 = 'a':'z';
    letters1 = arrayfun(@(x) {letters1(x)}, 1:26);
    letters2 = arrayfun(@(x) {letters2(x)}, 1:26);
    colorIdx = cellfun(@(x) find(matches(letters1, x) | matches(letters2, x)), NewLabels);
    labelIdx = matches(NewLabels(:)', letters1) | matches(NewLabels(:)', letters2);
    if ~isempty(colorIdx)
        colors = getColors(max(colorIdx));        
        newColors = zeros(nClasses, 3);        
        newColors(labelIdx,:) = colors(colorIdx,:);
        if any(~labelIdx)
            colorIdx = unique(colorIdx);
            extraIdx = find(colorIdx > 7 & colorIdx <= 7+sum(~labelIdx));
            colors = getColors(7+sum(~labelIdx)+numel(extraIdx));
            colors(1:7,:) = [];
            colors(colorIdx(extraIdx)-7,:) = [];
            newColors(~labelIdx,:) = colors;
        end
    else
        newColors = getColors(nClasses);
    end
    MSMaps(nClasses).ColorMap = newColors;
       
    % Update sorting information
    MSMaps(nClasses).SortMode = 'manual';
    MSMaps(nClasses).SortedBy = 'user';
    MSMaps(nClasses).SpatialCorrelation = [];
end