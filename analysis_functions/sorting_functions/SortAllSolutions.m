function MSMaps = SortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity)    
    % If the template set has unassigned maps, remove them (only base 
    % sorting on assigned maps)
    TemplateMaps = MSMaps(nClasses).Maps;
    nAssignedLabels = sum(~arrayfun(@(x) all(MSMaps(nClasses).ColorMap(x,:) == [.75 .75 .75]), 1:nClasses));
    if nAssignedLabels < nClasses
        TemplateMaps(nAssignedLabels+1:end,:) = [];
    end

    for i=ClassRange
        if i == nClasses
            continue
        end    

        if i >= 10
            warning('Automatic sorting is not supported for 10 classes or greater. Please use manual sorting instead. Skipping remaining cluster solutions...');
            break
        end

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, TemplateMaps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(nClasses).Labels, SortOrder, MSMaps(nClasses).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = [MSMaps(nClasses).SortMode '->alternate solution in set'];
        MSMaps(i).SortedBy = sprintf('%s->this set (%i classes)', MSMaps(nClasses).SortedBy, nClasses);
        MSMaps(i).SpatialCorrelation = SpatialCorrelation;
        if numel(MSMaps(i).ExpVar) > 1
            MSMaps(i).ExpVar = MSMaps(i).ExpVar(SortOrder(SortOrder <= i));
        end
        if isfield(MSMaps(i), 'SharedVar')
            MSMaps(i).SharedVar = MSMaps(i).SharedVar(SortOrder(SortOrder <= i));
        end

        if i > nClasses+1
            [SortedMaps, SortOrder, ~, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps((nClasses+1):end,:), MSMaps(i-1).Maps((nClasses+1):end,:), ~IgnorePolarity);
            MSMaps(i).Maps((nClasses+1):end,:) = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps),2));
            MSMaps(i).Labels((nClasses+1):end) = arrayfun(@(x) sprintf('MS_%i.%i', i, nClasses+x), 1:(i-nClasses), 'UniformOutput', false);
            if numel(MSMaps(i).ExpVar) > 1
                endExpVar = MSMaps(i).ExpVar((nClasses+1):end);
                MSMaps(i).ExpVar((nClasses+1):end) = endExpVar(SortOrder);
            end
            if isfield(MSMaps(i), 'SharedVar')
                endSharedVar = MSMaps(i).SharedVar((nClasses+1):end);
                MSMaps(i).SharedVar((nClasses+1):end) = endSharedVar(SortOrder);
            end
        end
    end
end