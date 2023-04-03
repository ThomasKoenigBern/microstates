clear variables

scriptPath = fileparts(mfilename('fullpath'));

% CHANGE DATA TYPE HERE %
dataName = '10-20 channels';
% CHANGE DIRECTORY HERE %
folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_1020channels');

% MODIFY INCLUDED AND EXCLUDED CRITERIA HERE %
replaceCV = 0;
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

ECcriterionvotes = zeros(nSubjects/2, numCriteria);
EOcriterionvotes = zeros(nSubjects/2, numCriteria);

EC_IQMSNRmc = zeros(nSubjects/2, numClustSolutions);
EO_IQMSNRmc = zeros(nSubjects/2, numClustSolutions);
EC_IQMSNRmcvotes = zeros(nSubjects/2, 1);
EO_IQMSNRmcvotes = zeros(nSubjects/2, 1);

% collect criteria values from using all GFP peaks for all subjects
ECcount = 1;
EOcount = 1;
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

    % compute IQM
    criterionIQM = sort(criteriaValues);                            % first sort the columns and make copy of array
    quartileSize = numCriteria/4;                                   % calculate quartile size

    % if number of criterion chosen is divisible by 4, can take IQM
    % without weighting partial values
    if (mod(numCriteria, 4) == 0)
        criterionIQM = criterionIQM(1+quartileSize:numCriteria-quartileSize,:);
        IQM = mean(criterionIQM);
    % otherwise, find full and partial observations of IQR and weight for
    % partial values
    else
        removeSize = floor(quartileSize);                           % number of values to remove from 1st and 4th quartiles
        criterionIQM = criterionIQM(1+removeSize:end-removeSize,:); % full and partial values of IQR
        nIQR = numCriteria - 2*quartileSize;                        % number of values in IQR
        nFull = size(criterionIQM,1) - 2;                           % number of full values in IQR
        weight = (nIQR-nFull)/2;                                    % weight to multiply partial values of IQR by
        IQM = zeros(1, numClustSolutions);
        for c=1:numClustSolutions
            IQM(c) = (weight*(criterionIQM(1, c) + criterionIQM(end, c)) + sum(criterionIQM(2:end-1, c)))/nIQR;
        end
    end
    
    % compute IQR
    IQR = iqr(criteriaValues);

    % compute metacriterion
    metacriterion = (IQM.^2)./IQR;

    % normalize
    metacriterion = (metacriterion - min(metacriterion))/(max(metacriterion) - min(metacriterion));

    % find optimal cluster number predicted by metacriterion
    [M, ind] = max(metacriterion);
    vote = ClusterNumbers(ind);

    % find optimal cluster number for each criterion
    [M, ind2] = max(criteriaValues, [], 2);

    if contains(filename, 'EC')
        EC_IQMSNRmc(ECcount, :) = metacriterion;
        EC_IQMSNRmcvotes(ECcount) = vote;
        
        ECcriterionvotes(ECcount, :) = ClusterNumbers(ind2);
        ECcount = ECcount + 1;
    elseif contains(filename, 'EO')
        EO_IQMSNRmc(EOcount, :) = metacriterion;
        EO_IQMSNRmcvotes(EOcount) = vote;

        EOcriterionvotes(EOcount, :) = ClusterNumbers(ind2);
        EOcount = EOcount + 1;
    end
end

% make histograms for EC vs. EO IQM/SNR metacriterion votes for all subjects
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figureName = sprintf('EC IQM/SNR Metacriterion Vote Histogram - %s', dataName);
figure('Name', figureName);
fontSize = 20;
histogram(EC_IQMSNRmcvotes, edges);
title('Eyes Closed Optimal Cluster Numbers (IQM*SNR Metacriterion)', 'FontSize', fontSize);
filename = sprintf('EC vs EO metacriterion histograms/EC IQMSNR Metacriterion Vote Histogram_%s_%s', dataName, includedCriteriaString);
if saveFig; saveas(gcf, filename); end

figureName = sprintf('EO IQM/SNR Metacriterion Vote Histogram - %s', dataName);
figure('Name', figureName);
histogram(EO_IQMSNRmcvotes, edges);
title('Eyes Open Optimal Cluster Numbers (IQM*SNR Metacriterion)', 'FontSize', fontSize);
filename = sprintf('EC vs EO metacriterion histograms/EO IQMSNR Metacriterion Vote Histogram_%s_%s', dataName, includedCriteriaString);
if saveFig; saveas(gcf, filename); end

% find median of all criteria votes across participants
ECmedianvotes = median(ECcriterionvotes, 2);
EOmedianvotes = median(EOcriterionvotes, 2);
ECmedianvotetotal = median(ECmedianvotes);
EOmedianvotetotal = median(EOmedianvotes);

% find median criterion vote across participants
ECmedianCriterionVotes = median(ECcriterionvotes, 1);
EOmedianCriterionVotes = median(EOcriterionvotes, 1);

% find difference between EC and EO vote for across participants
ECEOdiff = ECcriterionvotes - EOcriterionvotes;

% average difference per criteria
criterionECEOdiff = mean(ECEOdiff);

% average difference between median vote of all criteria across
% participants
subjECEOdiff = EOmedianvotes - ECmedianvotes;

% difference between average vote of all criteria across participants
% subjECEOdiff_avg = avgEOVotes - avgECVotes;

% make histograms for EC vs. EO median criterion votes for all subjects
figureName = sprintf('EC Median Vote Histogram - %s', dataName);
figure('Name', figureName);
histogram(ECmedianvotes, edges);
title('Eyes Closed Optimal Cluster Numbers (Median Vote Across Criteria)', 'FontSize', fontSize);
filename = sprintf('EC vs EO metacriterion histograms/EC Median Vote Histogram_%s_%s', dataName, includedCriteriaString);
if saveFig; saveas(gcf, filename); end

figureName = sprintf('EO Median Vote Histogram - %s', dataName);
figure('Name', figureName);
histogram(EOmedianvotes, edges);
title('Eyes Open Optimal Cluster Numbers (Median Vote Across Criteria)', 'FontSize', fontSize);
filename = sprintf('EC vs EO metacriterion histograms/EO Median Vote Histogram_%s_%s', dataName, includedCriteriaString);
if saveFig; saveas(gcf, filename); end

% make bar graph for median criterion vote per criterion
figureName = sprintf('Eyes Open vs Eyes Closed Median Criterion Votes - %s', dataName);
figure('Name', figureName);
names = categorical(sortedNames);
names = reordercats(names, sortedNames);
bar(names, [ECmedianCriterionVotes; EOmedianCriterionVotes]');
legend({'Eyes Closed', 'Eyes Open'});
title('Median Optimal Cluster Number Per Criterion Across Subjects');
filename = sprintf('EC vs EO metacriterion histograms/ECvsEO Median Vote Per Criterion_%s', dataName);
if saveFig; saveas(gcf, filename); end

% make bar graph for average votes per criterion
% figure;
% bar(names, avgVotes_ECEO);
% legend({'Eyes Closed', 'Eyes Open'});
% title('Average Vote Per Criterion Across Subjects');
% % saveas(gcf, 'EC vs EO metacriterion histograms/1020channels_average_vote_per_criterion_histogram.fig');

% % make bar graph for median overall vote
% figure;
% names = categorical({'Eyes Closed', 'Eyes Open'});
% names = reordercats(names, {'Eyes Closed', 'Eyes Open'});
% bar(names, [totalMedECVote, totalMedEOVote]);
% title('Median of Criterion Votes Across Subjects');
% 
% % make bar graph for average overall vote
% figure;
% bar(names, avgMeanVote_ECEO);
% title('Average of Criterion Votes Across Subjects');