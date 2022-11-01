clear variables

% CHANGE DATA TYPE HERE %
dataName = 'ECEO Mean 71 channels';
% CHANGE DIRECTORY HERE %
folderName = fullfile('../criteria csvs', 'meanmap_csvs');

% MODIFY INCLUDED AND EXCLUDED CRITERIA HERE %
replaceCV = 1;
includedCriteria = {'CH', 'CV', 'DB', 'D', 'FVG', 'KL', 'KLnrm', 'PB', 'S'};
excludedCriteria = [];
numCriteria = numel(includedCriteria);

files = dir(folderName);
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);

avgCorrMat = zeros(numCriteria);

% collect criteria values from using all GFP peaks for all subjects
for i=1:numel(filenames)
    filename = filenames{i};
    tbl = readtable(fullfile(folderName, filename));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValues = tbl(isAllPeaks, :);

    % remove CV and rename CV2
    if replaceCV
        criteriaValues(matches(criteriaValues.criterion_name, 'CV'), :) = [];
        criteriaValues{matches(criteriaValues.criterion_name, 'CV2'), 3} = {'CV'};
    end

    % remove criteria to exclude
    for c=1:numel(excludedCriteria)
        cIdx = matches(criteriaValues.criterion_name, excludedCriteria{c});
        if any(cIdx)
            criteriaValues(cIdx, :) = [];
        end
    end

    % sort in alphabetical order
    [sortedNames, sortIdx] = sort(criteriaValues.criterion_name);
    criteriaValues = criteriaValues{sortIdx, 4:end};

    % get correlation matrix
    corrMat = corr(criteriaValues');

    % plot as heat map and save
%     heatmap(sortedNames, sortedNames, corrMat, 'GridVisible', 'off');
%     setname = filename(1:strfind(filename, '_criteria_results.csv')-1);
%     saveas(gcf, ['' setname '_corrmat.fig']);
%     close(gcf);

    % add to overall correlation matrix
    avgCorrMat = avgCorrMat + corrMat;
end

% plot average correlation matrix
avgCorrMat = avgCorrMat./nSubjects;
figureName = sprintf('Average Corrmat - %s', dataName);
figure('Name', figureName);
heatmap(sortedNames, sortedNames, avgCorrMat, 'GridVisible', 'off');
filename = sprintf('correlation matrices/Average Corrmat_%s.fig', dataName);
saveas(gcf, filename);