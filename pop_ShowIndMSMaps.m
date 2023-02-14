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

        SelectedSets = outstruct.SelectedSets;
    end

    TheEEG = AllEEG(SelectedSets);

    for i=1:numel(TheEEG)
    
        ud.visible = visible;
    
        ud.AllMaps   = TheEEG(i).msinfo.MSMaps;
        ud.chanlocs  = TheEEG(i).chanlocs;
        ud.setname   = TheEEG(i).setname;
        ud.ClustPar  = TheEEG(i).msinfo.ClustPar;
        ud.wasSorted = false;
        if isfield(TheEEG(i).msinfo,'Children')
            ud.Children = TheEEG(i).msinfo.Children;
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
        ud.LabelEdited = false(ud.ClustPar.MaxClasses,ud.ClustPar.MaxClasses);
        
        ud.TitleHandles = cell(ud.ClustPar.MaxClasses,1);
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
    
        AvailableClassesText = sprintf('%i Classes|', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
        AvailableClassesText(end) = [];
         
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
                fig_h = figure('WindowStyle', 'modal', 'Units', 'normalized', 'Position', [0.3 0.2 0.4 0.6]);
                if ~visible
                    fig_h.Visible = 'off';
                end
                if isfield(TheEEG(i).msinfo, 'children')
                    DynEnable = 'off';
                else
                    DynEnable = 'on';
                end
                warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');
                ud.MapPanel    = uipanel(fig_h,'Position',[0.02 0.3 0.96 0.67],'BorderType','Line');
                ud.ButtonPanel = uibuttongroup(fig_h,'Position',[0.71 0.02 0.28 0.27],'BorderType','Line','Title','Explore');

                ud.Info        = uicontrol('Style', 'pushbutton','String', 'Info'    , 'Units','Normalized','Position'  , [0.05  0.7 0.9 0.20], 'Parent', ud.ButtonPanel , 'Callback', {@MapInfo     , fig_h});                
                ud.ShowDyn     = uicontrol('Style', 'pushbutton','String', 'Dynamics', 'Units','Normalized','Position'  , [0.05  0.5 0.9 0.20], 'Parent', ud.ButtonPanel ,'Callback', {@ShowDynamics, TheEEG, i}, 'Enable', DynEnable);
                ud.Compare     = uicontrol('Style', 'pushbutton', 'String', 'Compare', 'Units','Normalized','Position'  , [0.05  0.3 0.9 0.20], 'Parent', ud.ButtonPanel , 'Callback', {@CompareMicrostateSolutions, fig_h}, 'Enable',eTxt);
                ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'  , 'Units','Normalized','Position'  , [0.05  0.1 0.9 0.20], 'Parent', ud.ButtonPanel , 'Callback', {@ShowIndMSMapsClose,fig_h});
        
                ud.SelPanel    = uibuttongroup(fig_h,'Position',[0.02 0.02 0.68 0.27],'BorderType','Line','Title','Sort');
        
                uicontrol('Style','Text','String','Select solution','Units','Normalized','Position'                              , [0.01  0.89 0.26 0.10], 'Parent', ud.SelPanel)
                ud.ClassList   = uicontrol('Style', 'listbox'  ,'String', AvailableClassesText, 'Units','Normalized','Position'  , [0.01  0.05 0.26 0.80], 'Parent', ud.SelPanel,'Callback',{@ActionChangedCallback,fig_h});
                        
                Actions = {'1) Reorder clusters in selected solution based on index','2) Reorder clusters in selected solution based on template','3) Use selected solution to reorder all other solutions','3) First 2), then 3)'};
                uicontrol('Style','Text','String','Choose the sorting procedure','Units','Normalized','Position'    , [0.3  0.87 0.68 0.12], 'Parent', ud.SelPanel)
                ud.ActChoice   = uicontrol('Style', 'popupmenu','String', Actions, 'Units','Normalized','Position'  , [0.3  0.70 0.68 0.15], 'Parent', ud.SelPanel,'Callback',{@ActionChangedCallback,fig_h});
        
                ud.IdxTxt      = uicontrol('Style','Text','String','Sort Index','Units','Normalized','Position'     , [0.3 0.51 0.2  0.12], 'Parent', ud.SelPanel);
                ud.IdxEdit     = uicontrol('Style', 'edit'  ,'String', "", 'Units','Normalized','Position'          , [0.5 0.51 0.48 0.15], 'Parent', ud.SelPanel,'Enable','inactive');
                ud.SelTemplate = uicontrol('Style', 'popupmenu'  ,'String', "", 'Units','Normalized','Position'     , [0.5 0.51 0.48 0.15], 'Parent', ud.SelPanel,'Enable','inactive', 'Visible', 'off');
                ud.IgnorePolarity  = uicontrol('Style', 'checkbox'   ,'String', "Ignore Polarity", 'Units','Normalized','Position', [0.3 0.34 0.48 0.12], 'Parent', ud.SelPanel,'Value',true, 'Visible', 'off');
        
                ud.GoButton    = uicontrol('Style', 'pushbutton', 'String', 'Sort now'  , 'Units','Normalized','Position'  , [0.3 0.1 0.68 0.20], 'Parent', ud.SelPanel , 'Callback', {@SortThingsOut,fig_h});

                n_x = ud.ClustPar.MaxClasses;
                n_y = ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses + 1;
                ud.ExpVarLabels = cell(n_y, n_x);
            else
                fig_h = figure;
                if ~visible
                    fig_h.Visible = 'off';
                end
                ud.MapPanel = uipanel(fig_h, 'Position', [0 0 1 1], 'BorderType', 'none');
            end    
        end
        set(fig_h,'userdata',ud);    
        fig_h.CloseRequestFcn = {@ShowIndMSMapsClose};
            
        PlotMSMaps([],[],fig_h);
        
        set(fig_h,'Name', ['Microstate maps of ' TheEEG(i).setname],'NumberTitle','off');
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
        StoreLabels(fig_h);
        
        delete(fig_h);

        if any(ud.LabelEdited(:))
            ud.wasSorted = true;
        end
        
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

function ShowIndMSMapsClose(obj,event,fh)
    if strcmp(obj.Type,'uicontrol')
        ud = fh.UserData;
    else
        ud = obj.UserData;
    end
    
    if isfield(ud,"CompFigHandle")
        if isvalid(ud.CompFigHandle)
            close(ud.CompFigHandle);
        end
    end

    
    if ud.Edit == true
        uiresume(gcf);
    else
        delete(gcf);
    end

end

function SortThingsOut(obj,event,fh)
    UserData = fh.UserData;
    StoreLabels(fh);
    [~, ~, sortOrder] = getTemplateNames();
    switch(UserData.ActChoice.Value)
        case 1
            SingleSort(fh,false);
            nClasses = UserData.ClassList.Value + UserData.ClustPar.MinClasses -1;
            UserData.IdxEdit.String = sprintf('%i ',1:nClasses);

        case 2
            TemplateSort(fh,sortOrder(UserData.SelTemplate.Value),UserData.IgnorePolarity.Value);

        case 3
            SingleSort(fh,true);

        case 4
            TemplateSort(fh,sortOrder(UserData.SelTemplate.Value),UserData.IgnorePolarity.Value);
            SingleSort(fh,true);
    end
    ClearMaps(fh);

    PlotMSMaps([],[],fh);

end


function ActionChangedCallback(obj,event,fh)
    UserData = fh.UserData;
    nClasses = UserData.ClassList.Value + UserData.ClustPar.MinClasses -1;
    switch(UserData.ActChoice.Value)
        case 1
            UserData.IdxEdit.Visible = 'on';
            UserData.IdxEdit.Enable = 'on';
            UserData.IdxEdit.String = sprintf('%i ',1:nClasses);
            UserData.IdxTxt.Visible = 'on';
            UserData.IdxTxt.String = 'Sort Index';
            UserData.SelTemplate.Visible = 'off';
            UserData.IgnorePolarity.Visible = 'off';
            UserData.IgnorePolarity.Enable = 'inactive';
            
        case {2,4}
            UserData.IdxEdit.Visible = 'off';
            UserData.IdxEdit.Enable = 'inactive';
            UserData.IdxEdit.String = '';
            UserData.IdxTxt.Visible = 'on';
            UserData.IdxTxt.String = 'Template';
            UserData.SelTemplate.Visible = 'on';
            UserData.SelTemplate.Enable = 'on';
            UserData.IgnorePolarity.Visible = 'on';
            UserData.IgnorePolarity.Enable = 'on';

            [~, DisplayNames] = getTemplateNames();
            UserData.SelTemplate.String = DisplayNames;
        
        case 3
            UserData.IdxEdit.Visible = 'off';
            UserData.IdxEdit.Enable = 'inactive';
            UserData.IdxEdit.String = '';
            UserData.IdxTxt.Visible = 'off';
            UserData.IdxTxt.String = 'Template';
            UserData.SelTemplate.Visible = 'off';
            UserData.SelTemplate.Enable = 'off';
            UserData.IgnorePolarity.Visible = 'on';
            UserData.IgnorePolarity.Enable  = 'on';

            [~, DisplayNames] = getTemplateNames();
            UserData.SelTemplate.String = DisplayNames;                
    end
end

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


function [NewOrder, NewOrderSign] = GetOrderFromString(txt,n)
    NewOrder = sscanf(txt,'%i');
    NewOrderSign = sign(NewOrder);
    NewOrder = abs(NewOrder);
    
   if numel(NewOrder) ~= n
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        NewOrder = [];
        return
   end

    if numel(unique(NewOrder)) ~= n
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        NewOrder = [];
        return
    end
    
    if any(unique(NewOrder) ~= unique(1:n)')
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        NewOrder = [];
    end
end

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

function TemplateSort(fh,MeanIndex,IgnorePolarity)
    global MSTEMPLATE;
    UserData = get(fh,'UserData');
    nClasses = UserData.ClassList.Value + UserData.ClustPar.MinClasses -1;

    if nargin < 2
        [~, DisplayNames, sortOrder] = getTemplateNames();
        MeanIndex = 1;
    
        res = inputgui('title','Sort microstate maps based on published template',...
            'geometry', {1 1 1}, 'geomvert', [1 4 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
            { 'Style', 'listbox', 'string', DisplayNames,'tag','MeanName','Value',MeanIndex} ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
     
        if isempty(res); return; end
        
        MeanIndex = sortOrder(res{1});
        IgnorePolarity = res{2};
    end

    HasTemplates = ~cellfun(@isempty,{MSTEMPLATE(MeanIndex).msinfo.MSMaps.Maps});
    TemplateClassesToUse = find(HasTemplates == true);

    % Delara 10/3/22 change: convert whichever maps have more
    % channels
    [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(UserData.chanlocs,MSTEMPLATE(MeanIndex).chanlocs);
    if numel(UserData.chanlocs) > numel(MSTEMPLATE(MeanIndex).chanlocs)
        MapsToSort(1,:,:) = UserData.AllMaps(nClasses).Maps * LocalToGlobal';
        TemplateMaps = MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).Maps;
    else
        MapsToSort(1,:,:) = UserData.AllMaps(nClasses).Maps;
        TemplateMaps = MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).Maps * GlobalToLocal';
    end
    
    [~,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MapsToSort, TemplateMaps, ~IgnorePolarity);
    %UserData.AllMaps(nClasses).Maps = squeeze(SortedMaps);
    UserData.AllMaps(nClasses).Maps = UserData.AllMaps(nClasses).Maps(SortOrder(SortOrder <= nClasses), :);
    UserData.AllMaps(nClasses).Maps = UserData.AllMaps(nClasses).Maps .* repmat(polarity',1,size(UserData.AllMaps(nClasses).Maps,2));
       
    [Labels,Colors] = UpdateMicrostateLabels(UserData.AllMaps(nClasses).Labels,MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).Labels,SortOrder,UserData.AllMaps(nClasses).ColorMap,MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).ColorMap);
    UserData.AllMaps(nClasses).Labels = Labels;
    UserData.AllMaps(nClasses).ColorMap = Colors;

    UserData.AllMaps(nClasses).ExpVar = UserData.AllMaps(nClasses).ExpVar(SortOrder <= nClasses);
    
    UserData.AllMaps(nClasses).SortedBy = MSTEMPLATE(MeanIndex).setname;
    UserData.AllMaps(nClasses).SortMode = "published template";
    UserData.AllMaps(nClasses).SpatialCorrelation = SpatialCorrelation;
    UserData.wasSorted = true;
    fh.UserData = UserData;

end


function SingleSort(fh, DoThemAll)

    UserData = fh.UserData;
    
    for i = 1:(UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1)
        nClasses = UserData.ClustPar.MinClasses + i -1;
        
        for k = 1: nClasses
             UserData.Labels{nClasses,k} = get(UserData.TitleHandles{i,k},'String');
        end
    end
    
    nClasses = UserData.ClassList.Value + UserData.ClustPar.MinClasses -1;
    
    if DoThemAll == false
        [NewOrder, NewOrderSign] = GetOrderFromString(UserData.IdxEdit.String,nClasses);

        if isempty(NewOrder)
            return;
        end
    
        UserData.AllMaps(nClasses).Maps = UserData.AllMaps(nClasses).Maps(NewOrder,:).*repmat(NewOrderSign,1,size(UserData.AllMaps(nClasses).Maps,2));
        UserData.AllMaps(nClasses).Labels = UserData.AllMaps(nClasses).Labels(NewOrder);
        UserData.AllMaps(nClasses).ExpVar = UserData.AllMaps(nClasses).ExpVar(NewOrder);
        UserData.AllMaps(nClasses).SortMode = 'manual';
        UserData.AllMaps(nClasses).SortedBy = 'user';

    else
        for i = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses
            
            if i == nClasses
                continue
            end
            [SortedMaps,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(UserData.AllMaps(i).Maps, UserData.AllMaps(nClasses).Maps,~UserData.IgnorePolarity.Value);
            UserData.AllMaps(i).Maps = squeeze(SortedMaps) .* repmat(polarity',1,size(squeeze(SortedMaps),2));
%            UserData.AllMaps(i).Maps = UserData.AllMaps(i).Maps(SortOrder(1:i,:), :);
%            UserData.AllMaps(i).Maps = UserData.AllMaps(i).Maps .* repmat(polarity',1,size(UserData.AllMaps(i).Maps,2));

            [Labels,Colors] = UpdateMicrostateLabels(UserData.AllMaps(i).Labels,UserData.AllMaps(nClasses).Labels,SortOrder,UserData.AllMaps(i).ColorMap,UserData.AllMaps(nClasses).ColorMap);
            UserData.AllMaps(i).Labels = Labels(1:i);
            UserData.AllMaps(i).ColorMap = Colors(1:i,:);
            UserData.AllMaps(i).ExpVar = UserData.AllMaps(nClasses).ExpVar(SortOrder(SortOrder <= i));

            if i > nClasses+2
                [SortedMaps,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(UserData.AllMaps(i).Maps((nClasses+1):end,:), UserData.AllMaps(i-1).Maps(nClasses+1:end,:),~UserData.IgnorePolarity.Value);
                UserData.AllMaps(i).Maps((nClasses+1):end,:) = squeeze(SortedMaps) .* repmat(polarity',1,size(squeeze(SortedMaps),2));
                [Labels,Colors] = UpdateMicrostateLabels(UserData.AllMaps(i).Labels(nClasses+1:end),UserData.AllMaps(i-1).Labels(nClasses+1:end),SortOrder,UserData.AllMaps(i).ColorMap(nClasses+1:end,:),UserData.AllMaps(i-1).ColorMap(nClasses+1:end,:));
                UserData.AllMaps(i).Maps((nClasses+1):end,:) = squeeze(SortedMaps) .* repmat(polarity',1,size(UserData.AllMaps(i).Maps,2));
                UserData.AllMaps(i).Labels((nClasses+1):end) = Labels;
                UserData.AllMaps(i).ColorMap((nClasses+1):end,:) = Colors;
                UserData.AllMaps(i).ExpVar = UserData.AllMaps(nClasses).ExpVar(SortOrder(SortOrder <= i));
            end
            
            UserData.AllMaps(i).SortMode = 'Template';
            UserData.AllMaps(i).SpatialCorrelation = SpatialCorrelation;
            UserData.AllMaps(i).SortedBy = sprintf("%s->This set (%i Classes)",UserData.AllMaps(nClasses).SortedBy,nClasses);

        end
    end
    UserData.wasSorted = true;

    set(fh,'UserData',UserData);    
    
end


function SortMapsSolutionChanged(src,event,fh)

    OrderGUI = findobj(src.Parent,'Tag','ManSortOrderText');
    OrderText = OrderGUI.UserData;
    OrderGUI.String = OrderText{src.Value};
end

function ShowDynamics(~, ~, TheEEG, SetIndex)
    pop_ShowIndMSDyn(TheEEG, SetIndex);
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
            sprintf('Explained variance: %2.2f%%',UserData.AllMaps(nClasses).ExpVar * 100) ...
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


function MapInfo(~, ~, fh)
% ------------------------

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


function ChangeMSMaps(obj, event,i,fh)
% ------------------------------------
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

function EditMSLabel(obj,~,i,j)
    set(obj,'Editing','on');
    fh = get(get(get(obj,'Parent'),'Parent'), 'Parent');
    ud = get(fh,'UserData');
    ud.LabelEdited(i,j) = true;
    set(fh,'UserData',ud);
end

function ClearMaps(fh)

    UserData = get(fh,'UserData');
    set(0,'CurrentFigure',fh);


    if ~isnan(UserData.nClasses)
        sp_x = ceil(sqrt(UserData.nClasses));
        sp_y = ceil(UserData.nClasses / sp_x);
    else
        sp_x = UserData.ClustPar.MaxClasses;
        sp_y = UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1;
    end
    for m = 1:sp_x*sp_y
        h = subplot(sp_y,sp_x,m);
        cla(h);
        set(h, 'Visible','off');
    end
    if UserData.Edit
        for y_pos=1:sp_y
            for x_pos=1:UserData.ClustPar.MinClasses + y_pos - 1
                delete(UserData.ExpVarLabels{y_pos,x_pos});
            end
        end
    end
end

function StoreLabels(fh)
    sp_y = fh.UserData.ClustPar.MaxClasses - fh.UserData.ClustPar.MinClasses + 1;

    for y_pos = 1:sp_y
        for x_pos = 1:fh.UserData.ClustPar.MinClasses + y_pos - 1
            fh.UserData.AllMaps(y_pos + fh.UserData.ClustPar.MinClasses-1).Labels(x_pos) = fh.UserData.TitleHandles{y_pos,x_pos}.String;
        end
    end

end


function PlotMSMaps(~, ~,fh)
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
        
        
    set(fh,'UserData',UserData);  

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
