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

function PlotMSMaps2(fh, MapPanel, MSMaps, chanlocs, varargin)
    p = inputParser;       
    addParameter(p, 'Background', true,  @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'Label', true,  @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'ShowProgress', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'Setname', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));
    addParameter(p, 'ShowExpVar', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    parse(p, varargin{:});
    Background = p.Results.Background;
    Label = p.Results.Label;
    ShowProgress = p.Results.ShowProgress;
    setname = p.Results.Setname;
    ShowExpVar = p.Results.ShowExpVar;

    ud = MapPanel.UserData;

    X = [chanlocs.X];
    Y = [chanlocs.Y];
    Z = [chanlocs.Z];

    % Make the axes array and tiled layout if they do not exist
    nRows = length(MSMaps);
    classes = arrayfun(@(x) size(MSMaps(x).Maps, 1), 1:length(MSMaps));
    if ~isfield(ud, 'Axes')          
        nCols = max(classes);
        ud.Axes = cell(nRows,1);
        for i=1:numel(classes)
            ud.Axes{i} = cell(1,classes(i));
        end
        updateRows = 1:nRows;
    else        
        allClasses = cellfun(@length, ud.Axes);
        nCols = max(allClasses);
        updateRows = find(ismember(allClasses, classes));
    end
    if ~isfield(ud, 'MapLayout')
        ud.MapLayout = tiledlayout(MapPanel, nRows, nCols, ...
            'TileSpacing', 'tight', 'Padding', 'tight');
    end

    if ShowProgress        
        mapsPlotted = 0;
        totalMaps = sum(classes);
        if strcmp(MapPanel.Parent.Type, 'uipanel')
            progressBar = uiprogressdlg(fh, 'Message', sprintf('Plotting maps for %s...', setname), ...
                'Value', 0, 'Cancelable', 'on');
        else
            nSteps = 20;
            step = 0;
            fprintf(1, 'Plotting maps for %s: |', setname);
            strLength = fprintf(1, [repmat(' ', 1, nSteps - step) '|   0%%']);
            tic
        end
    end

    for y = 1:numel(updateRows)
        y_pos = updateRows(y);
        for x_pos = 1:classes(y)
            % Make the axes if they do not exist
            if isempty(ud.Axes{y_pos}{x_pos})
                ax = axes('Parent', ud.MapLayout);
                tilenum = y_pos*nCols - nCols + x_pos;
                ax.Layout.Tile = tilenum;
                ud.Axes{y_pos}{x_pos} = ax;
            end

            % Plot map and add title            
            if Background
                BackColor = MSMaps(y).ColorMap(x_pos,:);
                dspCMap3(ud.Axes{y_pos}{x_pos}, double(MSMaps(y).Maps(x_pos,:)),[X;Y;Z],'NoScale', ...
                    'Resolution',2,'Background',BackColor,'ShowNose',15);
            else
                dspCMap3(ud.Axes{y_pos}{x_pos}, double(MSMaps(y).Maps(x_pos,:)),[X;Y;Z],'NoScale', ...
                    'Resolution',2,'ShowNose',15);
            end
            ud.Axes{y_pos}{x_pos}.Toolbar.Visible = 'off';
            if Label
                title(ud.Axes{y_pos}{x_pos}, MSMaps(y).Labels(x_pos), ...
                    'FontSize', 9, 'Interpreter','none');
            end

            % Add explained variance labels if requested
            if ShowExpVar
                if ~isfield(MSMaps, 'SharedVar')
                    if ~isempty(MSMaps(y).ExpVar) && ~all(isnan(MSMaps(y).ExpVar))
                        if x_pos == 1
                            ExpVar = sum(MSMaps(y).ExpVar);
                            ExpVarStr = sprintf(' %2.2f%% ', ExpVar*100);
                            ylabel(ud.Axes{y_pos}{x_pos}, ExpVarStr, 'FontSize', 10, 'Rotation', 0, 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
                        end
                        if numel(MSMaps(y).ExpVar) > 1
                            IndExpVar = MSMaps(y).ExpVar(x_pos);
                            IndExpVarStr = sprintf('%2.2f%%', IndExpVar*100);
                            if Background
                                xlabel(ud.Axes{y_pos}{x_pos}, IndExpVarStr, 'FontSize', 9);
                            else
                                subtitle(ud.Axes{y_pos}{x_pos}, IndExpVarStr, 'FontSize', 9);
                            end
                        end
                    end                    
                else
                    if x_pos == 1
                        SharedVar = mean(MSMaps(y).SharedVar);
                        SharedVarStr = sprintf(' %2.2f%% ', SharedVar*100);
                        ylabel(ud.Axes{y_pos}{x_pos}, SharedVarStr, 'FontSize', 10, 'Rotation', 0, 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
                    end
                    IndSharedVar = MSMaps(y).SharedVar(x_pos);
                    IndSharedVarStr = sprintf('%2.2f%%', IndSharedVar*100);
                    if Background
                        xlabel(ud.Axes{y_pos}{x_pos}, IndSharedVarStr, 'FontSize', 9);
                    else
                        subtitle(ud.Axes{y_pos}{x_pos}, IndSharedVarStr, 'FontSize', 9);
                    end
                end        
            end
            
            % Add context menu
            contextMenu = uicontextmenu(fh);
            uimenu(contextMenu, 'Text', 'Plot map in new window', 'MenuSelectedFcn', {@plotIndMap, ud.Axes{y_pos}{x_pos}});
            ud.Axes{y_pos}{x_pos}.ContextMenu = contextMenu;
            for child=1:numel(ud.Axes{y_pos}{x_pos}.Children)
                ud.Axes{y_pos}{x_pos}.Children(child).ContextMenu = contextMenu;
            end            

            if ShowProgress
                mapsPlotted = mapsPlotted + 1;
                if strcmp(MapPanel.Parent.Type, 'uipanel')
                    progressBar.Value = mapsPlotted/totalMaps;
                    if progressBar.CancelRequested
                        delete(fh);
                        return;
                    end                    
                else
                    [step, strLength] = mywaitbar(mapsPlotted, totalMaps, step, nSteps, strLength);
                end
            end
        end
        if strcmp(fh.Visible, 'on')
            drawnow limitrate            
        end
    end

    if ShowProgress && ~strcmp(MapPanel.Parent.Type, 'uipanel')
        mywaitbar(mapsPlotted, totalMaps, step, nSteps, strLength);
        fprintf('\n');
    end

    MapPanel.UserData = ud;
end

function plotIndMap(~, ~, ax)
    fig = figure;
    newAx = copyobj(ax, fig);
    newAx.Units = 'normalized';
    newAx.Position = [0 0 1 1];
end