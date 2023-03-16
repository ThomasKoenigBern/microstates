nClasses = 4;
sets = 1:44;

mapLabels = arrayfun(@(x) ALLEEG(x).msinfo.MSMaps(nClasses).Labels, sets, 'UniformOutput', false);
uniqueLabels = mapLabels{1};

for i=2:length(mapLabels)
    if ~any(arrayfun(@(x) all(matches(mapLabels{i}, uniqueLabels(x,:))), 1:size(uniqueLabels, 1)))
        uniqueLabels = [uniqueLabels; mapLabels{i}];
    end
end