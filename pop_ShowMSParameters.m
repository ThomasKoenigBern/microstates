% pop_ShowMSParameters() Generates plots of the temporal dynamics
% parameters for all included datasets. If one dataset is selected,
% individual parameters will be displayed as bar graphs, otherwise the
% distribution of parameters across datasets will be displayed as swarm
% charts. pop_FitMSMaps() must be used before calling this function
% to extract temporal parameters.
%
% Usage:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, SelectedSets, 'Classes', 
%       Classes, 'Visible', true/false)
%
% Specify the number of classes in the fitting solution using the "Classes"
% argument.
% Ex:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, 1:5, 'Classes', 4);
%
% The figure with plotted temporal dynamics parameters can be 
% generated but not displayed. This option is useful if you would like to 
% save the plots in a script but avoid the window appearing. To generate an 
% invisible figure, set the "Visible" argument to 0.
% Ex:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, 1:5, 'Classes', 4, 'Visible', 0);
%   saveas(fig_h, 'temporal_parameters.png');
%   close(fig_h);
%
% Graphical interface:
%
%   "Choose sets to plot"
%   -> Select sets whose temporal parameters should be plotted
%   -> Command line equivalent: "SelectedSets"
%
%   "Select number of classes"   
%   -> Select which fitting solution should be used
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG for which temporal parameters will be
%   plotted. Selected sets must contain temporal parameters in the "MSStats"
%   field of "msinfo" (obtained from calling pop_FitMSMaps). If sets
%   are not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Integer indicating the fitting solution whose associated temporal 
%   parameters will be plotted.
%
%   "Visible"
%   -> 1 = Show GUI with plotted temporal parameters, 0 = keep GUI hidden.
%   Useful for scripting purposes to generate and save figures from the
%   returned figure handle without the figures popping up. Ignored if "gui"
%   is 0.
%
% Outputs:
%
%   "fig_h"
%   -> Figure handle to window with plotted temporal dynamics parameters
%   for all selected sets. Useful for scripting purposes to save figures.
%
%   "com"
%   -> Command necessary to replicate the computation
%              
% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function [fig_h, com] = pop_ShowMSParameters(AllEEG, varargin)

    [~,nogui] = eegplugin_microstatelab;

    %% Set defaults for outputs
    com = '';
    fig_h = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_ShowMSParameters';

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    addParameter(p, 'Visible', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    
    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;
    Visible = p.Results.Visible;

    if nogui && (isempty(SelectedSets) || isempty(nClasses) || Visible)
        error("This function needs a GUI");
    end

    %% SelectedSets validation        
    HasStats = arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasStats & ~HasDyn);
    
    if isempty(AvailableSets)
        errorMessage = ['No sets with temporal parameters found. ' ...
            'Use Tools->Backfit microstate maps to EEG to extract temporal dynamics.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Plot temporal parameters error');
            return;
        else
            error(errorMessage);
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets do not contain temporal parameters: %s. ' ...
                'Use pop_FitMSMaps() to extract temporal dynamics first.'], invalidSetsTxt);
        end
    % Otherwise, prompt user to choose sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1 1], 'geomvert', [1 1 1 1 4], 'uilist', {
                    { 'Style', 'text'    , 'string', 'Choose sets to plot', 'fontweight', 'bold'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                    { 'Style', 'text'    , 'string', 'If one is chosen, individual dynamics will be displayed.'} ...
                    { 'Style', 'text'    , 'string', 'If multiple are chosen, aggregate dynamics will be displayed.'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Plot temporal parameters');

        if isempty(res); return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Plot temporal parameters error');
            return;
        end
    end        


    SelectedEEG = AllEEG(SelectedSets);    

    %% Classes validation
    classRanges = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.Classes, 1:numel(SelectedEEG), 'UniformOutput', false)';
    commonClasses = classRanges{1};
    for i=2:numel(SelectedSets)
        commonClasses = intersect(commonClasses, classRanges{i});
    end

    if isempty(commonClasses)
        errorMessage = 'No overlap in cluster solutions used for fitting found between all selected sets.';
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end
    if matches('Classes', p.UsingDefaults)
        classChoices = sprintf('%i Classes|', commonClasses);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes'} ...
              {'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Tag', 'Classes'}}, ...
              'title', 'Plot temporal parameters');
        
        if isempty(res); return; end
        nClasses = commonClasses(outstruct.Classes);
    else
        if ~ismember(nClasses, commonClasses)
            classesTxt = sprintf('%i, ', commonClasses);
            classesTxt = classesTxt(1:end-2);
            error(['Not all selected sets to plot contain microstate statistics for the %i cluster solution. ' ...
                'Valid class numbers include: %s.'], nClasses, classesTxt);
        end
    end

    %% Verify compatibility between selected sets

    % Check for consistent fitting parameters
    PeakFit = arrayfun(@(x) logical(SelectedEEG(x).msinfo.FitPar.PeakFit), 1:numel(SelectedEEG));
    unmatched = ~(all(PeakFit == 1) || all(PeakFit == 0));

    if all(PeakFit == 0)
        b = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.b, 1:numel(SelectedEEG));
        lambda = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.lambda, 1:numel(SelectedEEG));
        unmatched = ~all(b == b(1)) || ~all(lambda == lambda(1));
    end

    if unmatched
        errorMessage = 'Fitting parameters differ between selected sets.';  
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent fitting templates
    FittingTemplates = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses).FittingTemplate, 1:numel(SelectedEEG), 'UniformOutput', false);
    if numel(unique(FittingTemplates)) > 1
        errorMessage = 'Fitting templates differ across datasets.';
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent labels
    labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses).TemplateLabels, 1:numel(SelectedEEG), 'UniformOutput', false);
    labels = vertcat(labels{:});
    if any(arrayfun(@(x) numel(unique(labels(:,x))), 1:size(labels,2)) > 1)
        errorMessage = sprintf('Map labels of the %i cluster solution are inconsistent across datasets.', nClasses);
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
            return;
        else
            error(errorMessage);
        end
    end   

    %% Show GUI with plotted temporal parameters
    Labels = SelectedEEG(1).msinfo.MSStats(nClasses).TemplateLabels;
    if numel(SelectedSets) == 1
        figName = ['Microstate temporal parameters: ' SelectedEEG.setname];
        x = categorical(Labels);
        x = reordercats(x, Labels);
    else
        figName = 'Microstate temporal parameters';
        x = repmat(Labels, 1, numel(SelectedSets));
        x = categorical(x, Labels);
    end

    if Visible
        figVisible = 'on';
    else
        figVisible = 'off';
    end        

    % Get usable screen size
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('ToolBar', 'none', 'MenuBar', 'figure', 'Position', [-1000 -1000 0 0]);
    pause(0.2);
    titleBarHeight = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    delete(tempFig);
    % Use the largest monitor available
    monitorPositions = get(0, 'MonitorPositions');
    if size(monitorPositions, 1) > 1
        screenSizes = arrayfun(@(x) monitorPositions(x, 3)*monitorPositions(x,4), 1:size(monitorPositions, 1));
        [~, i] = max(screenSizes);
        screenSize = monitorPositions(i, :);
    else
        screenSize = get(0, 'ScreenSize');
    end
    figSize = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight-insets.bottom-insets.top];
    fig_h = figure('Name', figName, 'NumberTitle', 'off', 'Units', 'pixels', ...
        'Position', figSize, 'ToolBar', 'none', 'Visible', figVisible);
    datacursormode(fig_h, 'on');

    if numel(SelectedSets) == 1
        t = tiledlayout(fig_h, 2, 3);
    else
        plotsPanel = uipanel(fig_h, 'Units', 'normalized', 'Position', [0 0 .85 1], 'BorderType', 'none');
        t = tiledlayout(plotsPanel, 2, 3);       
        uicontrol(fig_h, 'Style', 'listbox', 'Units', 'normalized', 'Position', [.86 .02 .12 .96], ...
            'String', {SelectedEEG.setname}, 'Callback', {@setChanged, t}, 'UserData', struct('nClasses', nClasses));
        setnames = {};
        for i=1:numel(SelectedEEG)
            setnames = [setnames repmat({SelectedEEG(i).setname}, 1, nClasses)];
        end
        row1 = dataTipTextRow('Dataset:', setnames);
    end
    t.TileSpacing = 'compact';
    t.Padding = 'compact';    

    % GEV
    gevAx = nexttile(t, 1);
    if numel(SelectedSets) == 1
        bar(gevAx, x, SelectedEEG.msinfo.MSStats(nClasses).IndExpVar*100);
    else
        IndGEVs = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).IndExpVar*100), 1:numel(SelectedSets), 'UniformOutput', false));
        gevChart = swarmchart(gevAx, x, IndGEVs, 15, [0 0.4470 0.7410],'filled');  
        gevStr = arrayfun(@(x) sprintf('%2.2f%%', x), IndGEVs, 'UniformOutput', false);
        row2 = dataTipTextRow('GEV:', gevStr);
        gevChart.DataTipTemplate.DataTipRows = [row1 row2];
        gevChart.DataTipTemplate.Interpreter = 'none';
    end
    ymax = gevAx.YLim(2)*1.1;
    ylim(gevAx, [0 ymax]);
    title(gevAx, 'Explained Variance (%)');

    % Duration
    durAx = nexttile(t, 2);
    if numel(SelectedSets)  == 1
        bar(durAx, x, SelectedEEG.msinfo.MSStats(nClasses).MeanDuration*1000);
    else
        Durations = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).MeanDuration*1000), 1:numel(SelectedSets), 'UniformOutput', false));
        durChart = swarmchart(durAx, x, Durations, 15, [0 0.4470 0.7410],'filled');
        durStr = arrayfun(@(x) sprintf('%3.2f ms', x), Durations, 'UniformOutput', false);
        row2 = dataTipTextRow('Duration:', durStr);
        durChart.DataTipTemplate.DataTipRows = [row1 row2];
        durChart.DataTipTemplate.Interpreter = 'none';
    end
    ymax = durAx.YLim(2)*1.1;
    ylim(durAx, [0 ymax]);
    title(durAx, 'Mean Duration (ms)');

    % Occurrence
    occAx = nexttile(t, 4);
    if numel(SelectedSets) == 1
        bar(occAx, x, SelectedEEG.msinfo.MSStats(nClasses).MeanOccurrence);
    else
        Occurrences = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).MeanOccurrence), 1:numel(SelectedSets), 'UniformOutput', false));
        occStr = arrayfun(@(x) sprintf('%2.2f appear/s', x), Occurrences, 'UniformOutput', false);
        occChart = swarmchart(occAx, x, Occurrences, 15, [0 0.4470 0.7410],'filled');
        row2 = dataTipTextRow('Occurrence:', occStr);
        occChart.DataTipTemplate.DataTipRows = [row1 row2];
        occChart.DataTipTemplate.Interpreter = 'none';
    end
    ymax = occAx.YLim(2)*1.1;
    ylim(occAx, [0 ymax]);
    title(occAx, 'Mean Occurrence (appearances/s)');

    % Coverage
    covAx = nexttile(t, 5);
    if numel(SelectedSets) == 1
        bar(covAx, x, SelectedEEG.msinfo.MSStats(nClasses).Coverage);
    else
        Coverages = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).Coverage), 1:numel(SelectedSets), 'UniformOutput', false));
        covStr = arrayfun(@(x) sprintf('%2.2f%%', x), Coverages, 'UniformOutput', false);
        row2 = dataTipTextRow('Coverage:', covStr);
        covChart = swarmchart(covAx, x, Coverages, 15, [0 0.4470 0.7410],'filled');
        covChart.DataTipTemplate.DataTipRows = [row1 row2];
        covChart.DataTipTemplate.Interpreter = 'none';
    end
    ymax = covAx.YLim(2)*1.1;
    ylim(covAx, [0 ymax]);
    title(covAx, 'Coverage (%)');

    % GFP
    gfpAx = nexttile(t);
    if numel(SelectedSets) == 1
        bar(gfpAx, x, SelectedEEG.msinfo.MSStats(nClasses).MeanGFP);
    else
        GFPs = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).MeanGFP), 1:numel(SelectedSets), 'UniformOutput', false));
        gfpStr = arrayfun(@(x) sprintf('%2.2f uV', x), GFPs, 'UniformOutput', false);
        row2 = dataTipTextRow('GFP:', gfpStr);
        gfpChart = swarmchart(gfpAx, x, GFPs, 15, [0 0.4470 0.7410],'filled');
        gfpChart.DataTipTemplate.DataTipRows = [row1 row2];
        gfpChart.DataTipTemplate.Interpreter = 'none';
    end
    ymax = gfpAx.YLim(2)*1.1;
    ylim(gfpAx, [0 ymax]);
    title(gfpAx, 'Mean GFP (\muV)', 'Interpreter', 'tex');

    % Transition matrix
%         nexttile(t, 3);
%         if numel(SelectedSets) == 1
%             h = heatmap(t, Labels, Labels, MSStats.OrgTM, 'GridVisible', 'off');
%             h.Title = 'Transition Matrix';
%         else
%             avgTM = zeros(FitPar.nClasses);
%             for s=1:numel(SelectedSets)
%                 avgTM = avgTM + MSStats(s).OrgTM;
%             end
%             avgTM = avgTM/numel(SelectedSets);
%             h = heatmap(t, Labels, Labels, avgTM, 'GridVisible', 'off');
%             h.Title = 'Average Transition Matrix';
%         end
%         h.XLabel = 'To';
%         h.YLabel = 'From';

    % Delta transition matrix
    nexttile(t, 6);
    if numel(SelectedSets) == 1
        lim = abs(max(SelectedEEG.msinfo.MSStats(nClasses).DeltaTM, [], 'all'));
        h2 = heatmap(t, Labels, Labels, SelectedEEG.msinfo.MSStats(nClasses).DeltaTM, 'Colormap', bluered(256), 'ColorLimits', [-lim lim]);
        h2.Title = 'Observed - Expected Transition Probabilities';
    else
        avgTM = zeros(nClasses);
        for s=1:numel(SelectedSets)
            avgTM = avgTM + SelectedEEG(s).msinfo.MSStats(nClasses).DeltaTM;
        end
        avgTM = avgTM/numel(SelectedSets);
        lim = abs(max(avgTM, [], 'all'));
        h2 = heatmap(t, Labels, Labels, avgTM, 'Colormap', bluered(256), 'ColorLimits', [-lim lim]);
        h2.Title = 'Mean Observed - Expected Transition Probabilities';
    end
    h2.XLabel = 'To';
    h2.YLabel = 'From';

    com = sprintf('fig_h = pop_ShowMSParameters(%s, %s, ''Classes'', %i, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), nClasses, Visible);

end

function setChanged(src, ~, t)
    nClasses = src.UserData.nClasses;
    for i=1:numel(t.Children)
        if strcmp(t.Children(i).Title, 'Mean Observed - Expected Transition Probabilities')
            continue;
        end
        % Delete old data tips
%         if isfield(t.Children(i).UserData, 'dataTips')
%             if ~isempty(t.Children(i).UserData.dataTips)
%                 for j=1:numel(t.Children(i).UserData.dataTips)
%                     delete(t.Children(i).UserData.dataTips(j));
%                 end
%             end
%         end
        % Highlight the data points associated with the selected set
        t.Children(i).Children.CData = repmat([0 .447 .741], numel(t.Children(i).Children.XData), 1);
        setIdx = nClasses*(src.Value-1)+1:nClasses*src.Value;
        t.Children(i).Children.CData(setIdx, :) = repmat([.85 .325 .098], nClasses, 1);
        t.Children(i).Children.SizeData = repmat(15, numel(t.Children(i).Children.XData), 1);
        t.Children(i).Children.SizeData(setIdx) = 60;
%         % Make new data tips        
%         t.Children(i).UserData.dataTips = [];
%         for j=setIdx
%             x = t.Children(i).Children.XData(j);
%             y = t.Children(i).Children.YData(j);
%             t.Children(i).UserData.dataTips = [t.Children(i).UserData.dataTips ...
%                 datatip(t.Children(i).Children, x, y)];
%         end
    end
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;
    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end    
    % check if set has FitPar
    if ~isfield(in.msinfo, 'FitPar')
        return;
    end
    % check if FitPar contains Rectify/Normalize parameters
    if ~isfield(in.msinfo.FitPar, 'Rectify')
        return;
    else
        hasDyn = true;
    end
end

function hasStats = hasStats(in)
    hasStats = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set has MSStats
    if ~isfield(in.msinfo, 'MSStats')
        return;
    else
        hasStats = true;
    end
end