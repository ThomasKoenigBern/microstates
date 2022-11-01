
% Generate metacriteria
mapNames = fieldnames(maps);
for i=1:numel(mapNames)
    mapName = mapNames{i};

    fprintf("~~~~Beginning criterion computations for dataset %i~~~~~\n", i);
    % Run with all GFP peaks
    tic
    criteria = generate_criteria_IndMaps(msinfo.(mapName), maps.(mapName)');
    toc
    for j=1:numel(criteria)
        criteria(j).run_no = 1;
        criteria(j).sample_size = size(maps.(mapName), 1);
    end

    fprintf("Generating csv for dataset %i\n", i);

    % Reorder struct
    criteria = orderfields(criteria, [9, 10, 1:8]);

    % make table
    outputTable = struct2table(criteria);

    % Rename cluster columns
    oldNames = arrayfun(@(x) sprintf("clust%i", x), 4:10);
    outputTable = renamevars(outputTable, oldNames, string(4:10));

    writetable(outputTable, ['meanmap_csvs/' mapName '_criteria_results.csv']);
end