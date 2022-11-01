clear variables

% CHANGE DATA TYPE HERE %
dataName = '71 channels';
% CHANGE DIRECTORY HERE %
folderName = fullfile('../criteria csvs', 'individual_csvs');

% MODIFY INCLUDED AND EXCLUDED CRITERIA HERE %
replaceCV = 1;
saveFig = 1;
includedCriteria = {'CV', 'DB', 'D', 'FVG', 'KL', 'KLnrm', 'PB'};
excludedCriteria = {'CH', 'S'};
numCriteria = numel(includedCriteria);
includedCriteriaString = sprintf('%s ', string(includedCriteria));
includedCriteriaString(end) = [];

files = dir(folderName);
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);
sampleSizes = [1000 2000];

avgCorrs_1000samples = zeros(numCriteria, 1);
avgCorrs_2000samples = zeros(numCriteria, 1);
n1000samples = 0;
n2000samples = 0;
nRuns = 5;

for i=1:numel(filenames)
    filename = filenames{i};
    tbl = readtable(fullfile(folderName, filename));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValuesAllPeaks = tbl(isAllPeaks, :);

    % remove CV and rename CV2
    if replaceCV
        criteriaValuesAllPeaks(matches(criteriaValuesAllPeaks.criterion_name, 'CV'), :) = [];
        criteriaValuesAllPeaks{matches(criteriaValuesAllPeaks.criterion_name, 'CV2'), 3} = {'CV'};
    end

    % remove criteria to exclude
    for c=1:numel(excludedCriteria)
        cIdx = matches(criteriaValuesAllPeaks.criterion_name, excludedCriteria{c});
        if any(cIdx)
            criteriaValuesAllPeaks(cIdx, :) = [];
        end
    end

    % Find rows for different sample sizes
    for s=sampleSizes
        criteriaValues = tbl(tbl.sample_size == s, :);

        if ~isempty(criteriaValues)
            if s == 1000
                n1000samples = n1000samples + 1;
            elseif s == 2000
                n2000samples = n2000samples + 1;
            end

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

            % find average correlation between downsampled criterion values
            % and true criterion values for all criteria
            for c=1:numel(includedCriteria)
                criterionName = includedCriteria(c);
                downsampledCriterion = criteriaValues(matches(criteriaValues.criterion_name, criterionName), :);
                corrs = corr(downsampledCriterion{:, 4:end}', criteriaValuesAllPeaks{matches(criteriaValuesAllPeaks.criterion_name, criterionName), 4:end}');

                if s == 1000
                    avgCorrs_1000samples(c) = avgCorrs_1000samples(c) + sum(corrs);
                else
                    avgCorrs_2000samples(c) = avgCorrs_2000samples(c) + sum(corrs);
                end
            end
            
        end
    end

end

avgCorrs_1000samples = avgCorrs_1000samples/(n1000samples*nRuns);
avgCorrs_2000samples = avgCorrs_2000samples/(n2000samples*nRuns);

% make bar graph for average correlation per criterion
figureName = sprintf('Average Correlation Between Downsampled and True Criterion - %s', dataName);
figure('Name', figureName);
names = categorical(includedCriteria);
names = reordercats(names, includedCriteria);
bar(names, [avgCorrs_1000samples avgCorrs_2000samples]);
legend({'1000 samples', '2000 samples'});
title('Average Correlation Between Downsampled and True Criterion');
filename = sprintf('Average Correlation Between Downsampled and True Criterion_%s', dataName);
if saveFig; saveas(gcf, filename); end