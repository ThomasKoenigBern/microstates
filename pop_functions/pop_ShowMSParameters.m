% pop_QuantMSTemplates() Generates plots of the temporal dynamics
% parameters for all included datasets. If one dataset is selected,
% individual parameters will be displayed as bar graphs, otherwise the
% distribution of parameters across datasets will be displayed as swarm
% charts.
%
% Usage:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, SelectedSets, 'key1', value1, 
%       'key2', value2)
%
% Specify the number of classes in the fitting solution using the "Classes"
% argument.
% Ex:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, 1:5, 'Classes', 4);
%
% The figure with plotted temporal dynamics parameters can also be 
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
%   -> Array of set indices of ALLEEG for which temporal parameters will be
%   plotted. Selected sets must contain temporal parameters in the "MSStats"
%   field of "msinfo" (obtained from calling pop_FitMSTemplates). If sets
%   are not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Scalar integer value indicating the fitting solution whose
%   associated temporal parameters will be plotted.
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
% Author: Thomas Koenig, University of Bern, Switzerland, 2016
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2016
% thomas.koenig@puk.unibe.ch
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

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global guiOpts;
    fig_h = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowMSParameters';
    p.FunctionName = funcName;

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    addParameter(p, 'Visible', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    
    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;
    Visible = p.Results.Visible;

    %% SelectedSets validation        
    AvailableSets = find(arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG)));
    
    if isempty(AvailableSets)
        errordlg2(['No sets with temporal parameters found. ' ...
            'Use Tools->Backfit template maps to EEG to extract temporal dynamics.'], 'Plot temporal parameters error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error('The following sets do not contain temporal parameters: %s', invalidSetsTxt);
        end
    % Otherwise, prompt user to choose sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
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
            errordlg2('You must select at least one set of microstate maps','Plot temporal parameters error');
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
        if ~isempty(p.UsingDefaults)
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
            errorMessage = sprintf(['Not all selected sets to export contain microstate statistics for the %i cluster solution. ' ...
                'Valid class numbers include: %s.'], nClasses, classesTxt);
            if ~isempty(p.UsingDefaults)
                errordlg2(errorMessage, 'Plot temporal parameters error');
            else
                error(errorMessage);
            end
            return;
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
        if ~isempty(p.UsingDefaults)
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
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    % Check for consistent fitting template sorting
    SortedBy = arrayfun(@(x) SelectedEEG(x).msinfo.MSStats(nClasses).SortedBy, 1:numel(SelectedEEG), 'UniformOutput', false);
    if numel(unique(SortedBy)) > 1
        errorMessage = 'Sorting information for the fitting template differs across datasets.';
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal parameters error');
        else
            error(errorMessage);
        end
        return;
    end

    %% Show GUI with plotted temporal parameters
    Labels = arrayfun(@(x) sprintf('MS %i.%i', nClasses, x), 1:nClasses, 'UniformOutput', false);
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
    
    t = tiledlayout(fig_h, 2, 3);
    t.TileSpacing = 'compact';
    t.Padding = 'compact';

    % GEV
    gevAx = nexttile(t, 1);
    if numel(SelectedSets) == 1
        bar(gevAx, x, SelectedEEG.msinfo.MSStats(nClasses).IndExpVar*100);
    else
        IndGEVs = cell2mat(arrayfun(@(x) double(SelectedEEG(x).msinfo.MSStats(nClasses).IndExpVar*100), 1:numel(SelectedSets), 'UniformOutput', false));
        swarmchart(gevAx, x, IndGEVs, 25, [0 0.4470 0.7410],'filled');
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
        swarmchart(durAx, x, Durations, 25, [0 0.4470 0.7410],'filled');
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
        swarmchart(occAx, x, Occurrences, 25, [0 0.4470 0.7410],'filled');
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
        swarmchart(covAx, x, Coverages, 25, [0 0.4470 0.7410],'filled');
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
        swarmchart(gfpAx, x, GFPs, 25, [0 0.4470 0.7410],'filled');
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

    com = sprintf('[fig_h, com] = pop_SaveMSParameters(%s, %s, ''Classes'', %i, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), nClasses, Visible);

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