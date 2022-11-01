clear variables

% CHANGE DATA TYPE HERE %
dataName = 'ECEO Mean 71 channels';
% CHANGE DIRECTORY HERE %
folderName = fullfile('../criteria csvs', 'meanmap_csvs');

files = dir(folderName);        
filenames = {files(3:end).name};
nSubjects = 44;
ClusterNumbers = 4:10;
numClustSolutions = numel(ClusterNumbers);

% COMMENT OUT EXCLUDED CRITERIA HERE
% criteria(1).name   = 'S';          % Silhouette
criteria(1).name   = 'DB';         % Davies-Bouldin
criteria(2).name   = 'PB';         % Point-Biserial
criteria(3).name   = 'D';          % Dunn
criteria(4).name   = 'KL';         % Krzanowski-Lai
criteria(5).name   = 'KLnrm';      % Normalized Krzanowski-Lai
criteria(6).name   = 'CV';         % Cross-Validation
criteria(7).name   = 'FVG';        % Frey and Van Groenewoud
% criteria(9).name   = 'CH';         % Calinski-Harabasz

% criteria(1).fullname   = 'Silhouette';
criteria(1).fullname   = 'Davies-Bouldin';
criteria(2).fullname   = 'Point-Biserial';
criteria(3).fullname   = 'Dunn';
criteria(4).fullname   = 'Krzanowski-Lai';
criteria(5).fullname   = 'Normalized Krzanowski-Lai';
criteria(6).fullname   = 'Cross-Validation';
criteria(7).fullname   = 'Frey and Van Groenewoud';
% criteria(9).fullname   = 'Calinski-Harabasz';

criteria(1).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(2).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(3).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(4).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(5).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(6).ECvalues = nan(nSubjects/2, numClustSolutions);
criteria(7).ECvalues = nan(nSubjects/2, numClustSolutions);
% criteria(8).values = nan(nSubjects, numClustSolutions);
% criteria(9).values = nan(nSubjects, numClustSolutions);

criteria(1).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(2).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(3).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(4).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(5).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(6).EOvalues = nan(nSubjects/2, numClustSolutions);
criteria(7).EOvalues = nan(nSubjects/2, numClustSolutions);

% sort names
[criterionNames, sortIdx] = sort({criteria.name});
criteria = criteria(sortIdx);

% collect criteria values from using all GFP peaks for all subjects
ECcount = 1;
EOcount = 1;
for i=1:numel(filenames)
    tbl = readtable(fullfile(folderName, filenames{i}));
    
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    criteriaValues = tbl(isAllPeaks, :);

    for j=1:numel(criterionNames)
        c = criteriaValues{matches(criteriaValues.criterion_name, criterionNames{j}), 4:end};
        if contains(filenames{i}, 'EC')
            criteria(matches({criteria.name}, criterionNames{j})).ECvalues(ECcount,:) = c;
        elseif contains(filenames{i}, 'EO')
            criteria(matches({criteria.name}, criterionNames{j})).EOvalues(EOcount,:) = c;
        end            
    end

    if contains(filenames{i}, 'EC')
        ECcount = ECcount + 1;
    elseif contains(filenames{i}, 'EO')
        EOcount = EOcount + 1;
    end
end

% make histograms
figureName = sprintf('EC Criteria Histograms - %s', dataName);
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figure('Name', figureName);
tiledlayout(3,3);

for i=1:numel(criteria)
    nexttile;
    [M, ind] = max(criteria(i).ECvalues, [], 2);

    histogram(ClusterNumbers(ind), edges);
    title(criteria(i).fullname);
end
filename = sprintf('EC vs EO criteria histograms/EC Criteria Histograms_%s.fig', dataName);
saveas(gcf, filename);

figureName = sprintf('EO Criteria Histograms - %s', dataName);
edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
figure('Name', figureName);
tiledlayout(3,3);

for i=1:numel(criteria)
    nexttile;
    [M, ind] = max(criteria(i).EOvalues, [], 2);

    histogram(ClusterNumbers(ind), edges);
    title(criteria(i).fullname);
end
filename = sprintf('EC vs EO criteria histograms/EO Criteria Histograms_%s.fig', dataName);
saveas(gcf, filename);