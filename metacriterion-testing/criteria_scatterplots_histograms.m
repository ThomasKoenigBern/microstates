files = dir('csvs');
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);

criteria(1).name   = 'S';          % Silhouette
criteria(2).name   = 'DB';         % Davies-Bouldin
criteria(3).name   = 'PB';         % Point-Biserial
criteria(4).name   = 'D';          % Dunn
criteria(5).name   = 'KL';         % Krzanowski-Lai
criteria(6).name   = 'KLnrm';      % Normalized Krzanowski-Lai
criteria(7).name   = 'CV2';        % Cross-Validation
criteria(8).name   = 'FVG';        % Frey and Van Groenewoud
criteria(9).name   = 'CH';         % Calinski-Harabasz

criteria(1).fullname   = 'Silhouette';
criteria(2).fullname   = 'Davies-Bouldin';
criteria(3).fullname   = 'Point-Biserial';
criteria(4).fullname   = 'Dunn';
criteria(5).fullname   = 'Krzanowski-Lai';
criteria(6).fullname   = 'Normalized Krzanowski-Lai';
criteria(7).fullname   = 'Cross-Validation';
criteria(8).fullname   = 'Frey and Van Groenewoud';
criteria(9).fullname   = 'Calinski-Harabasz';

criteria(1).values = nan(nSubjects, numClustSolutions);
criteria(2).values = nan(nSubjects, numClustSolutions);
criteria(3).values = nan(nSubjects, numClustSolutions);
criteria(4).values = nan(nSubjects, numClustSolutions);
criteria(5).values = nan(nSubjects, numClustSolutions);
criteria(6).values = nan(nSubjects, numClustSolutions);
criteria(7).values = nan(nSubjects, numClustSolutions);
criteria(8).values = nan(nSubjects, numClustSolutions);
criteria(9).values = nan(nSubjects, numClustSolutions);

% sort names
[criterionNames, sortIdx] = sort({criteria.name});
criteria = criteria(sortIdx);

% collect criteria values from using all GFP peaks for all subjects
for i=1:numel(filenames)
    tbl = readtable(fullfile('csvs', filenames{i}));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValues = tbl(isAllPeaks, :);

    for j=1:numel(criterionNames)
        c = criteriaValues{matches(criteriaValues.criterion_name, criterionNames{j}), 4:end};
        criteria(matches({criteria.name}, criterionNames{j})).values(i,:) = c;
    end
end

% make scatterplots
figure;
tiledlayout(3,3);

for i=1:numel(criteria)
    nexttile;
    scatter(ClusterNumbers, criteria(i).values', 10, 'filled');
    title(criteria(i).fullname);
end
saveas(gcf, 'figures/criteria_scatterplots.fig');

% make histograms
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figure;
tiledlayout(3,3);

for i=1:numel(criteria)
    nexttile;
    [M, ind] = max(criteria(i).values, [], 2);

    histogram(ClusterNumbers(ind), edges);
    title(criteria(i).fullname);
end
saveas(gcf, 'figures/criteria_histograms.fig');