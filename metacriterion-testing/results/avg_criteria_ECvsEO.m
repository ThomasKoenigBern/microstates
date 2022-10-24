files = dir('csvs');
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);
numCriteria = 7;

avgVotes_ECEO = zeros(numCriteria,2);
avgMeanVote_ECEO = zeros(1,2);

ECvotes = zeros(nSubjects/2, numCriteria);
EOvotes = zeros(nSubjects/2, numCriteria);

% collect criteria values from using all GFP peaks for all subjects
ECcount = 1;
EOcount = 1;
for i=1:numel(filenames)
    filename = filenames{i};
    tbl = readtable(fullfile('csvs', filename));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValues = tbl(isAllPeaks, :);

    % remove CV and rename CV2
    criteriaValues(matches(criteriaValues.criterion_name, 'CV'), :) = [];
    criteriaValues{matches(criteriaValues.criterion_name, 'CV2'), 3} = {'CV'};

    % remove S and CH
    criteriaValues(matches(criteriaValues.criterion_name, 'S'), :) = [];
    criteriaValues(matches(criteriaValues.criterion_name, 'CH'), :) = [];

    % sort in alphabetical order
    [sortedNames, sortIdx] = sort(criteriaValues.criterion_name);
    criteriaValues = criteriaValues{sortIdx, 4:end};

    % find optimal cluster number for each criterion
    [M, ind] = max(criteriaValues, [], 2);

    if contains(filename, 'EC')
        ECvotes(ECcount, :) = ClusterNumbers(ind);
        ECcount = ECcount + 1;

        avgVotes_ECEO(:, 1) = avgVotes_ECEO(:, 1) + ClusterNumbers(ind)';
        avgMeanVote_ECEO(1) = avgMeanVote_ECEO(1) + mean(ClusterNumbers(ind));
    elseif contains(filename, 'EO')
        EOvotes(EOcount, :) = ClusterNumbers(ind);
        EOcount = EOcount + 1;

        avgVotes_ECEO(:, 2) = avgVotes_ECEO(:, 2) + ClusterNumbers(ind)';
        avgMeanVote_ECEO(2) = avgMeanVote_ECEO(2) + mean(ClusterNumbers(ind));
    end
end

avgVotes_ECEO = avgVotes_ECEO./(nSubjects/2);
avgMeanVote_ECEO = avgMeanVote_ECEO./(nSubjects/2);

% find median of all criteria votes across participants
medECVotes = median(ECvotes, 2);
medEOVotes = median(EOvotes, 2);
avgECVotes = mean(ECvotes, 2);
avgEOVotes = mean(EOvotes, 2);
totalMedECVote = median(medECVotes);
totalMedEOVote = median(medEOVotes);

% find median criterion vote across participants
medCriterionECVotes = median(ECvotes, 1);
medCriterionEOVotes = median(EOvotes, 1);

% find difference between EC and EO vote for across participants
ECEOdiff = ECvotes - EOvotes;

% average difference per criteria
criterionECEOdiff = mean(ECEOdiff);

% average difference between median vote of all criteria across
% participants
subjECEOdiff = medEOVotes - medECVotes;

% difference between average vote of all criteria across participants
subjECEOdiff_avg = avgEOVotes - avgECVotes;

% make histograms for EC vs. EO median criterion votes for all subjects
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figure;
histogram(medECVotes, edges);
title('Eyes Closed Optimal Cluster Numbers (Median Vote Across Criteria)');
saveas(gcf, 'figures/EC_median_criteria_vote_histogram');

figure;
histogram(medEOVotes, edges);
title('Eyes Open Optimal Cluster Numbers (Median Vote Across Criteria)');
saveas(gcf, 'figures/EO_median_criteria_vote_histogram');

% make bar graph for median criterion vote per criterion
figure;
names = categorical(sortedNames);
names = reordercats(names, sortedNames);
bar(names, [medCriterionECVotes; medCriterionEOVotes]');
legend({'Eyes Closed', 'Eyes Open'});
title('Median Vote Per Criterion Across Subjects');
saveas(gcf, 'figures/median_vote_per_criterion_histogram.fig');

% make bar graph for average votes per criterion
figure;
bar(names, avgVotes_ECEO);
legend({'Eyes Closed', 'Eyes Open'});
title('Average Vote Per Criterion Across Subjects');
saveas(gcf, 'figures/average_vote_per_criterion_histogram.fig');

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