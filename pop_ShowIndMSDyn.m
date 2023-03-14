% pop_ShowIndMSDyn() Show microstate dynamics over time
%
% Usage:
%   >> [EEG, CURRENTSET, com] = pop_ShowIndMSDyn(ALLEEG, SelectedSets,
%   'key1', value1, 'key2', value2)
%
% To use each subject's own microstate maps for backfitting, specify
% "TemplateSet" as "own."
% Ex:
%   >> [EEG, CURRENTSET] = pop_ShowIndMSDyn(ALLEEG, 1:5, 'TemplateSet',
%       'own')
%
% To use a mean set or published set for backfitting, specify either the
% index of the mean set in ALLEEG, the name of the mean set, or the name of
% the published set.
% Ex:
%   >> [EEG, CURRENTSET] = pop_ShowIndMSDyn(ALLEEG, 1:5, 'TemplateSet',
%       'Koenig2002')
%
% Graphical interface:
%
%   "Choose sets for plotting dynamics"
%   -> Select sets for plotting dynamics. If multiple are selected, a
%   window will be generated for each.
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of template set"
%   -> Name of template set whose maps will be used for backfitting. Select 
%   "Own" to use each subject's own maps to backfit their own data, or 
%   select the name of a template set to use its maps for backfitting for 
%   all subjects.
%   -> Command line equivalent: "TemplateSet"
%
%   "Microstate fitting parameters"
%   ------------------------------
%
%   "Number of classes"
%   -> Number of classes to use for backfitting
%   -> Command line equivalent: "FitPar.nClasses"
%
%   "Fitting only on GFP peaks"
%   -> Controls whether to backfit maps only at global field power peaks
%   and interpolate microstae assignments in between peaks, or to backfit
%   maps at all timepoints.
%   -> Command line equivalent: "FitPar.PeakFit"
%
%   "Remove potentially truncated microstates"
%   -> Controls whether to remove microstate assignments around boundary
%   events in the EEG data
%   -> Command line equivalent: "FitPar.BControl"
%
%   "Label smoothing window"
%   -> Window size in ms to use for temporal smoothing of microstate
%   assignments. Use 0 to skip temporal smoothing. Ignored if fitting only
%   on GFP peaks.
%   -> Command line equivalent: "FitPar.b"
%
%   "Non-Smoothness penality"
%   -> Penalty for non-smoothness in the temporal smoothing algorithm.
%   Ignored if fitting only on GFP peaks.
%   -> Command line equivalent: "FitPar.lambda"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG for which dynamics will be plotted.
%   If not provided, a GUI will appear to select sets.
%
% Key, Value inputs (optional):
%
%   "FitPar"
%   -> Structure containing fields specifying parameters for backfitting.
%   If some required fields are not included, a GUI will appear with the
%   unincluded fields. Required fields:
%       "FitPar.nClasses"
%       -> Number of classes to use for backfitting
%
%       "FitPar.PeakFit"
%       -> 1 = backfit maps only at global field power peaks and
%       interpolate in between, 0 = backfit maps at all timepoints
%
%       "FitPar.BControl"
%       -> 1 = Remove microstate assignments around boundary events in the
%       EEG data, 0 = keep all microstate assignments
%
%       "FitPar.b"
%       -> Window size in ms to use for temporal smoothing of microstate
%       assignments. Use 0 to skip temporal smoothing. Ignored if fitting
%       only on GFP peaks.
%
%       "FitPar.lambda"
%       > Penalty for non-smoothness in the temporal smoothing algorithm.
%       Ignored if fitting only on GFP peaks.
%
%   "TemplateSet"
%   -> Integer, string, or character vector specifying the template set
%   whose maps should be used for backfitting. Can be either the index of 
%   a mean set in ALLEEG, the name of a mean set in ALLEEG, the name of a 
%   published template set in the microstates/Templates folder, or "own" to
%   use each subject's own maps for backfitting. If not provided, a GUI 
%   will appear to select a template set.
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array of sets chosen for plotting dynamics
%
%   "CURRENTSET" 
%   -> Indices of sets chosen for plotting dynamics
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

function [EEGout, CurrentSet, com] = pop_ShowIndMSDyn(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global guiOpts;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowIndMSDyn';
    p.FunctionName = funcName;
    p.StructExpand = false;         % do not expand FitPar struct input into key, value args

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'FitPar', []);
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    
    parse(p, AllEEG, varargin{:});

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(p.Results.TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    SelectedSets = p.Results.SelectedSets;
    FitPar = p.Results.FitPar;
    TemplateSet = p.Results.TemplateSet;

    %% SelectedSets validation
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(and(~HasChildren, ~HasDyn), ~isEmpty), HasMS));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for plotting dynamics found.'], 'Plot microstate dynamics error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets cannot be plotted: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.'];
            errordlg2(errorMessage, 'Plot microstate dynamics error');
            return;
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for plotting dynamics'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'text'    , 'string', 'If multiple are chosen, a window will be opened for each.'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1 1];
        guiGeomV = [guiGeomV  1 1 1 4];
    end

    %% TemplateSet validation
    % If the user has provided a template set number or name, check its
    % validity
    meanSets = find(and(and(and(HasChildren, ~HasDyn), ~isEmpty), HasMS));
    meanSetnames = {AllEEG(meanSets).setname};
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    TemplateIndex = 1;
    if ~isempty(TemplateSet)        
        % If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        if isnumeric(TemplateSet)
            if ~ismember(TemplateSet, meanSets)
                errorMessage = sprintf(['The specified template set number %i is not a valid mean set. ' ...
                    'Make sure you have not selected an individual set or a dynamics set.'], TemplateSet);
                errordlg2([errorMessage], 'Plot microstate dynamics error');
                return;
            else
                TemplateMode = 'mean';
                TemplateIndex = find(ismember(meanSets, TemplateSet));
                TemplateName = meanSetnames{TemplateIndex};
            end
        % Else if the template set is a string, make sure it matches one of
        % the mean setnames, published template setnames, or "own"
        else
            if matches(TemplateSet, 'own', IgnoreCase=true)
                TemplateMode = 'own';                          
            elseif matches(TemplateSet, publishedSetnames)
                TemplateMode = 'published';
                TemplateIndex = sortOrder(matches(publishedSetnames, TemplateSet));
                TemplateName = TemplateSet;
             elseif matches(TemplateSet, meanSetnames)
                % If there are multiple mean sets with the same name
                % provided, notify the suer
                if numel(find(matches(meanSetnames, TemplateSet))) > 1
                    errorMessage = sprintf(['There are multiple mean sets with the name "%s." ' ...
                        'Please specify the set number instead ot the set name.'], TemplateSet);
                    errordlg2([errorMessage], 'Plot microstate dynamics error');
                    return;
                else
                    TemplateMode = 'mean';
                    TemplateIndex = find(matches(meanSetnames, TemplateSet));
                    TemplateName = TemplateSet;
                    TemplateSet = meanSets(TemplateIndex);
                end
            else
                errorMessage = sprintf(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
                errordlg2([errorMessage], 'Plot microstate dynamics error');
                return;
            end
        end

    % Otherwise, add template set selection gui elements
    else
        combinedSetnames = ['Own' meanSetnames publishedDisplayNames];
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Name of template set', 'fontweight', 'bold'}} ...
            {{ 'Style', 'popupmenu', 'string', combinedSetnames, 'tag', 'TemplateIndex', 'Value', TemplateIndex }}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 1];
    end

    %% Prompt user to choose SelectedSets and TemplateSet if necessary
    if ~isempty(guiElements)

        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Plot microstates dynamics');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'TemplateIndex')
            if outstruct.TemplateIndex == 1
                TemplateMode = 'own';
                TemplateSet = 'own';
            elseif outstruct.TemplateIndex <= numel(meanSetnames)+1
                TemplateMode = 'mean';
                TemplateIndex = outstruct.TemplateIndex - 1;
                TemplateSet = meanSets(TemplateIndex);
                TemplateName = meanSetnames{TemplateIndex};
            else
                TemplateMode = 'published';
                TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames) - 1;
                TemplateSet = publishedSetnames{TemplateIndex};
                TemplateName = TemplateSet;
                TemplateIndex = sortOrder(TemplateIndex);
            end
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Plot microstate dynamics error');
        return;
    end

    if strcmp(TemplateMode, 'published')
        ChosenTemplate = MSTEMPLATE(TemplateIndex);
    elseif strcmp(TemplateMode, 'mean')
        ChosenTemplate = AllEEG(meanSets(TemplateIndex));
    end

    %% Verify compatibility between selected sets and template set
    % If the template set chosen is a mean set, make sure it is a parent
    % set of all the selected sets
    if strcmp(TemplateMode, 'mean')
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            containsChild = checkSetForChild(AllEEG, meanSets(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames) && guiOpts.showQuantWarning1
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);
            [yesPressed, boxChecked] = warningDialog(warningMessage, 'Plot microstate dynamics error');
            if boxChecked;  guiOpts.showDynWarning = false;     end
            if ~yesPressed; return;                             end
        end
    end

    %% Validate and get FitPar
    if strcmp(TemplateMode, 'own')
        AllMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets);
        AllMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets);
        MinClasses = max(AllMinClasses);
        MaxClasses = min(AllMaxClasses);
        if MaxClasses < MinClasses
            errorMessage = ['No overlap in microstate classes found between all selected sets.'];
            errordlg2(errorMessage, 'Quantify microstates error');
        end
    else
        MinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        MaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    end

    FitPar = SetFittingParameters(MinClasses:MaxClasses, FitPar, funcName);
    if isempty(FitPar);  return; end

    %% Plot dynamics
    SelectedEEG = AllEEG(SelectedSets);
    for s=1:numel(SelectedSets)

        if strcmp(TemplateMode, 'own')
            msinfo = SelectedEEG(s).msinfo;
        else
            msinfo = ChosenTemplate.msinfo;
        end
        Maps = msinfo.MSMaps(FitPar.nClasses).Maps;
        cmap = msinfo.MSMaps(FitPar.nClasses).ColorMap;
        
        SelectedEEG(s).msinfo.FitPar = FitPar;

        if strcmp(TemplateMode, 'own')
            [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar,msinfo.ClustPar.IgnorePolarity);
        else
            [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(SelectedEEG.chanlocs,ChosenTemplate.chanlocs);
            if SelectedEEG(s).nbchan > ChosenTemplate.nbchan
                [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity, LocalToGlobal);
            else
                Maps = Maps*GlobalToLocal';
                [MSClass,gfp,IndGEVs] = AssignMStates(SelectedEEG(s),Maps,FitPar, msinfo.ClustPar.IgnorePolarity);
            end
        end
        
        fit = sum(IndGEVs);
        
        if isempty(MSClass)
            continue;
        end

        fig_h = figure();
        ud.nClasses = size(Maps,1);
        ud.gfp = gfp;
        ud.Assignment = MSClass;
        ud.cmap = cmap;
        ud.Start  =  0;
        ud.Segment = 1;
        ud.Time   = SelectedEEG(s).times;
        ud.XRange = min([10000 ud.Time(end)]);
        ud.event = SelectedEEG(s).event;
    
        ud.MaxY   = 10;
        ud.nSegments = SelectedEEG(s).trials;
    
        set(fig_h,'userdata',ud);
        PlotMSDyn([],[],fig_h);
    
         if ~strcmp(TemplateMode, 'own')
            set(fig_h, 'Name', ['Microstate dynamics of ' SelectedEEG(s).setname ' (Template: ' ChosenTemplate.setname ')'],'NumberTitle','off');
         else
            set(fig_h, 'Name', ['Microstate dynamics of ' SelectedEEG(s).setname ' (own template)'],'NumberTitle','off');
         end
      
        uicontrol('Style', 'pushbutton', 'String', '|<<','Units','Normalized','Position', [0.11 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,-Inf});
        uicontrol('Style', 'pushbutton', 'String',  '<<','Units','Normalized','Position', [0.21 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,-10000 });
	    uicontrol('Style', 'pushbutton', 'String',   '<','Units','Normalized','Position', [0.31 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , -1000 });
        uicontrol('Style', 'pushbutton', 'String', '>'  ,'Units','Normalized','Position', [0.41 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,  1000});
        uicontrol('Style', 'pushbutton', 'String', '>>' ,'Units','Normalized','Position', [0.51 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , 10000 });
        uicontrol('Style', 'pushbutton', 'String', '>>|','Units','Normalized','Position', [0.61 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , Inf});
        uicontrol('Style', 'pushbutton', 'String', '<>' ,'Units','Normalized','Position', [0.71 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'ScaleX', -1000});
        uicontrol('Style', 'pushbutton', 'String', '><' ,'Units','Normalized','Position', [0.81 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'ScaleX',  1000});
        uicontrol('Style', 'slider'    ,'Min',ud.Time(1),'Max',ud.Time(end),'Value',ud.Time(1) ,'Units','Normalized','Position', [0.1 0.12 0.8 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Slider',  1});
    
        uicontrol('Style', 'pushbutton', 'String', '-'   ,'Units','Normalized','Position', [0.91 0.30 0.07 0.2], 'Callback', {@PlotMSDyn, fig_h, 'ScaleY', 1/0.75});
        uicontrol('Style', 'pushbutton', 'String', '+'   ,'Units','Normalized','Position', [0.91 0.50 0.07 0.2], 'Callback', {@PlotMSDyn, fig_h, 'ScaleY',   0.75});
    
        uicontrol('Style', 'text'      , 'String',sprintf('Explained variance: %3.1f%%',fit * 100),'Units','Normalized','Position', [0.1 0.19 0.8 0.03]);
        
        if strcmp(TemplateMode, 'own'   )
            uicontrol('Style', 'pushbutton', 'String', 'Map' ,'Units','Normalized','Position', [0.91 0.70 0.07 0.2], 'Callback', {@PlotMaps, SelectedEEG(s),ud.nClasses});
        else
            uicontrol('Style', 'pushbutton', 'String', 'Map' ,'Units','Normalized','Position', [0.91 0.70 0.07 0.2], 'Callback', {@PlotMaps, ChosenTemplate,ud.nClasses});
        end    

    end

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;

    if ischar(TemplateSet) || isstring(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_ShowIndMSDyn(%s, %s, ''FitPar'', %s, ''TemplateSet'', ''%s'');', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    elseif isnumeric(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_ShowIndMSDyn(%s, %s, ''FitPar'', %s, ''TemplateSet'', %i);', inputname(1), mat2str(SelectedSets), struct2String(FitPar), TemplateSet);
    end
end


function PlotMaps(~,~,TheEEG,nClasses)
    pop_ShowIndMSMaps(TheEEG, 1, 'Classes', nClasses);
end

function PlotMSDyn(obj, ~,fh, varargin)

    figure(fh);
    ax = subplot('Position',[0.1 0.3 0.8 0.65]);
    ud = get(fh,'UserData');
    
    p = inputParser;
    
    addParameter(p,'Move',0,@isnumeric);
    addParameter(p,'ScaleX',0,@isnumeric);
    addParameter(p,'ScaleY',1,@isnumeric);
    addParameter(p,'Slider',0,@isnumeric);
    
    parse(p,varargin{:});
    
    MoveX = p.Results.Move;
    if(ud.nSegments > 1) && p.Results.Move == inf
        ud.Segment = min(ud.nSegments,ud.Segment + 1);
         MoveX = 0;    
    end
        
    if(ud.nSegments > 1) && p.Results.Move == -inf
        ud.Segment = max(1,ud.Segment -1);
        MoveX = 0;    
    end
 
    ud.Start = ud.Start + MoveX;
    
    if p.Results.Slider == 1
        ud.Start = obj.Value;
    end
    
    if ud.Start < ud.Time(1)
        ud.Start = ud.Time(1);
    end
    
    if ud.Start + ud.XRange > ud.Time(end)
        ud.Start = ud.Time(end)-ud.XRange;
    end
    
    ud.XRange = ud.XRange+p.Results.ScaleX;
    
    if ud.XRange < 1
        ud.XRange = 1;
    end
    
    if ud.XRange > ud.Time(end) - ud.Time(1)
        ud.XRange = ud.Time(end) - ud.Time(1);
    end
    
    ud.MaxY = ud.MaxY * p.Results.ScaleY;
    
    slider = findobj(fh,'Style','slider');
    set(slider,'Value',ud.Start);
        
    Data2Show = find(ud.Time >= ud.Start & ud.Time <= (ud.Start + ud.XRange));
    Fit = zeros(ud.nClasses,numel(Data2Show));
    for e = 1:numel(ud.event)
        if ~isfield(ud.event(e),'epoch')
            epoch = 1;
        else
            epoch = ud.event(e).epoch;
        end
        if epoch ~= ud.Segment
            continue
        end
    end
    for c = 1:ud.nClasses
        idx = ud.Assignment(Data2Show,ud.Segment) == c;
        Fit(c,idx) = ud.gfp(1,Data2Show(1,idx),ud.Segment);
    end
    
    bar(ud.Time(Data2Show),Fit',1,'stacked','EdgeColor','none');
    colormap(ud.cmap);
    hold on
    axis([ud.Start-0.5 ud.Start+ ud.XRange+0.5 0, ud.MaxY]);
    xtick = num2cell(get(ax,'XTick')/ 1000);
    if (xtick{2} - xtick{1}) >= 1
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f',floor(x/3600),floor(rem(x/60,60)),rem(x,60)),xtick, 'UniformOutput',false);
    else
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f:%03.0f',floor(x/3600),floor(rem(x/60,60)),floor(rem(x,60)),rem(x*1000,1000)),xtick, 'UniformOutput',false);
    end
    set(ax,'XTickLabel',labels,'FontSize',7);
    
    title(sprintf('Segment %i of %i (%i classes)',ud.Segment,ud.nSegments,ud.nClasses))
    nPoints = numel(ud.Time);
    dt = ud.Time(2) - ud.Time(1);
    % Show the markers;
    for e = 1:numel(ud.event)
        if ~isfield(ud.event(e),'epoch')
            epoch = 1;
        else
            epoch = ud.event(e).epoch;
        end
        if epoch ~= ud.Segment
            continue
        end
        t = (ud.event(e).latency - (ud.Segment-1) * nPoints)  * dt;
        if t < ud.Start || t > ud.Start + ud.XRange
            continue;
        end
        plot([t,t],[0,ud.MaxY],'-k');
        if isnumeric(ud.event(e).type)
            txt = sprintf('%1.0i',ud.event(e).type);
        else
            txt = ud.event(e).type;
        end
        text(t,ud.MaxY,txt, 'Interpreter','none','VerticalAlignment','top','HorizontalAlignment','right','Rotation',90);
    end
    hold off
    set(fh,'UserData',ud);
end

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    minClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    maxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, 1:numel(MSTEMPLATE));
    [minClasses, sortOrder] = sort(minClasses, 'ascend');
    maxClasses = maxClasses(sortOrder);
    classRangeTxt = string(minClasses);
    diffMaxClasses = maxClasses ~= minClasses;
    classRangeTxt(diffMaxClasses) = sprintf('%s - %s', classRangeTxt(diffMaxClasses), string(maxClasses(diffMaxClasses)));
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(classRangeTxt, " maps - ", TemplateNames, " - ", nSubjects);
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


function Answer = DoesItHaveChildren(in)
    Answer = false;
    if ~isfield(in,'msinfo')
        return;
    end
    
    if ~isfield(in.msinfo,'children')
        return
    else
        Answer = true;
    end
end

function containsChild = checkSetForChild(AllEEG, SetsToSearch, childSetName)
    containsChild = false;
    if isempty(SetsToSearch)
        return;
    end
    
    % find which sets have children
    HasChildren = arrayfun(@(x) isfield(AllEEG(x).msinfo, 'children'), SetsToSearch);
    % if none of the sets to search have children, the child set could not
    % be found
    if ~any(HasChildren)
        return;
    end

    % search the children of all the mean sets for the child set name
    containsChild = any(arrayfun(@(x) matches(childSetName, AllEEG(x).msinfo.children), SetsToSearch(HasChildren)));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches({AllEEG.setname}, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end
