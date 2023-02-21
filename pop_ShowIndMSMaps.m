%% UPDATE DOCUMENTATION TO REFLECT KEY, VALUE PARAMETERS
%
% pop_ShowIndMSMaps() - Display microstate maps
%
% Usage:
%   >> [AllEEG,TheEEG,com] = pop_ShowIndMSMaps(TheEEG,nclasses, DoEdit, AllEEG)
%
% Inputs:
%   "TheEEG"    - The EEG whose microstate maps are to be shown.
%   "nclasses"  - Number of microstate classes to be shown.
%   "DoEdit"    - True if you want edit the microstate map sequence,
%                 otherwise false. If true, the window goes modal, and the
%                 AllEEG and EEG structures are updated when clicking the
%                 close button. Otherwise, the window immediately returns
%                 and the AllEEG and EEG structures remain unchanged.
%                 Editing will not only change the order of the maps, but
%                 also attempt to clear the sorting information in
%                 microstate maps that were previously sorted on the edited
%                 templates, and issue warnings if this fails.
%
%   "AllEEG"    - AllEEG structure with all the EEGs (only necessary when editing)
%
% Output:
%
%   "AllEEG" 
%   -> AllEEG structure with all the updated EEG, if editing was done
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
%
function [AllEEG, TheEEG, com, FigureHandle] = pop_ShowIndMSMaps(AllEEG, varargin)
    % controls whether to show plot
    visible = true;

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global EEG;
    TheEEG = EEG;

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowIndMSMaps';
    p.FunctionName = funcName;
    p.StructExpand = false;

    addRequired(p, 'AllEEG',  @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));    
    addParameter(p, 'Edit', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'nclasses', NaN, @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));       % for old plotting version
    parse(p, AllEEG, varargin{:});

    AllEEG = p.Results.AllEEG;
    SelectedSets = p.Results.SelectedSets;
    Edit = p.Results.Edit;
    nclasses = p.Results.nclasses;

    %% SelectedSets validation
    if numel(SelectedSets) > 1 && Edit
        errordlg2('Editing microstate maps is only supported for one dataset at a time.', ...
            'Plot microstate maps error');
        return;
    end

    % Make sure there are valid sets for editing/plotting
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(~isEmpty, ~HasDyn), HasMS));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for plotting found.'], 'Plot microstate maps error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % Check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid) && ~Edit
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.'];
            errordlg2(errorMessage, 'Plot microstate maps error');
            return;
        end
    end

    % Otherwise, prompt user to provide sets    
    if isempty(SelectedSets) || (any(~isValid) && Edit)
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        if Edit
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                {{ 'Style', 'text'    , 'string', 'Choose set for editing'} ...
                { 'Style', 'listbox' , 'string', AvailableSetnames, 'tag', SelectedSets }}, ...
                'title', 'Edit and sort microstate maps');
        else
            [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', ...
                {{ 'Style', 'text'    , 'string', 'Choose sets for plotting'} ...
                { 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'text'    , 'string', 'If multiple are chosen, a window will be opened for each'} ...
                { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                'title', 'Plot microstate maps');
        end

        if isempty(res);    return; end

        SelectedSets = AvailableSets(outstruct.SelectedSets);
    end

    TheEEG = AllEEG(SelectedSets);

    for i=1:numel(TheEEG)
    
        ud.visible = visible;
    
        ud.AllMaps   = TheEEG(i).msinfo.MSMaps;
        ud.chanlocs  = TheEEG(i).chanlocs;
        ud.setname   = TheEEG(i).setname;
        ud.ClustPar  = TheEEG(i).msinfo.ClustPar;
        ud.wasSorted = false;
        ud.SelectedSet = SelectedSets;
        ud.com = '';
        if isfield(TheEEG(i).msinfo,'children')
            ud.Children = TheEEG(i).msinfo.children;
        else
            ud.Children = [];
        end
    
        if isempty(nclasses)
            nclasses = ud.ClustPar.MinClasses;
        end
    
        ud.nClasses = nclasses;

        if Edit == true;  eTxt = 'on';
        else
                          eTxt = 'off';
        end
    
        ud.Edit = Edit;
        
        for j = ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses
    
            if isfield(ud.AllMaps(j),'Labels')
                if ~isempty(ud.AllMaps(j).Labels)
                    continue
                end
            end
    
            % Fill in generic labels if dataset does not have them
            for k = 1:j
                ud.AllMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
            end
            ud.Labels(j,1:j) = ud.AllMaps(j).Labels(1:j);
        end
    
        AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
         
        if ~isnan(ud.nClasses)
            ud.MapPanel    = uipanel(fig_h,'Position',[0.05 0.25 0.9 0.75],'BorderType','Line');
            ud.ButtonPanel = uibuttongroup(fig_h,'Position',[0.05 0.05 0.44 0.24],'BorderType','Line');
            ud.MinusButton = uicontrol('Style', 'pushbutton', 'String', 'Less'      , 'Units','Normalized','Position'  , [0.05 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps,-1,fig_h});
            ud.PlusButton  = uicontrol('Style', 'pushbutton', 'String', 'More'      , 'Units','Normalized','Position'  , [0.20 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps, 1,fig_h});
            ud.ShowDyn     = uicontrol('Style', 'pushbutton', 'String', 'Dynamics'  , 'Units','Normalized','Position'  , [0.35 0.05 0.15 0.05], 'Callback', {@ShowDynamics, TheEEG, i});
            ud.Info        = uicontrol('Style', 'pushbutton', 'String', 'Info'      , 'Units','Normalized','Position'  , [0.50 0.05 0.15 0.05], 'Callback', {@MapInfo     , fig_h});
            ud.Sort        = uicontrol('Style', 'pushbutton', 'String', 'Sort'      , 'Units','Normalized','Position'  , [0.65 0.05 0.15 0.05], 'Callback', {@ManSort     , fig_h}, 'Enable',eTxt);
            ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'     , 'Units','Normalized','Position'  , [0.80 0.05 0.15 0.05], 'Callback', {@ShowIndMSMapsClose,fig_h});
        else
            if Edit
                fig_h = uifigure('WindowStyle', 'modal', 'Units', 'pixels', 'Position', [380 174 758 518], 'Visible', 'off', ...
                    'Name', ['Microstate maps of ' TheEEG(i).setname], 'AutoResizeChildren', 'off', 'SizeChangedFcn', @sizeChanged);

                if isfield(TheEEG(i).msinfo, 'children')
                    DynEnable = 'off';
                else
                    DynEnable = 'on';
                end
                warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');

                ud.FigLayout = uigridlayout(fig_h, [3 1]);
                ud.FigLayout.RowHeight = {25, '1x', 120};

                if ~isfield(TheEEG(i).msinfo, 'children')
                    uilabel(ud.FigLayout, 'Text', 'Left: total explained variance per solution. Subtitles: individual explained variance per map.');
                else
                    uilabel(ud.FigLayout, 'Text', 'Left: mean shared variance per solution across maps. Subtitles: mean shared variance between individual and mean maps.');
                end                    

                ud.MapPanel = uipanel(ud.FigLayout, 'Scrollable', 'on');

                SelLayout = uigridlayout(ud.FigLayout, [1 3]);
                SelLayout.Padding = [0 0 0 0];
                SelLayout.ColumnWidth = {90, '1x', 200};

                ud.ClassList = uilistbox(SelLayout, 'Items', AvailableClassesText, 'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, 'ValueChangedFcn', {@solutionChanged, fig_h});
                
                SortLayout = uigridlayout(SelLayout, [4 1]);
                SortLayout.RowSpacing = 8;
                SortLayout.Padding = [0 0 0 0];

                Actions = {'1) Reorder clusters in selected solution based on index','2) Reorder clusters in selected solution based on template','3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'};               
                ud.ActChoice = uidropdown(SortLayout, 'Items', Actions, 'ItemsData', 1:5, 'ValueChangedFcn', {@ActionChangedCallback, fig_h});

                ud.OrderLayout = uigridlayout(SortLayout, [1 2]);
                ud.OrderLayout.Padding = [0 0 0 0];
                ud.OrderLayout.ColumnSpacing = 0;
                ud.OrderLayout.ColumnWidth = {210, '1x'};

                ud.LabelsLayout = uigridlayout(SortLayout, [1 2]);
                ud.LabelsLayout.Padding = [0 0 0 0];
                ud.LabelsLayout.ColumnSpacing = 0;
                ud.LabelsLayout.ColumnWidth = {210, '1x'};

                uibutton(SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@Sort,fig_h, TheEEG});

                BtnLayout = uigridlayout(SelLayout, [4 1]);
                BtnLayout.Padding = [0 0 0 0];
                BtnLayout.RowSpacing = 2;
                ud.Info = uibutton(BtnLayout, 'Text', 'Info', 'ButtonPushedFcn', {@MapInfo, fig_h});
                ud.ShowDyn = uibutton(BtnLayout, 'Text', 'Dynamics', 'ButtonPushedFcn', {@ShowDynamics, TheEEG}, 'Enable', DynEnable);
                ud.Compare = uibutton(BtnLayout, 'Text', 'Compare maps', 'ButtonPushedFcn', {@CompareCallback, fig_h, TheEEG});
                ud.Done = uibutton(BtnLayout, 'Text', 'Close', 'ButtonPushedFcn', {@ShowIndMSMapsClose, fig_h});

            else
                fig_h = figure('Units', 'pixels', 'Position', [385 174 758 518], 'Visible', 'off', ...
                    'Name', ['Microstate maps of ' TheEEG(i).setname], 'AutoResizeChildren', 'off', 'SizeChangedFcn', @sizeChanged);
                ud.MapPanel = uipanel(fig_h, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');               
            end    
        end
        set(fig_h,'userdata',ud);    
        fig_h.CloseRequestFcn = {@ShowIndMSMapsClose, fig_h};
            
        PlotMSMaps(fig_h, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);

        if visible
            fig_h.Visible = 'on';
            drawnow limitrate
        end
            
    end

    if ~isnan(nclasses)
        com = sprintf('[ALLEEG EEG com] = pop_ShowIndMSMaps(%s, %s, ''nclasses'', %i)', inputname(1), mat2str(SelectedSets), nclasses);
    else
        com = sprintf('[ALLEEG EEG com] = pop_ShowIndMSMaps(%s, %s, ''Edit'', %i)', inputname(1), mat2str(SelectedSets), Edit);
    end
    
    if Edit
        ActionChangedCallback([],[],fig_h);
        uiwait(fig_h);
        if ~isvalid(fig_h)
            return
        end
        
        ud = get(fig_h,'Userdata');

        if ~isempty(ud.com)
            com = [com newline ud.com];
        end
        
        delete(fig_h);

        if ud.wasSorted == true
            ButtonName = questdlg2('Update dataset and try to clear depending sorting?', 'Microstate template edit', 'Yes', 'No', 'Yes');
            switch ButtonName
                case 'Yes'
                    dummy = ud.AllMaps(5)
                    TheEEG.msinfo.MSMaps = ud.AllMaps;
                                        
                    TheEEG.saved = 'no';
                    if isfield(TheEEG.msinfo,'children')
                        AllEEG = ClearDataSortedByParent(AllEEG,TheEEG.msinfo.children);
                    end
                case 'No'
                    disp('Changes abandoned');
            end
        end
    end
end

%% GUI CALLBACKS %%

function ShowIndMSMapsClose(obj,event,fh)
    ud = fh.UserData;
    
    if isfield(ud,"CompFigHandle")
        if isvalid(ud.CompFigHandle)
            close(ud.CompFigHandle);
        end
    end
    
    if ud.Edit == true
        uiresume(fh);
    else
        delete(fh);
    end

end

function sizeChanged(fig, ~)
    p = fig.UserData.TilePanel;

    if fig.UserData.Edit
        expVarWidth = 53;
        minGridHeight = 90;
    else
        expVarWidth = 0;
        minGridHeight = 60;
    end
    minGridWidth = 62;

    nCols = fig.UserData.ClustPar.MaxClasses;
    nRows = fig.UserData.ClustPar.MaxClasses - fig.UserData.ClustPar.MinClasses + 1;

    minPanelWidth = expVarWidth + minGridWidth*nCols;
    minPanelHeight = minGridHeight*nRows;

    p.Units = 'pixels';

    if p.Position(3) > minPanelWidth && p.Position(4) > minPanelHeight
        p.Units = 'normalized';
        p.Position = [0 0 1 1];
        return;
    end

    if p.Position(3) <= minPanelWidth
        p.Position(1:3) = [0 0 minPanelWidth];
    end

    if p.Position(4) <= minPanelHeight
        p.Position(1:2) = [0 0];
        p.Position(4) = minPanelHeight;
    end

    drawnow limitrate
    pause(0.02);
end              

function solutionChanged(~, ~, fig)
    ud = fig.UserData;
    nClasses = ud.ClassList.Value;

    if ud.ActChoice.Value == 1 || ud.ActChoice.Value == 4

        ud.OrderEdit.Value = sprintf('%i ', 1:nClasses);
    
        if strcmp(ud.AllMaps(nClasses).SortMode, 'none')
            letters = 'A':'Z';
            ud.LabelsEdit.Value = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
        else
            ud.LabelsEdit.Value = sprintf('%s ', string(ud.AllMaps(nClasses).Labels));
        end
    end
end

function ActionChangedCallback(obj,event,fh)
    UserData = fh.UserData;
    nClasses = UserData.ClassList.Value;
    switch(UserData.ActChoice.Value)
        case {1,4}
            if isfield(UserData, 'SelTemplate')
                delete(UserData.SelTemplateLabel);
                delete(UserData.SelTemplate);
            end

            if isfield(UserData, 'IgnorePolarity')
                delete(UserData.IgnorePolarity);
            end

            if ~isfield(UserData, 'OrderEdit') || ~isvalid(UserData.OrderEdit)
                UserData.OrderTxt = uilabel(UserData.OrderLayout, 'Text', 'Sort Order (negative to flip polarity)');
                UserData.OrderTxt.Layout.Column = 1;
                UserData.OrderEdit = uieditfield(UserData.OrderLayout, 'Value', sprintf('%i ', 1:nClasses));
                UserData.OrderEdit.Layout.Column = 2;
    
                UserData.LabelsTxt = uilabel(UserData.LabelsLayout, 'Text', 'New Labels');
                UserData.LabelsTxt.Layout.Column = 1;
                UserData.LabelsEdit = uieditfield(UserData.LabelsLayout);
                UserData.LabelsEdit.Layout.Column = 2;

                if strcmp(UserData.AllMaps(nClasses).SortMode, 'none')
                    letters = 'A':'Z';
                    UserData.LabelsEdit.Value = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
                else
                    UserData.LabelsEdit.Value = sprintf('%s ', string(UserData.AllMaps(nClasses).Labels));
                end
            end                        
            
        case {2,5}
            if isfield(UserData, 'OrderEdit')
                delete(UserData.OrderEdit);
                delete(UserData.OrderTxt);
    
                delete(UserData.LabelsEdit);
                delete(UserData.LabelsTxt);
            end

            if ~isfield(UserData, 'SelTemplate') || ~isvalid(UserData.SelTemplate)
                UserData.SelTemplateLabel = uilabel(UserData.OrderLayout, 'Text', 'Select template');
                UserData.SelTemplateLabel.Layout.Column = 1;
                [TemplateNames, DisplayNames, sortOrder] = getTemplateNames();
                UserData.SelTemplate = uidropdown(UserData.OrderLayout, 'Items', DisplayNames, 'ItemsData', TemplateNames);
                UserData.SelTemplate.Layout.Column = 2;
            end

            if ~isfield(UserData, 'IgnorePolarity') || ~isvalid(UserData.IgnorePolarity)
                UserData.IgnorePolarity = uicheckbox(UserData.LabelsLayout, 'Text', 'Ignore Polarity', 'Value', true);
                UserData.IgnorePolarity.Layout.Column = 1;
            end
        
        case 3
            if isfield(UserData, 'OrderEdit')
                delete(UserData.OrderEdit);
                delete(UserData.OrderTxt);
    
                delete(UserData.LabelsEdit);
                delete(UserData.LabelsTxt);
            end

            if isfield(UserData, 'SelTemplate')
                delete(UserData.SelTemplateLabel);
                delete(UserData.SelTemplate);
            end

            if ~isfield(UserData, 'IgnorePolarity') || ~isvalid(UserData.IgnorePolarity)
                UserData.IgnorePolarity = uicheckbox(UserData.LabelsLayout, 'Text', 'Ignore Polarity', 'Value', true);
                UserData.IgnorePolarity.Layout.Column = 1;
            end
    end

    fh.UserData = UserData;
end

%% SORTING %%
function Sort(obj,event,fh, TheEEG)
    UserData = fh.UserData;

    TheEEG.msinfo.MSMaps = fh.UserData.AllMaps;
    nClasses = UserData.ClassList.Value;  

    if UserData.ActChoice.Value == 1 || UserData.ActChoice.Value == 2
        SortAll = false;
    else
        SortAll = true;
    end

    switch(UserData.ActChoice.Value)
        case {1, 4}
            SortOrder = sscanf(UserData.OrderEdit.Value, '%i')';
            NewLabels = split(UserData.LabelsEdit.Value)';
            NewLabels = NewLabels(~cellfun(@isempty, NewLabels));

            EEGout = pop_SortMSTemplates(TheEEG, 1, 'TemplateSet', 'manual', 'SortOrder', SortOrder, 'NewLabels', NewLabels, 'ClassRange', nClasses, 'SortAll', SortAll);

            NewLabelsTxt = sprintf('%s, ', string(NewLabels));
            NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
            com = sprintf(['[EEG, CURRENTSET, COM] = pop_SortMSTemplates(ALLEEG, %i, ''TemplateSet'', ''manual'', ''SortOrder'', ' ...
                '%s, ''NewLabels'', %s, ''ClassRange'', %i, ''SortAll'', %i)'], UserData.SelectedSet, mat2str(SortOrder), NewLabelsTxt, nClasses, SortAll);

        case {2, 5}
            IgnorePolarity = UserData.IgnorePolarity.Value;
            TemplateName = UserData.SelTemplate.Value;

            EEGout = pop_SortMSTemplates(TheEEG, 1, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', TemplateName, 'ClassRange', nClasses, 'SortAll', SortAll);

            com = sprintf('[EEG, CURRENTSET, com] = pop_SortMSTemplates(ALLEEG, %i, ''IgnorePolarity'', %i, ''TemplateSet'', ''%s'', ''SortAll'', %i);', UserData.SelectedSet, IgnorePolarity, TemplateName, SortAll);
            
        case 3
            IgnorePolarity = UserData.IgnorePolarity.Value;

            EEGout = pop_SortMSTemplates(TheEEG, 1, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', 'manual', 'SortOrder', 1:nClasses, 'NewLabels', UserData.AllMaps(nClasses).Labels, 'ClassRange', nClasses, 'SortAll', true);

            LabelsTxt = sprintf('%s, ', string(UserData.AllMaps(nClasses).Labels));
            LabelsTxt = ['{' LabelsTxt(1:end-2) '}'];
            com = sprintf(['[EEG, CURRENTSET, COM] = pop_SortMSTemplates(ALLEEG, %i, ''IgnorePolarity'', %i, ''TemplateSet'', ''manual'', ''SortOrder'', ' ...
                '%s, ''NewLabels'', %s, ''ClassRange'', %i, ''SortAll'', %i)'], UserData.SelectedSet, IgnorePolarity, mat2str(1:nClasses), LabelsTxt, nClasses, true);

    end

    fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    else
        fh.UserData.com = [fh.UserData.com newline com];
    end
    fh.UserData.wasSorted = true;

    ActionChangedCallback([], [], fh);

    if SortAll
        PlotMSMaps(fh, UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses);
    else
        PlotMSMaps(fh, nClasses);
    end
end

% (deprecated)
function ManSort(obj, event,fh)

    UserData = get(fh,'UserData');
    UserData.Sort.Enable = 'off';
    UserData.Done.Enable = 'off';
    if ~isnan(UserData.nClasses)
        
        res = inputgui( 'geometry', {[3 1]}, 'geomvert', 1,  'uilist', { ...
                     { 'Style', 'text', 'string', 'Index of original position (negative to flip polarity)', 'fontweight', 'bold'  } ...
                     { 'style', 'edit', 'string', sprintf('%i ',1:UserData.nClasses) } },'title','Reorder microstates');
        
        if isempty(res)
            UserData.Sort.Enable = 'on';
            UserData.Done.Enable = 'on';
            return
        end

        [NewOrder, NewOrderSign] = GetOrderFromString(res{1},UserData.nClasses);
        
        if isempty(NewOrder)
            UserData.Sort.Enable = 'on';
            UserData.Done.Enable = 'on';
            return;
        end
            
        UserData.AllMaps(UserData.nClasses).Maps = UserData.AllMaps(UserData.nClasses).Maps(NewOrder,:).*repmat(NewOrderSign,1,size(UserData.AllMaps(UserData.nClasses).Maps,2));
        UserData.AllMaps(UserData.nClasses).SortMode = 'manual';
        UserData.AllMaps(UserData.nClasses).SortedBy = 'user';
        UserData.wasSorted = true;
        set(fh,'UserData',UserData);
        PlotMSMaps(obj,event,fh);
        
    else
    
        choice = '';
    
        for i = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses
            choice = [choice sprintf('%i Classes|',i)];
        end

        choice(end) = [];
        idx = 1;
        for i = 1:UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1
            OrderText{i} = sprintf('%i ',1:UserData.ClustPar.MinClasses -1 + i);
        end
        
        res = inputgui( 'geometry', {[1 1] [3 1] 1 1 1}, 'geomvert', [3 1 1 1 1],  'uilist', { ...
                    { 'Style', 'text', 'string', 'Select model', 'fontweight', 'bold'  } ...
                    { 'style', 'listbox', 'string', choice, 'Value', idx, 'Callback',{@SortMapsSolutionChanged,fh,}, 'Tag','nClassesListBox'}...
                    { 'Style', 'text', 'string', 'Index of original position (negative to flip polarity)', 'fontweight', 'bold'  } ...
                    { 'style', 'edit', 'string', OrderText{idx}, 'UserData',OrderText, 'Tag','ManSortOrderText'}...
                    { 'style','pushbutton','string','Reorder clusters in selected model based on index','Callback',{@pushbutton_SingleSortCallback,fh,false}},...
                    { 'style','pushbutton','string','Reorder clusters in selected model based on template','Callback',{@pushbutton_TemplateSortCallback,fh}},...
                    { 'style','pushbutton','string','Reorder clusters in other models based on this model','Callback',{@pushbutton_SingleSortCallback,fh,true}}},...
                    'title','Reorder microstates');
        
        UserData.wasSorted = true;
        UserData = fh.UserData;
        set(fh,'UserData',UserData);
    end

end

% (deprecated)
function SortMapsSolutionChanged(src,event,fh)

    OrderGUI = findobj(src.Parent,'Tag','ManSortOrderText');
    OrderText = OrderGUI.UserData;
    OrderGUI.String = OrderText{src.Value};
end

%% BUTTON CALLBACKS %% 
function MapInfo(~, ~, fh)
    UserData = get(fh,'UserData');    

    choice = '';
    
    for i = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses
        choice = [choice sprintf('%i Classes|',i)];
    end

    choice(end) = [];
   
    if ~isnan(UserData.nClasses)
        idx = UserData.nClasses - UserData.ClustPar.MinClasses + 1;
    else
        idx = 1;
    end

    [InfoTxt,InfoTit] = GetInfoText(UserData,idx);
    
    res = inputgui( 'geometry', {[1 1] 1 1}, 'geomvert', [3 1 3],  'uilist', { ...
                { 'Style', 'text', 'string', 'Select model', 'fontweight', 'bold'  } ...
                { 'style', 'listbox', 'string', choice, 'Value', idx, 'Callback',{@MapInfoSolutionChanged,fh} 'Tag','nClassesListBox'}...
                { 'Style', 'text', 'string', InfoTit, 'fontweight', 'bold','Tag','MapInfoTitle'} ...
                { 'Style', 'text', 'string', InfoTxt, 'fontweight', 'normal','Tag','MapInfoTxt'}}, ...
                'title','Microstate info');
end

function MapInfoSolutionChanged(obj,event,fh)
    UserData = fh.UserData;
    TxtToChange = findobj(obj.Parent,'Tag','MapInfoTxt');
    TitToChange = findobj(obj.Parent,'Tag','MapInfoTitle');
    
    [txt,tit] = GetInfoText(UserData,event.Source.Value);

    TxtToChange.String = txt;
    TitToChange.String = tit;

end

function [txt,tit] = GetInfoText(UserData,idx)
    nClasses = idx + UserData.ClustPar.MinClasses -1 ;

    tit = sprintf('Info for %i classes:',nClasses);

    AlgorithmTxt = {'k-means','AAHC'};
    PolarityText = {'considererd','ignored'};
    GFPText      = {'all data', 'GFP peaks only'};
    NormText     = {'not ', ''};
    
    if isinf(UserData.ClustPar.MaxMaps)
            MaxMapsText = 'all';
    else
            MaxMapsText = num2str(UserData.ClustPar.MaxMaps,'%i');
    end
    
    if ~isfield(UserData.ClustPar,'Normalize')
        UserData.ClustPar.Normalize = 1;
    end

    txt = { sprintf('Derived from: %s',UserData.setname) ...
            sprintf('Algorithm used: %s',AlgorithmTxt{UserData.ClustPar.UseAAHC+1})...
            sprintf('Polarity was %s',PolarityText{UserData.ClustPar.IgnorePolarity+1})...
            sprintf('EEG was %snormalized before clustering',NormText{UserData.ClustPar.Normalize+1})...
            sprintf('Extraction was based on %s',GFPText{UserData.ClustPar.GFPPeaks+1})...
            sprintf('Extraction was based on %s maps',MaxMapsText)...
            sprintf('Explained variance: %2.2f%%',sum(UserData.AllMaps(nClasses).ExpVar) * 100) ...
%            sprintf('Sorting was based  on %s ',UserData.AllMaps(UserData.nClasses).SortedBy)...
            };
    if isempty(UserData.AllMaps(nClasses).SortedBy)
        txt = [txt, 'Maps are unsorted'];
    else
        txt = [txt sprintf('Sort mode was %s ',UserData.AllMaps(nClasses).SortMode)];
        txt = [txt sprintf('Sorting was based  on %s ',UserData.AllMaps(nClasses).SortedBy)];
    end
            
    if ~isempty(UserData.Children)
        txt = [txt 'Children: ' UserData.Children];
    end

end

function ShowDynamics(~, ~, TheEEG)
    pop_ShowIndMSDyn(TheEEG, 1);
end

function CompareCallback(obj, event, fh, TheEEG)
    global guiOpts;

    TheEEG.msinfo.MSMaps = fh.UserData.AllMaps;
    SelectedEEG = TheEEG;

    MinClasses = SelectedEEG.msinfo.ClustPar.MinClasses;
    MaxClasses = SelectedEEG.msinfo.ClustPar.MaxClasses;

    % First check if any solutions remain unsorted
    yesPressed = false;
    SortModes = {SelectedEEG.msinfo.MSMaps(MinClasses:MaxClasses).SortMode};
    if any(strcmp(SortModes, 'none')) && guiOpts.showCompWarning1
        warningMessage = ['Some cluster solutions remain unsorted. Would you like to sort' ...
            ' all solutions according to the same template before proceeding?'];
        [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
        if boxChecked;  guiOpts.showCombWarning1 = false;   end
        if yesPressed
            [SelectedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, 1, 'ClassRange', MinClasses:MaxClasses);
            if isempty(com);    return; end
        elseif ~noPressed
            return;
        end
    end

    % Then check if there is inconsistency in sorting across solutions
    SortedBy = {SelectedEEG.msinfo.MSMaps(MinClasses:MaxClasses).SortedBy};
    emptyIdx = cellfun(@isempty, SortedBy);
    SortedBy(emptyIdx) = [];
    if ~yesPressed && numel(unique(SortedBy)) > 1 && guiOpts.showCompWarning2
        warningMessage = ['Sorting information differs across cluster solutions. Would you like ' ...
            'to resort all solutions according to the same template before proceeding?'];
        [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
        if boxChecked;  guiOpts.showCompWarning2 = false;   end
        if yesPressed
            [SelectedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, 1, 'ClassRange', MinClasses:MaxClasses);
            if isempty(com);    return; end
        elseif ~noPressed
            return;
        end
    end

    if yesPressed
        fh.UserData.AllMaps = SelectedEEG.msinfo.MSMaps;
        PlotMSMaps([], [], fh);
    end

    CompareMicrostateSolutions(SelectedEEG, 0, 'none', fh);
end

%% HELPERS %%

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    nClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    [nClasses, sortOrder] = sort(nClasses, 'ascend');
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(string(nClasses), " maps - ", TemplateNames, " - ", nSubjects);
end

function isEmpty = isEmptySet(in)
    isEmpty = all(cellfun(@(x) isempty(in.(x)), fieldnames(in)));
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set is a dynamics set
    if ~isfield(in.msinfo, 'DynamicsInfo')
        return;
    else
        hasDyn = true;
    end
end

function hasMS = hasMicrostates(in)
    hasMS = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if msinfo is empty
    if isempty(in.msinfo)
        return;
    else
        hasMS = true;
    end
end

% (deprecated)
function ChangeMSMaps(obj, event,i,fh)
    ud = get(fh,'userdata');

    for k = 1: ud.nClasses
        ud.Labels{ud.nClasses,k} = get(ud.TitleHandles{k,1},'String');
    end
    
    ud.nClasses = ud.nClasses + i;

    if ud.nClasses < ud.ClustPar.MinClasses
        ud.nClasses = ud.ClustPar.MinClasses;
    end


    if ud.nClasses  > ud.ClustPar.MaxClasses
        ud.nClasses = ud.ClustPar.MaxClasses;
    end

    set(fh,'userdata',ud);
    PlotMSMaps(obj,event,fh);
end

%% OLD PLOTTING %%
function PlotMSMapsFast(~, ~,fh)
% --------------------------
    UserData = get(fh,'UserData');
    set(0,'CurrentFigure',fh);  % use this instead of figure(fh) so the figure doesn't have to show up

    ClearMaps(fh);

    X = cell2mat({UserData.chanlocs.X});
    Y = cell2mat({UserData.chanlocs.Y});
    Z = cell2mat({UserData.chanlocs.Z});
    
%    Montage = UserData.chanlocs;
%    QMap = dspMapClass(Montage);
%    HelperData = QMap.GetQuickMontage();
    
%    disp('1');
%    toc()
    if ~isnan(UserData.nClasses)
        n_x = ceil(sqrt(UserData.nClasses));
        n_y = ceil(UserData.nClasses / n_x);
    
        for m = 1:UserData.nClasses
            h = subplot(n_y,n_x,m,'Parent',UserData.MapPanel);
            h.Toolbar.Visible = 'off';
            Background = UserData.AllMaps(UserData.nClasses).ColorMap(m,:);
%            dspMapClass(Montage,'HelperData',HelperData,'Map',double(UserData.AllMaps(UserData.nClasses).Maps(m,:)'));
%            toc()
            dspCMap(double(UserData.AllMaps(UserData.nClasses).Maps(m,:)),[X; Y;Z],'NoScale','Resolution',10,'Background',Background,'ShowNose',15);
        
            UserData.TitleHandles{m,1} = title(UserData.AllMaps(UserData.nClasses).Labels{m},'FontSize',10,'Interpreter','none');
        
            if UserData.Edit == true
                set(UserData.TitleHandles{m,1},'ButtonDownFcn',{@EditMSLabel,UserData.nClasses,m});
            end
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
    else
        n_x = UserData.ClustPar.MaxClasses;
        n_y = UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1;

        Spacing_x = 0.01;
        if UserData.Edit
            Spacing_y = 0.08;
            dx = (.94+Spacing_x)/n_x;
            dy = (.88+Spacing_y)/n_y;
            x_start = .07;
            y_start = .05;
        else
            Spacing_y = 0.05;
            dx = (.98+Spacing_x)/n_x;
            dy = (.93+Spacing_y)/n_y;
            x_start = .01;
            y_start = .01;
        end

        for y_pos = 1:n_y
            if UserData.Edit
                ExpVar = sum(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).ExpVar);
                ExpVarStr = sprintf('%2.2f%%', ExpVar*100);
                uicontrol('Style', 'text', 'String', ExpVarStr, 'Units', 'normalized', 'Position', ...
                    [.01, y_start + (n_y-y_pos)*dy + (dy-Spacing_y)/3, .07, .04], 'FontSize', 10, ...
                    'Parent', UserData.MapPanel);
            end
            for x_pos = 1:UserData.ClustPar.MinClasses + y_pos - 1

                h = subplot('Position',[x_start+(x_pos-1)*dx,y_start+(n_y-y_pos)*dy,dx-Spacing_x,dy-Spacing_y],'Parent',UserData.MapPanel);

%                h = subplot(sp_y,sp_x,(y_pos-1) * sp_x + x_pos,'Parent',UserData.MapPanel);
                Background = UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).ColorMap(x_pos,:);
%                dspMapClass(Montage,'HelperData',HelperData,'Map',double(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).Maps(x_pos,:))');
%                toc
%                dummy = UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).Maps(x_pos,:)
                dspCMap(double(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).Maps(x_pos,:)),[X; Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
                if UserData.visible  % drawnow when figure is hidden will sometimes create separate figures, so only do this when visible
                    drawnow
                end
                UserData.TitleHandles{y_pos,x_pos} = title(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).Labels(x_pos),'FontSize',10,'Interpreter','none');
                if UserData.Edit == true
                    set(UserData.TitleHandles{y_pos,x_pos},'ButtonDownFcn',{@EditMSLabel,y_pos + UserData.ClustPar.MinClasses-1,x_pos});
                end

                % the next if section produced crashes, as ExpVar sometimes
                % came with only one element. Added an ad hoc fix
                if UserData.Edit && numel(UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).ExpVar) > 1
                    IndExpVar = UserData.AllMaps(y_pos + UserData.ClustPar.MinClasses-1).ExpVar(x_pos);
                    IndExpVarStr = sprintf('%2.2f%%', IndExpVar*100);
                    UserData.ExpVarLabels{y_pos, x_pos} = uicontrol('Style', 'text', 'String', IndExpVarStr, 'Units', 'normalized', 'Position', ...
                        [x_start+(x_pos-1)*dx, y_start+(n_y-y_pos)*dy - .04, dx-Spacing_x, .04], 'FontSize', 8, ...
                        'Parent', UserData.MapPanel);
                end
                h.Toolbar.Visible = 'off';
                h.PickableParts = 'all';
                set(h,'Color',Background);
            end
        end
    end
end

