function PlotMSMaps(fh, classes)
    UserData = get(fh,'UserData');

    X = cell2mat({UserData.chanlocs.X});
    Y = cell2mat({UserData.chanlocs.Y});
    Z = cell2mat({UserData.chanlocs.Z});

    if UserData.Edit
        classesToPlot = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses;
        classesToUpdate = classes;
    else
        if isfield(UserData, 'ClustPar')
            ClassRange = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses;
            classesToPlot = ClassRange(ismember(ClassRange, classes));
            classesToUpdate = classesToPlot;
        else
            classesToPlot = classes;
            classesToUpdate = classes;
        end
    end
    nRows = numel(classesToPlot);
    nCols = max(classesToPlot);

    if ~isfield(UserData, 'MapLayout')
        if ~isfield(UserData, 'TilePanel')
            UserData.MapLayout = tiledlayout(UserData.MapPanel, nRows, nCols, ...
                'TileSpacing', 'tight', 'Padding', 'tight');
        else
            UserData.MapLayout = tiledlayout(UserData.TilePanel, nRows, nCols, ...
                'TileSpacing', 'tight', 'Padding', 'tight');
        end
    end

    showProgress = false;
    if UserData.Scroll && ~isfield(UserData, 'Axes') && UserData.Visible
        showProgress = true;        
        mapsPlotted = 0;
        totalMaps = sum(classesToPlot);
        if ~strcmp(fh.Type, 'uitab')
            progressBar = uiprogressdlg(fh, 'Message', 'Plotting large numbers of maps has a slower render time, please wait...', ...
                'Value', 0, 'Cancelable', 'on');
        else
            progressBar = uiprogressdlg(fh.Parent.Parent, 'Message', 'Plotting large numbers of maps has a slower render time, please wait...', ...
                'Value', 0, 'Cancelable', 'on');
        end
    end

    if ~isfield(UserData, 'Axes')
        UserData.Axes = cell(nRows, nCols);
    end    
    
    % Update specified solutions
    for y = 1:numel(classesToUpdate)
        if UserData.Edit
            y_pos = classes(y)-UserData.ClustPar.MinClasses+1;
        else
            y_pos = y;
        end

        for x_pos = 1:classesToUpdate(y)
            % Make the axes if they do not exist
            if isempty(UserData.Axes{y_pos, x_pos})
                ax = axes('Parent', UserData.MapLayout);
                tilenum = y_pos*nCols - nCols + x_pos;
                ax.Layout.Tile = tilenum;
                UserData.Axes{y_pos, x_pos} = ax;
            end

            % Plot map and add title
            Background = UserData.AllMaps(classesToUpdate(y)).ColorMap(x_pos,:);
            dspCMap3(UserData.Axes{y_pos, x_pos}, double(UserData.AllMaps(classesToUpdate(y)).Maps(x_pos,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
            UserData.Axes{y_pos, x_pos}.Toolbar.Visible = 'off';
            title(UserData.Axes{y_pos, x_pos}, UserData.AllMaps(classesToUpdate(y)).Labels(x_pos), ...
                'FontSize', 9, 'Interpreter','none');

            % Add explained variance labels if in edit mode
            if UserData.Edit
                % if in edit mode, add explained variance labels
                if x_pos == 1
                    if isempty(UserData.Children)
                        ExpVar = sum(UserData.AllMaps(classesToUpdate(y)).ExpVar);
                        ExpVarStr = sprintf(' %2.2f%% ', ExpVar*100);
                        ylabel(UserData.Axes{y_pos, x_pos}, ExpVarStr, 'FontSize', 10, 'Rotation', 0, 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
                    else
                        if isfield(UserData.AllMaps(classesToUpdate(y)), 'SharedVar')
                            SharedVar = mean(UserData.AllMaps(classesToUpdate(y)).SharedVar);
                            SharedVarStr = sprintf(' %2.2f%% ', SharedVar*100);
                            ylabel(UserData.Axes{y_pos, x_pos}, SharedVarStr, 'FontSize', 10, 'Rotation', 0, 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
                        end
                    end                                                
                end
                  
                if isempty(UserData.Children)
                    if numel(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).ExpVar) > 1
                        IndExpVar = UserData.AllMaps(classesToUpdate(y)).ExpVar(x_pos);
                        IndExpVarStr = sprintf('%2.2f%%', IndExpVar*100);
                        xlabel(UserData.Axes{y_pos, x_pos}, IndExpVarStr, 'FontSize', 9);
                    end
                else
                    if isfield(UserData.AllMaps(classesToUpdate(y)), 'SharedVar')
                        SharedVar = UserData.AllMaps(classesToUpdate(y)).SharedVar(x_pos);
                        SharedVarStr = sprintf('%2.2f%%', SharedVar*100);
                        xlabel(UserData.Axes{y_pos, x_pos}, SharedVarStr, 'FontSize', 9);
                    end
                end
            end
            
            % Add context menu
            if ~strcmp(fh.Type, 'uitab')
                contextMenu = uicontextmenu(fh);
            else
                contextMenu = uicontextmenu(fh.Parent.Parent);
            end
            uimenu(contextMenu, 'Text', 'Plot map in new window', 'MenuSelectedFcn', {@plotIndMap, UserData.Axes{y_pos, x_pos}});
            UserData.Axes{y_pos, x_pos}.ContextMenu = contextMenu;
            for child=1:numel(UserData.Axes{y_pos, x_pos}.Children)
                UserData.Axes{y_pos, x_pos}.Children(child).ContextMenu = contextMenu;
            end            

            if showProgress
                mapsPlotted = mapsPlotted + 1;
                progressBar.Value = mapsPlotted/totalMaps;
                if progressBar.CancelRequested
                    delete(fh);
                    return;
                end
            end
        end
        if UserData.Visible
            drawnow limitrate            
        end
    end
    
    set(fh,'UserData',UserData);  
end

function plotIndMap(~, ~, ax)
    fig = figure;
    newAx = copyobj(ax, fig);
    newAx.Units = 'normalized';
    newAx.Position = [0 0 1 1];
end