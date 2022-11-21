function interactive_metacriterion_explorer(subjNum, dataType)
   
    scriptPath = fileparts(mfilename('fullpath'));
    
    if strcmp(dataType, 'Subject-level 71 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_71channels');
    elseif strcmp(dataType, 'Subject-level 10-20 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_1020channels');
    elseif strcmp(dataType, 'ECEO Mean 71 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_71channels');
    elseif strcmp(dataType, 'ECEO Mean 10-20 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_1020channels');
    end

    % Load the selected subject's EC and EO criteria values
    if contains(dataType, 'Subject-level')
        ECfilename = sprintf('s%i_TD_EC_criteria_results.csv', subjNum);
        EOfilename = sprintf('s%i_TD_EO_criteria_results.csv', subjNum);
    elseif contains(dataType, 'Mean')
        ECfilename = sprintf('s%i_TD_EC_mean_criteria_results.csv', subjNum);
        EOfilename = sprintf('s%i_TD_EO_mean_criteria_results.csv', subjNum);
    end

    % Read in EC criteria
    tbl = readtable(fullfile(folderName, ECfilename));
        
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    ECcriteria = tbl(isAllPeaks, :);

    % Read in EO criteria
    tbl = readtable(fullfile(folderName, EOfilename));
        
    % Rename table column names and remove header row with NaN values
    tbl.Properties.VariableNames = {'run_no', 'sample_size', 'criterion_name', ...
        'clust4', 'clust5', 'clust6', 'clust7', 'clust8', 'clust9', 'clust10'};
    tbl(1,:) = [];

    % Find rows with criteria values from using all GFP peaks
    isAllPeaks = (tbl.sample_size ~= 1000) & (tbl.sample_size ~= 2000) & (tbl.sample_size ~= 4000);
    EOcriteria = tbl(isAllPeaks, :);

    ClusterNumbers = 4:10;
    numClustSolutions = numel(ClusterNumbers);

    % make interactive figure
    fig = uifigure;
    fig.Name = sprintf('Interactive Criterion Explorer - S%i - %s', subjNum, dataType);
    gl = uigridlayout(fig, [1 2]);
    gl.ColumnWidth = {'1x', '10x'};
    
    % add criteria panel
    criteriaPanel = uipanel(gl);
    criteriaPanel.Title = 'Select criteria to include';
    criteriaPanel.Layout.Column = 1;
    panelgl = uigridlayout(criteriaPanel, [1 1]);
    criteriaListBox = uilistbox(panelgl);
    criteria = {'CV', 'DB', 'D', 'FVG', 'KL', 'KLnrm', 'PB'};
    criteriaListBox.Items = criteria;
    criteriaListBox.Multiselect = 'on';
    criteriaListBox.Value = {};

    % add plot panel
    linePlotsPanel = uipanel(gl);
    linePlotsPanel.Title = sprintf('S%i Metacriterion Line Plots: EC vs EO', subjNum);
    t = tiledlayout(linePlotsPanel, 2, 3);
    t.TileSpacing = 'compact';
    t.Padding = 'compact';

    % EC axes
    ECcriteriaAx = nexttile(t);
    title(ECcriteriaAx, 'Normalized Criteria Values: EC');
    xticks(ECcriteriaAx, 4:10);
    yticks(ECcriteriaAx, 0:0.1:1);
    EChistogramAx = nexttile(t);
    title(EChistogramAx, 'Optimal Cluster Numbers: EC');
    ECmetacriterionAx = nexttile(t);
    title(ECmetacriterionAx, 'IQM*SNR Metacriterion: EC');
    xticks(ECmetacriterionAx, 4:10);
    yticks(ECmetacriterionAx, 0:0.1:1);

    % EO axes
    EOcriteriaAx = nexttile(t);
    title(EOcriteriaAx, 'Normalized Criteria Values: EO');
    xticks(EOcriteriaAx, 4:10);
    yticks(EOcriteriaAx, 0:0.1:1);
    EOhistogramAx = nexttile(t);
    title(EOhistogramAx, 'Optimal Cluster Numbers: EO');
    EOmetacriterionAx = nexttile(t);
    title(EOmetacriterionAx, 'IQM*SNR Metacriterion: EO');
    xticks(EOmetacriterionAx, 4:10);
    yticks(EOmetacriterionAx, 0:0.1:1);

    criteriaListBox.ValueChangedFcn = {@listboxCallback};

    function listboxCallback(src, event)
        selectedCriteria = event.Value;
        numCriteria = numel(selectedCriteria);
        [selectedCriteria, sortIdx] = sort(selectedCriteria);
    
        cla(ECcriteriaAx);
        cla(EChistogramAx);
        cla(ECmetacriterionAx);
        cla(EOcriteriaAx);
        cla(EOhistogramAx);
        cla(EOmetacriterionAx);

        % EC axes
        % criteria
        ECcriteriavalues = nan(numel(selectedCriteria), numClustSolutions);
        for c=1:numel(selectedCriteria)
            ECcriteriavalues(c, :) = ECcriteria{matches(ECcriteria.criterion_name, selectedCriteria{c}), 4:end};
        end
        plot(ECcriteriaAx, ClusterNumbers, ECcriteriavalues');
        legend(ECcriteriaAx, selectedCriteria);

        % optimal numbers histogram
        [M, ind] = max(ECcriteriavalues, [], 2);
        edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
        histogram(EChistogramAx, ClusterNumbers(ind), edges);

        % metacriterion
        % compute IQM
        criterionIQM = sort(ECcriteriavalues);                          % first sort the columns and make copy of array
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
        IQR = iqr(ECcriteriavalues);
    
        % compute metacriterion
        metacriterion = (IQM.^2)./IQR;
    
        % normalize
        metacriterion = (metacriterion - min(metacriterion))/(max(metacriterion) - min(metacriterion));

        plot(ECmetacriterionAx, ClusterNumbers, metacriterion);

        % EO axes
        % criteria
        EOcriteriavalues = nan(numel(selectedCriteria), numClustSolutions);
        for c=1:numel(selectedCriteria)
            EOcriteriavalues(c, :) = EOcriteria{matches(EOcriteria.criterion_name, selectedCriteria{c}), 4:end};
        end
        plot(EOcriteriaAx, ClusterNumbers, EOcriteriavalues');
        legend(EOcriteriaAx, selectedCriteria);

        % optimal numbers histogram
        [M, ind] = max(EOcriteriavalues, [], 2);
        edges = ClusterNumbers(1)-0.5:1:ClusterNumbers(end)+0.5;
        histogram(EOhistogramAx, ClusterNumbers(ind), edges);

        % metacriterion
        % compute IQM
        criterionIQM = sort(EOcriteriavalues);                          % first sort the columns and make copy of array
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
        IQR = iqr(EOcriteriavalues);
    
        % compute metacriterion
        metacriterion = (IQM.^2)./IQR;
    
        % normalize
        metacriterion = (metacriterion - min(metacriterion))/(max(metacriterion) - min(metacriterion));

        plot(EOmetacriterionAx, ClusterNumbers, metacriterion);
    
        % Update titles and axis marks
        % EC axes
        title(ECcriteriaAx, 'Normalized Criteria Values: EC');
        xticks(ECcriteriaAx, 4:10);
        yticks(ECcriteriaAx, 0:0.1:1);
        title(EChistogramAx, 'Optimal Cluster Numbers: EC');
        title(ECmetacriterionAx, 'IQM*SNR Metacriterion: EC');
        xticks(ECmetacriterionAx, 4:10);
        yticks(ECmetacriterionAx, 0:0.1:1);
    
        % EO axes
        title(EOcriteriaAx, 'Normalized Criteria Values: EO');
        xticks(EOcriteriaAx, 4:10);
        yticks(EOcriteriaAx, 0:0.1:1);
        title(EOhistogramAx, 'Optimal Cluster Numbers: EO');
        title(EOmetacriterionAx, 'IQM*SNR Metacriterion: EO');
        xticks(EOmetacriterionAx, 4:10);
        yticks(EOmetacriterionAx, 0:0.1:1);
    end

end