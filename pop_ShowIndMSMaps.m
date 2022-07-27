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
function [AllEEG,TheEEG,com, FigureHandle] = pop_ShowIndMSMaps(TheEEG,nclasses, DoEdit, AllEEG)
    
    com = '';
    

    if numel(TheEEG) > 1
        errordlg2('pop_findMSTemplates() currently supports only a single EEG as input');
        return;
    end
    
    if nargin < 3
        DoEdit = false;
    end
    
    if DoEdit == true && nargin < 4
        errordlg2('Editing requires the AllEEG argument','Edit microstate maps');
        return;
    end
        
    if nargin < 4
        AllEEG = [];
    end
    
    if ~isfield(TheEEG,'msinfo')
        errordlg2('The data does not contain microstate maps','Show microstate maps');
        return;
    end
  
    ud.AllMaps   = TheEEG.msinfo.MSMaps;
    ud.chanlocs  = TheEEG.chanlocs;
    ud.msinfo    = TheEEG.msinfo;
    ud.setname   = TheEEG.setname;
    ud.wasSorted = false;
    if isfield(TheEEG.msinfo,'Children')
        ud.Children = TheEEG.msinfo.Children;
    else
        ud.Children = [];
    end
    
    if nargin < 2
        nclasses = ud.msinfo.ClustPar.MinClasses;
    end

    if isempty(nclasses)
        nclasses = ud.msinfo.ClustPar.MinClasses;
    end

    ud.nClasses = nclasses;

    fig_h = figure();
  
    if DoEdit == true;  eTxt = 'on';
    else
                        eTxt = 'off';
    end

    ud.DoEdit = DoEdit;
    ud.LabelEdited = false(ud.msinfo.ClustPar.MaxClasses,ud.msinfo.ClustPar.MaxClasses);
    
    ud.Labels = cell(ud.msinfo.ClustPar.MaxClasses,ud.msinfo.ClustPar.MaxClasses);
    ud.TitleHandles = cell(ud.msinfo.ClustPar.MaxClasses,1);
    for i = ud.msinfo.ClustPar.MinClasses:ud.msinfo.ClustPar.MaxClasses
        LabelsThere = false;
        if isfield(ud.AllMaps(i),'Labels')
            if ~isempty(ud.AllMaps(i).Labels)
                LabelsThere = true;
            end
        end
        if LabelsThere
            ud.Labels(i,1:i) = ud.AllMaps(i).Labels(1:i);
        else
            for j = 1:i
                ud.Labels{i,j} = sprintf('MS_%i.%i',i,j);
            end
        end
    end

    if DoEdit == true
        DoneCallback = 'uiresume(gcf)';
    else
        DoneCallback = 'close(gcf)';
    end
        
    if ~isnan(ud.nClasses)
        ud.MinusButton = uicontrol('Style', 'pushbutton', 'String', 'Less'      , 'Units','Normalized','Position'  , [0.05 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps,-1,fig_h});
        ud.PlusButton  = uicontrol('Style', 'pushbutton', 'String', 'More'      , 'Units','Normalized','Position'  , [0.20 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps, 1,fig_h});
        ud.ShowDyn     = uicontrol('Style', 'pushbutton', 'String', 'Dynamics'  , 'Units','Normalized','Position'  , [0.35 0.05 0.15 0.05], 'Callback', {@ShowDynamics, fig_h, TheEEG});
        ud.Info        = uicontrol('Style', 'pushbutton', 'String', 'Info'      , 'Units','Normalized','Position'  , [0.50 0.05 0.15 0.05], 'Callback', {@MapInfo     , fig_h});
        ud.Sort        = uicontrol('Style', 'pushbutton', 'String', 'Sort'      , 'Units','Normalized','Position'  , [0.65 0.05 0.15 0.05], 'Callback', {@ManSort     , fig_h}, 'Enable',eTxt);
        ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'     , 'Units','Normalized','Position'  , [0.80 0.05 0.15 0.05], 'Callback', DoneCallback);
    else
        ud.ShowDyn     = uicontrol('Style', 'pushbutton', 'String', 'Dynamics'  , 'Units','Normalized','Position'  , [0.1 0.05 0.2 0.05], 'Callback', {@ShowDynamics, fig_h, TheEEG});
        ud.Info        = uicontrol('Style', 'pushbutton', 'String', 'Info'      , 'Units','Normalized','Position'  , [0.3 0.05 0.2 0.05], 'Callback', {@MapInfo     , fig_h});
        ud.Sort        = uicontrol('Style', 'pushbutton', 'String', 'Sort'      , 'Units','Normalized','Position'  , [0.5 0.05 0.2 0.05], 'Callback', {@ManSort     , fig_h}, 'Enable',eTxt);
        ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'     , 'Units','Normalized','Position', [0.7 0.05 0.2 0.05], 'Callback', DoneCallback);
    end
    set(fig_h,'userdata',ud);

    FigureHandle = fig_h;
    PlotMSMaps([],[],fig_h);
    
    set(fig_h,'Name', ['Microstate maps of ' TheEEG.setname],'NumberTitle','off');
    if nargin < 4
        com = sprintf('[empty,EEG,com] = pop_ShowIndMSMaps(%s, %i, %i);', inputname(1), nclasses,DoEdit);
    else
        com = sprintf('[AllEEG,EEG,com] = pop_ShowIndMSMaps(%s, %i, %i, %s);', inputname(1), nclasses,DoEdit, inputname(4));
    end
    
    if DoEdit == true
        uiwait(fig_h);
        if ~isvalid(fig_h)
            return
        end
        ud = get(fig_h,'Userdata');
     
        for i = 1:(ud.msinfo.ClustPar.MaxClasses - ud.msinfo.ClustPar.MinClasses + 1)
            nClasses = ud.msinfo.ClustPar.MinClasses + i -1;
        
            for k = 1: nClasses
                 ud.Labels{nClasses,k} = get(ud.TitleHandles{i,k},'String');
            end
        end
        close(fig_h);
        if any(ud.LabelEdited(:))
            ud.wasSorted = true;
        end
        
        if ud.wasSorted == true
            ButtonName = questdlg2('Update dataset and try to clear depending sorting?', 'Microstate template edit', 'Yes', 'No', 'Yes');
            switch ButtonName
                case 'Yes'
                    TheEEG.msinfo.MSMaps = ud.AllMaps;
                                        
                    for i = ud.msinfo.ClustPar.MinClasses:ud.msinfo.ClustPar.MaxClasses
                        TheEEG.msinfo.MSMaps(i).Labels = ud.Labels(i,1:i);
                    end
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
    

function ManSort(obj, event,fh)
% -----------------------------

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
        UserData.AllMaps(UserData.nClasses).SortedMode = 'manual';
        UserData.AllMaps(UserData.nClasses).SortedBy = 'user';
        UserData.wasSorted = true;
        set(fh,'UserData',UserData);
        PlotMSMaps(obj,event,fh);
        
    else
    
        choice = '';
    
        for i = UserData.msinfo.ClustPar.MinClasses:UserData.msinfo.ClustPar.MaxClasses
            choice = [choice sprintf('%i Classes|',i)];
        end

        choice(end) = [];
        idx = 1;
        for i = 1:UserData.msinfo.ClustPar.MaxClasses - UserData.msinfo.ClustPar.MinClasses + 1
            OrderText{i} = sprintf('%i ',1:UserData.msinfo.ClustPar.MinClasses -1 + i);
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

    end   
    UserData.Sort.Enable = 'on';
    UserData.Done.Enable = 'on';

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


function pushbutton_TemplateSortCallback(src,~,fh)
    global MSTEMPLATE;
    nTemplates = numel(MSTEMPLATE);
    UserData = fh.UserData;
    
    ListBoxObj = findobj(src.Parent,'Tag','nClassesListBox');
    nClasses = ListBoxObj.Value + UserData.msinfo.ClustPar.MinClasses -1;

    UsefulTemplates = false(nTemplates,1);
    
    for i = 1:nTemplates
        
        if numel(MSTEMPLATE(i).msinfo.MSMaps) < nClasses
            continue;
        end
        if ~isempty(MSTEMPLATE(i).msinfo.MSMaps(nClasses).Maps)
            UsefulTemplates(i) = true;
        end
    end
    UsefulTemplates = find(UsefulTemplates == true);
    
    TemplateNames = {MSTEMPLATE.setname};
    
    for i = 1:numel(UsefulTemplates)
        TemplateNames{UsefulTemplates(i)} = [TemplateNames{UsefulTemplates(i)} ' *'];
    end
    
    MeanIndex = 1;
    
    res = inputgui('title','Sort microstate maps based on published template',...
        'geometry', {1 1 1}, 'geomvert', [1 4 1], 'uilist', { ...
        { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
        { 'Style', 'listbox', 'string', TemplateNames,'tag','MeanName','Value',MeanIndex} ...
        { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', UserData.msinfo.ClustPar.IgnorePolarity }  ...
        });
     
    if isempty(res); return; end
    
    MeanIndex = res{1};
    IgnorePolarity = res{2};

    LocalToGlobal = MakeResampleMatrices(MSTEMPLATE(MeanIndex).chanlocs,UserData.chanlocs);

    MapsToSort(1,:,:) = UserData.AllMaps(nClasses).Maps;
            
    HasTemplates = ~cellfun(@isempty,{MSTEMPLATE(MeanIndex).msinfo.MSMaps.Maps});
    TemplateClassesToUse = find(HasTemplates == true);

        
    [SortedMaps,~, Communality] = ArrangeMapsBasedOnMean(MapsToSort, MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).Maps * LocalToGlobal',IgnorePolarity);

        
    UserData.AllMaps(nClasses).Maps = squeeze(SortedMaps);
    %            Communality
    nAssignments = min(nClasses,TemplateClassesToUse);
        
    UserData.Labels(nClasses,1:nAssignments) = MSTEMPLATE(MeanIndex).msinfo.MSMaps(TemplateClassesToUse).Labels(1:nAssignments);
    
    fh.UserData = UserData;
    ClearMaps(fh);
    PlotMSMaps([],[],fh);

end


function pushbutton_SingleSortCallback(src,~,fh, DoThemAll)

    UserData = fh.UserData;
    
    for i = 1:(UserData.msinfo.ClustPar.MaxClasses - UserData.msinfo.ClustPar.MinClasses + 1)
        nClasses = UserData.msinfo.ClustPar.MinClasses + i -1;
        
        for k = 1: nClasses
             UserData.Labels{nClasses,k} = get(UserData.TitleHandles{i,k},'String');
        end
    end

    
    ListBoxObj = findobj(src.Parent,'Tag','nClassesListBox');
    nClasses = ListBoxObj.Value + UserData.msinfo.ClustPar.MinClasses -1;
    
    if DoThemAll == false
        OrderGUI = findobj(src.Parent,'Tag','ManSortOrderText');    
        [NewOrder, NewOrderSign] = GetOrderFromString(OrderGUI.String,nClasses);

        if isempty(NewOrder)
            return;
        end
    
        UserData.AllMaps(nClasses).Maps = UserData.AllMaps(nClasses).Maps(NewOrder,:).*repmat(NewOrderSign,1,size(UserData.AllMaps(nClasses).Maps,2));
        UserData.AllMaps(nClasses).SortedMode = 'manual';
        UserData.AllMaps(nClasses).SortedBy = 'user';
        UserData.wasSorted = true;

        ClearMaps(fh);
    else
    
% Go to lower numbers        
        for i = nClasses - 1:-1:UserData.msinfo.ClustPar.MinClasses
            MapsToSort = [];
            MapsToSort(1,:,:) = UserData.AllMaps(i).Maps;
            [SortedMaps,SortOrder, Communality] = ArrangeMapsBasedOnMean(MapsToSort, UserData.AllMaps(i+1).Maps,~UserData.msinfo.ClustPar.IgnorePolarity);
            idx = SortOrder <= i;
            UserData.AllMaps(i).Maps = squeeze(SortedMaps);
%            Communality
            UserData.Labels(i,1:i) = UserData.Labels(i+1,idx);
        end

% Now go up        
        for i = nClasses + 1:1:UserData.msinfo.ClustPar.MaxClasses
            MapsToSort = [];
            MapsToSort(1,:,:) = UserData.AllMaps(i).Maps;
            [SortedMaps,~, Communality] = ArrangeMapsBasedOnMean(MapsToSort, UserData.AllMaps(i-1).Maps,~UserData.msinfo.ClustPar.IgnorePolarity);

%            Communality
            UserData.AllMaps(i).Maps = squeeze(SortedMaps);
            UserData.Labels(i,1:(i-1)) = UserData.Labels(i-1,1:(i-1));
        end
    end

    set(fh,'UserData',UserData);    
    PlotMSMaps([],[],fh);

    
end


function SortMapsSolutionChanged(src,event,fh)

    OrderGUI = findobj(src.Parent,'Tag','ManSortOrderText');
    OrderText = OrderGUI.UserData;
    OrderGUI.String = OrderText{src.Value};
end

function ShowDynamics(~, ~,fh, TheEEG)
% ---------------------------------------
    UserData = get(fh,'UserData');
    TheEEG.msinfo.FitPar.nClasses = UserData.nClasses;
    pop_ShowIndMSDyn(0,TheEEG,0);
end


function [txt,tit] = GetInfoText(UserData,idx)
% --------------------------------------------
    nClasses = idx + UserData.msinfo.ClustPar.MinClasses -1 ;

    tit = sprintf('Info for %i classes:',nClasses);

    AlgorithmTxt = {'k-means','AAHC'};
    PolarityText = {'considererd','ignored'};
    GFPText      = {'all data', 'GFP peaks only'};
    NormText     = {'not ', ''};
    
    if isinf(UserData.msinfo.ClustPar.MaxMaps)
            MaxMapsText = 'all';
    else
            MaxMapsText = num2str(UserData.msinfo.ClustPar.MaxMaps,'%i');
    end
    
    if ~isfield(UserData.msinfo.ClustPar,'Normalize')
        UserData.msinfo.ClustPar.Normalize = 1;
    end

    txt = { sprintf('Derived from: %s',UserData.setname) ...
            sprintf('Alorithm used: %s',AlgorithmTxt{UserData.msinfo.ClustPar.UseAAHC+1})...
            sprintf('Polarity was %s',PolarityText{UserData.msinfo.ClustPar.IgnorePolarity+1})...
            sprintf('EEG was %snormalized before clustering',NormText{UserData.msinfo.ClustPar.Normalize+1})...
            sprintf('Extraction was based on %s',GFPText{UserData.msinfo.ClustPar.GFPPeaks+1})...
            sprintf('Extraction was based on %s maps',MaxMapsText)...
            sprintf('Explained variance: %4.2f%%',UserData.AllMaps(nClasses).ExpVar * 100) ...
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
    
    for i = UserData.msinfo.ClustPar.MinClasses:UserData.msinfo.ClustPar.MaxClasses
        choice = [choice sprintf('%i Classes|',i)];
    end

    choice(end) = [];
   
    if ~isnan(UserData.nClasses)
        idx = UserData.nClasses - UserData.msinfo.ClustPar.MinClasses + 1;
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

    if ud.nClasses < ud.msinfo.ClustPar.MinClasses
        ud.nClasses = ud.msinfo.ClustPar.MinClasses;
    end


    if ud.nClasses  > ud.msinfo.ClustPar.MaxClasses
        ud.nClasses = ud.msinfo.ClustPar.MaxClasses;
    end

    set(fh,'userdata',ud);
    PlotMSMaps(obj,event,fh);
end

function EditMSLabel(obj,~,i,j)
    set(obj,'Editing','on');
    fh = get(get(obj,'Parent'),'Parent');
    ud = get(fh,'UserData');
    ud.LabelEdited(i,j) = true;
    set(fh,'UserData',ud);
end

function ClearMaps(fh)

    figure(fh);
    UserData = get(fh,'UserData');  

    
    if ~isnan(UserData.nClasses)
        sp_x = ceil(sqrt(UserData.nClasses));
        sp_y = ceil(UserData.nClasses / sp_x);
    else
        sp_x = UserData.msinfo.ClustPar.MaxClasses;
        sp_y = UserData.msinfo.ClustPar.MaxClasses - UserData.msinfo.ClustPar.MinClasses + 1;
    end
    for m = 1:sp_x*sp_y
        h = subplot(sp_y,sp_x,m);
        cla(h);
        set(h, 'Visible','off');
    end
end



function PlotMSMaps(~, ~,fh)
% --------------------------

    figure(fh);
    UserData = get(fh,'UserData');  

    ClearMaps(fh);

    X = cell2mat({UserData.chanlocs.X});
    Y = cell2mat({UserData.chanlocs.Y});
    Z = cell2mat({UserData.chanlocs.Z});
    
    tic()
    
    
%    Montage = UserData.chanlocs;
%    QMap = dspMapClass(Montage);
%    HelperData = QMap.GetQuickMontage();
    
%    disp('1');
%    toc()
    if ~isnan(UserData.nClasses)
        sp_x = ceil(sqrt(UserData.nClasses));
        sp_y = ceil(UserData.nClasses / sp_x);
    
        for m = 1:UserData.nClasses
            h = subplot(sp_y,sp_x,m);
            h.Toolbar.Visible = 'off';
            Background = UserData.AllMaps(UserData.nClasses).ColorMap(m,:);
%            dspMapClass(Montage,'HelperData',HelperData,'Map',double(UserData.AllMaps(UserData.nClasses).Maps(m,:)'));
%            toc()
            dspCMap(double(UserData.AllMaps(UserData.nClasses).Maps(m,:)),[X; Y;Z],'NoScale','Resolution',3,'Background',Background,'ShowNose',15);
        
            UserData.TitleHandles{m,1} = title(UserData.Labels{UserData.nClasses,m},'FontSize',10,'Interpreter','none');
        
            if UserData.DoEdit == true
                set(UserData.TitleHandles{m,1},'ButtonDownFcn',{@EditMSLabel,UserData.nClasses,m});
            end
        end
    
        if UserData.nClasses == UserData.msinfo.ClustPar.MinClasses
            set(UserData.MinusButton,'enable','off');
        else
            set(UserData.MinusButton,'enable','on');
        end

        if UserData.nClasses == UserData.msinfo.ClustPar.MaxClasses
            set(UserData.PlusButton,'enable','off');
        else
            set(UserData.PlusButton,'enable','on');
        end
    else
        sp_x = UserData.msinfo.ClustPar.MaxClasses;
        sp_y = UserData.msinfo.ClustPar.MaxClasses - UserData.msinfo.ClustPar.MinClasses + 1;
    
        for y_pos = 1:sp_y
            for x_pos = 1:UserData.msinfo.ClustPar.MinClasses + y_pos - 1
                h = subplot(sp_y,sp_x,(y_pos-1) * sp_x + x_pos);
                Background = UserData.AllMaps(y_pos + UserData.msinfo.ClustPar.MinClasses-1).ColorMap(x_pos,:);
%                dspMapClass(Montage,'HelperData',HelperData,'Map',double(UserData.AllMaps(y_pos + UserData.msinfo.ClustPar.MinClasses-1).Maps(x_pos,:))');
%                toc
                dspCMap(double(UserData.AllMaps(y_pos + UserData.msinfo.ClustPar.MinClasses-1).Maps(x_pos,:)),[X; Y;Z],'NoScale','Resolution',3,'Background',Background,'ShowNose',15);

                UserData.TitleHandles{y_pos,x_pos} = title(UserData.Labels{y_pos + UserData.msinfo.ClustPar.MinClasses-1,x_pos},'FontSize',10,'Interpreter','none');
                if UserData.DoEdit == true
                    set(UserData.TitleHandles{y_pos,x_pos},'ButtonDownFcn',{@EditMSLabel,y_pos + UserData.msinfo.ClustPar.MinClasses-1,x_pos});
                end
                h.Toolbar.Visible = 'off';
                h.PickableParts = 'all';
            end
        end
        h = subplot(sp_y,sp_x,sp_x);
%s        set(h, 'Visible','on');
        h.Toolbar.Visible = 'off';

        ht = title('test');
        ht.ButtonDownFcn = 'disp("gag")';
        
    end
        
        
    set(fh,'UserData',UserData);  

end

