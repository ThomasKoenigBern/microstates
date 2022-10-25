files = dir('csvs');
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);
includedCriteria = ["CV", "D", "DB", "FVG", "KL", "KLnrm", "PB"];     % change this for different versions of metacriterion
numCriteria = numel(includedCriteria);

ECmetacriteria = zeros(nSubjects/2, numClustSolutions);
EOmetacriteria = zeros(nSubjects/2, numClustSolutions);

ECmcvotes = zeros(nSubjects/2, 1);
EOmcvotes = zeros(nSubjects/2, 1);

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

    if contains(filename, 'EC')
        ECmetacriteria(ECcount, :) = metacriterion;
        ECmcvotes(ECcount) = vote;
        ECcount = ECcount + 1;
    elseif contains(filename, 'EO')
        EOmetacriteria(EOcount, :) = metacriterion;
        EOmcvotes(EOcount) = vote;
        EOcount = EOcount + 1;
    end
end

% make histograms for EC vs. EO metacriterion votes for all subjects
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figure;
histogram(ECmcvotes, edges);
title('Eyes Closed Optimal Cluster Numbers (IQM/SNR Metacriterion)');
saveas(gcf, 'figures/EC_metacriterion_vote_histogram');

figure;
histogram(EOmcvotes, edges);
title('Eyes Open Optimal Cluster Numbers (IQM/SNR Metacriterion)');
saveas(gcf, 'figures/EO_metacriterion_vote_histogram');

% compute mean EC and EO optimal cluster numbers predicted by metacriterion
meanECvote = mean(ECmcvotes);
meanEOvote = mean(EOmcvotes);
