% Interactive figure that allows selecting a variable number of subjects
% whose normalized criterion values will be displayed.
%
% Inputs:
%   criterionName: CH, CV, DB, D, FVG, KL, KLnrm, PB, S
%
%   dataType:
%       "71 channels": criteria derived from comparing the subject-level
%        maps to the subject-level data, using all 71 channels 
%
%       "10-20 channels": criteria derived from comparing the subject-level
%        maps to the subject-level data, using only 10-20 channels
%
%       "ECEO Mean 71 channels": criteria derived from comparing the
%        mean-level EC or EO maps to the subject-level data, using all 71
%        channels
%
%       "ECEO Mean 10-20 channels": criteria derived from comparing the
%        mean-level EC or EO maps to the subject-level data, using only
%        10-20 channels


function fig = interactive_criteria_explorer(criterionName, dataType)
   
    scriptPath = fileparts(mfilename('fullpath'));
    
    if strcmp(dataType, '71 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_71channels');
    elseif strcmp(dataType, '10-20 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'individual_csvs_1020channels');
    elseif strcmp(dataType, 'ECEO Mean 71 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_71channels');
    elseif strcmp(dataType, 'ECEO Mean 10-20 channels')
        folderName = fullfile(scriptPath, '../criteria csvs', 'meanmap_csvs_1020channels');
    end

    files = dir(folderName);        
    filenames = {files(3:end).name};
    nSubjects = 22;
    ClusterNumbers = 4:10;
    numClustSolutions = numel(ClusterNumbers);

    ECcriterion = nan(nSubjects, numClustSolutions);
    EOcriterion = nan(nSubjects, numClustSolutions);    

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
    
        c = criteriaValues{matches(criteriaValues.criterion_name, criterionName), 4:end};
        if contains(filenames{i}, 'EC')
            ECcriterion(ECcount,:) = c;
        elseif contains(filenames{i}, 'EO')
            EOcriterion(EOcount,:) = c;
        end            
    
        if contains(filenames{i}, 'EC')
            ECcount = ECcount + 1;
        elseif contains(filenames{i}, 'EO')
            EOcount = EOcount + 1;
        end
    end
    
    % make interactive figure
    fig = uifigure;
    fig.Name = sprintf('Interactive Criterion Explorer - %s - %s', dataType, criterionName);
    gl = uigridlayout(fig, [1 2]);
    gl.ColumnWidth = {'1x', '10x'};
    
    % add subjects panel
    subjectsPanel = uipanel(gl);
    subjectsPanel.Title = 'Select subjects to display';
    subjectsPanel.Layout.Column = 1;
    panelgl = uigridlayout(subjectsPanel, [1 1]);
    subjectsListBox = uilistbox(panelgl);
    subjects = arrayfun(@(x) sprintf('S%i', x), 1:22, 'UniformOutput', false);
    subjectsListBox.Items = subjects;
    subjectsListBox.ItemsData = 1:22;
    subjectsListBox.Multiselect = 'on';
    subjectsListBox.Value = {};

    % add plot panel
    linePlotsPanel = uipanel(gl);
    linePlotsPanel.Title = sprintf('%s Line Plots: EC vs EO', criterionName);
    t = tiledlayout(linePlotsPanel, 1, 2);
    t.TileSpacing = 'compact';
    t.Padding = 'compact';
    ax1 = nexttile(t);
    title(ax1, sprintf('Normalized %s Values: EC', criterionName));
    xticks(ax1, 4:10);
    yticks(ax1, 0:0.1:1);
    ax2 = nexttile(t);
    title(ax2, sprintf('Normalized %s Values: EO', criterionName));
    xticks(ax2, 4:10);
    yticks(ax2, 0:0.1:1);

    subjectsListBox.ValueChangedFcn = {@listboxCallback};

    function listboxCallback(src, event)
        selectedSubjects = event.Value;
    
        cla(ax1);
        cla(ax2);
        
        plot(ax1, ClusterNumbers, ECcriterion(selectedSubjects, :));
        legend(ax1, subjects(selectedSubjects));
        plot(ax2, ClusterNumbers, EOcriterion(selectedSubjects, :));
        legend(ax2, subjects(selectedSubjects));
    
        title(ax1, sprintf('Normalized %s Values: EC', criterionName));
        xticks(ax1, 4:10);
        yticks(ax1, 0:0.1:1);
        title(ax2, sprintf('Normalized %s Values: EO', criterionName));
        xticks(ax2, 4:10);
        yticks(ax2, 0:0.1:1);    
    end

end