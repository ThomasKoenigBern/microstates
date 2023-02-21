function PlotMSMaps(fh, classes)
    UserData = get(fh,'UserData');

    X = cell2mat({UserData.chanlocs.X});
    Y = cell2mat({UserData.chanlocs.Y});
    Z = cell2mat({UserData.chanlocs.Z});

    % DEPECRATED PLOTTING CODE
    if ~isnan(UserData.nClasses)
        n_x = ceil(sqrt(UserData.nClasses));
        n_y = ceil(UserData.nClasses / n_x);
    
        for m = 1:UserData.nClasses
            h = subplot(n_y,n_x,m,'Parent',UserData.MapPanel);
            h.Toolbar.Visible = 'off';
            Background = UserData.AllMaps(UserData.nClasses).ColorMap(m,:);
            dspCMap(double(UserData.AllMaps(UserData.nClasses).Maps(m,:)),[X; Y;Z],'NoScale','Resolution',10,'Background',Background,'ShowNose',15);        
            UserData.TitleHandles{m,1} = title(UserData.AllMaps(UserData.nClasses).Labels{m},'FontSize',10,'Interpreter','none');      
%             if UserData.Edit == true
%                 set(UserData.TitleHandles{m,1},'ButtonDownFcn',{@EditMSLabel,UserData.nClasses,m});
%             end
        end
    
        if UserData.nClasses == UserData.ClustPar.MinClasses
            set(UserData.MinusButton,'enable','off');
        else
            set(UserData.MinusButton,'enable','on');
        end

        if UserData.nClasses == UserData.ClustPar.MaxClasses
            set(UserData.PlusButton,'enable','off');
        else
            set(UserData.PlusButton,'enable','on');
        end
    % CURRENT PLOTTING CODE
    else
        nCols = UserData.ClustPar.MaxClasses;
        nRows = UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1;

        % Create the panels, axes, and tiled layout fields if they do not already exist
        if ~isfield(UserData, 'MapPanel')
            UserData.MapPanel = uipanel(UserData.FigLayout, 'Scrollable', 'on');
            UserData.MapPanel.Layout.Row = 1;
        end

        if ~isfield(UserData, 'TilePanel')
            UserData.TilePanel = uipanel(UserData.MapPanel, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none');
        end

        if ~isfield(UserData, 'MapLayout')
            UserData.MapLayout = tiledlayout(UserData.TilePanel, nRows, nCols, ...
                'TileSpacing', 'tight', 'Padding', 'tight');
        end

        showBar = false;
        if ~isfield(UserData, 'Axes')
            UserData.Axes = cell(nRows, nCols);
            showBar = true;
            progressBar = waitbar(0, 'Plotting maps, please wait...');
            nMaps = sum(classes);
            mapsPlotted = 0;
        end        

        % Update specified solutions
        for y = 1:numel(classes)
            y_pos = classes(y)-UserData.ClustPar.MinClasses+1;

            for x_pos = 1:UserData.ClustPar.MinClasses + y_pos - 1
                % Make the axes if they do not exist
                if isempty(UserData.Axes{y_pos, x_pos})
                    ax = axes('Parent', UserData.MapLayout);
                    ax.Layout.Tile = tilenum(UserData.MapLayout, y_pos, x_pos);
                    UserData.Axes{y_pos, x_pos} = ax;
                end

                % Plot map and add title
                Background = UserData.AllMaps(classes(y)).ColorMap(x_pos,:);
                dspCMap2(UserData.Axes{y_pos, x_pos}, double(UserData.AllMaps(classes(y)).Maps(x_pos,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
                UserData.Axes{y_pos, x_pos}.Toolbar.Visible = 'off';
                UserData.Axes{y_pos, x_pos}.PickableParts = 'none';                
                title(UserData.Axes{y_pos, x_pos}, UserData.AllMaps(classes(y)).Labels(x_pos), ...
                    'FontSize', 9, 'Interpreter','none');

                % Add explained variance labels if in edit mode
                if UserData.Edit
                    % if in edit mode, add explained variance labels
                    if x_pos == 1
                        if isempty(UserData.Children)
                            ExpVar = sum(UserData.AllMaps(classes(y)).ExpVar);
                        else
                            ExpVar = mean(UserData.AllMaps(classes(y)).SharedVar);
                        end                            
                        ExpVarStr = sprintf(' %2.2f%% ', ExpVar*100);
                        ylabel(UserData.Axes{y_pos, x_pos}, ExpVarStr, 'FontSize', 10, 'Rotation', 0, 'HorizontalAlignment', 'right', 'FontWeight', 'bold');
                    end
                      
                    if isempty(UserData.Children)
                        IndExpVar = UserData.AllMaps(classes(y)).ExpVar(x_pos);
                        IndExpVarStr = sprintf('%2.2f%%', IndExpVar*100);
                        xlabel(UserData.Axes{y_pos, x_pos}, IndExpVarStr, 'FontSize', 9);
                    else
                        SharedVar = UserData.AllMaps(classes(y)).SharedVar(x_pos);
                        SharedVarStr = sprintf('%2.2f%%', SharedVar*100);
                        xlabel(UserData.Axes{y_pos, x_pos}, SharedVarStr, 'FontSize', 9);
                    end
                end

                if showBar
                    mapsPlotted = mapsPlotted + 1;
                    waitbar(mapsPlotted/nMaps);
                end
            end
            if strcmp(fh.Visible, 'on')
                drawnow limitrate
            end
        end
        if showBar
            close(progressBar);
        end
    end

    set(fh,'UserData',UserData);  
end