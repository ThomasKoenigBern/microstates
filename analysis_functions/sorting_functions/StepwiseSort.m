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

function MSMaps = StepwiseSort(MSMaps, ClustPar, setname, nClasses, IgnorePolarity)

    % First sort the solutions with less classes than the template solution
    for i=(nClasses-1):-1:ClustPar.MinClasses    
        % If the template set has unassigned maps, remove them (only base 
        % sorting on assigned maps)
        TemplateMaps = MSMaps(i+1).Maps;
        nAssignedLabels = sum(~arrayfun(@(x) all(MSMaps(i+1).ColorMap(x,:) == [.75 .75 .75]), 1:(i+1)));
        if nAssignedLabels < (i+1)
            TemplateMaps(nAssignedLabels+1:end,:) = [];
        end

        if max(i, nAssignedLabels) >= 10 && (~license('test','optimization_toolbox') || isempty(which('intlinprog')))
            MSMaps = [];
            error(['Sorting using 10 or more classes requires the Optimization toolbox. ' ...
                'Please install the toolbox using the Add-On Explorer.']);
        end

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, TemplateMaps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(i+1).Labels, SortOrder, MSMaps(i+1).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = 'own template maps';
        MSMaps(i).SortedBy = sprintf('%s->%s (%i classes)', MSMaps(i+1).SortedBy, setname, i+1);
        MSMaps(i).SpatialCorrelation = SpatialCorrelation;
        if numel(MSMaps(i).ExpVar) > 1
            MSMaps(i).ExpVar = MSMaps(i).ExpVar(SortOrder(SortOrder <= i));
        end
        if isfield(MSMaps(i), 'SharedVar')
            MSMaps(i).SharedVar = MSMaps(i).SharedVar(SortOrder(SortOrder <= i));
        end

        % Sort any unassigned maps
        if nAssignedLabels < (i+1)
            nMaps = i-nAssignedLabels;
            if nMaps == 1;  continue;   end
            [SortedMaps, SortOrder, ~, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps((nAssignedLabels+1):end,:), MSMaps(i+1).Maps((nAssignedLabels+1):end,:), ~IgnorePolarity);
            MSMaps(i).Maps((nAssignedLabels+1):end,:) = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps),2));
            MSMaps(i).Labels((nAssignedLabels+1):end) = arrayfun(@(x) sprintf('MS_%i.%i', i, nAssignedLabels+x), 1:(i-nAssignedLabels), 'UniformOutput', false);
            if numel(MSMaps(i).ExpVar) > 1
                endExpVar = MSMaps(i).ExpVar((nAssignedLabels+1):end);
                MSMaps(i).ExpVar((nAssignedLabels+1):end) = endExpVar(SortOrder(SortOrder <= nMaps));
            end
            if isfield(MSMaps(i), 'SharedVar')
                endSharedVar = MSMaps(i).SharedVar((nAssignedLabels+1):end);
                MSMaps(i).SharedVar((nAssignedLabels+1):end) = endSharedVar(SortOrder(SortOrder <= nMaps));
            end
        end
    end

    % Then sort the solutions with more classes than the template solution
    for i=(nClasses+1):ClustPar.MaxClasses
        % If the template set has unassigned maps, remove them (only base 
        % sorting on assigned maps)
        TemplateMaps = MSMaps(i-1).Maps;
        nAssignedLabels = sum(~arrayfun(@(x) all(MSMaps(i-1).ColorMap(x,:) == [.75 .75 .75]), 1:(i-1)));
        if nAssignedLabels < (i-1)
            TemplateMaps(nAssignedLabels+1:end,:) = [];
        end

        if max(i, nAssignedLabels) >= 10 && (~license('test','optimization_toolbox') || isempty(which('intlinprog')))
            warning(['Sorting using 10 or more classes requires the Optimization toolbox. ' ...
                'Please install the toolbox using the Add-On Explorer. Skipping large cluster solutions...']);
            return;
        end

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, TemplateMaps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(i-1).Labels, SortOrder, MSMaps(i-1).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = 'own template maps';
        MSMaps(i).SortedBy = sprintf('%s->%s (%i classes)', MSMaps(i-1).SortedBy, setname, i-1);
        MSMaps(i).SpatialCorrelation = SpatialCorrelation;
        if numel(MSMaps(i).ExpVar) > 1
            MSMaps(i).ExpVar = MSMaps(i).ExpVar(SortOrder(SortOrder <= i));
        end
        if isfield(MSMaps(i), 'SharedVar')
            MSMaps(i).SharedVar = MSMaps(i).SharedVar(SortOrder(SortOrder <= i));
        end

        % Sort any unassigned maps
        if nAssignedLabels < (i-1)
            [SortedMaps, SortOrder, ~, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps((nAssignedLabels+1):end,:), MSMaps(i-1).Maps((nAssignedLabels+1):end,:), ~IgnorePolarity);
            MSMaps(i).Maps((nAssignedLabels+1):end,:) = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps),2));
            MSMaps(i).Labels((nAssignedLabels+1):end) = arrayfun(@(x) sprintf('MS_%i.%i', i, nAssignedLabels+x), 1:(i-nAssignedLabels), 'UniformOutput', false);
            if numel(MSMaps(i).ExpVar) > 1
                endExpVar = MSMaps(i).ExpVar((nAssignedLabels+1):end);
                MSMaps(i).ExpVar((nAssignedLabels+1):end) = endExpVar(SortOrder);
            end
            if isfield(MSMaps(i), 'SharedVar')
                endSharedVar = MSMaps(i).SharedVar((nAssignedLabels+1):end);
                MSMaps(i).SharedVar((nAssignedLabels+1):end) = endSharedVar(SortOrder);
            end
        end
    end    
end