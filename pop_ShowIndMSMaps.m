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
function [AllEEG,TheEEG,com] = pop_ShowIndMSMaps(TheEEG,nclasses, DoEdit, AllEEG)
    
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
    else                eTxt = 'off';
    end
        
    ud.MinusButton = uicontrol('Style', 'pushbutton', 'String', 'Less'      , 'Units','Normalized','Position'  , [0.05 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps,-1,fig_h});
    ud.PlusButton  = uicontrol('Style', 'pushbutton', 'String', 'More'      , 'Units','Normalized','Position'  , [0.20 0.05 0.15 0.05], 'Callback', {@ChangeMSMaps, 1,fig_h});
    ud.ShowDyn     = uicontrol('Style', 'pushbutton', 'String', 'Dynamics'  , 'Units','Normalized','Position'  , [0.35 0.05 0.15 0.05], 'Callback', {@ShowDynamics, fig_h, TheEEG});
    ud.Info        = uicontrol('Style', 'pushbutton', 'String', 'Info'      , 'Units','Normalized','Position'  , [0.50 0.05 0.15 0.05], 'Callback', {@MapInfo     , fig_h});
    ud.Sort        = uicontrol('Style', 'pushbutton', 'String', 'Man. sort' , 'Units','Normalized','Position'  , [0.65 0.05 0.15 0.05], 'Callback', {@ManSort     , fig_h}, 'Enable',eTxt);
    ud.DoEdit = DoEdit;
    ud.LabelEdited = false(ud.msinfo.ClustPar.MaxClasses,ud.msinfo.ClustPar.MaxClasses);
    
    ud.Labels = cell(ud.msinfo.ClustPar.MaxClasses,ud.msinfo.ClustPar.MaxClasses);
    ud.TitleHandles = cell(ud.msinfo.ClustPar.MaxClasses,1);
    for i = ud.msinfo.ClustPar.MinClasses:ud.msinfo.ClustPar.MaxClasses
        if isfield(ud.AllMaps(i),'Labels')
            ud.Labels(i,1:i) = ud.AllMaps(i).Labels(1:i);
        else
            for j = 1:i
                ud.Labels{i,j} = sprintf('MS_%i',j);
            end
        end
    end
        
    if DoEdit == true
        ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'     , 'Units','Normalized','Position', [0.80 0.05 0.15 0.05], 'Callback', 'uiresume(gcf)');
    else
        ud.Done        = uicontrol('Style', 'pushbutton', 'String', 'Close'     , 'Units','Normalized','Position', [0.80 0.05 0.15 0.05], 'Callback', 'close(gcf)');
    end
    
    set(fig_h,'userdata',ud);
    PlotMSMaps([],[],fig_h);
    
    set(fig_h,'Name', ['Microstate maps of ' TheEEG.setname],'NumberTitle','off');
    if nargin < 4
        com = sprintf('[empty,EEG,com] = pop_ShowIndMSMaps(%s, %i, %i);', inputname(1), inputname(1),nclasses,DoEdit);
    else
        com = sprintf('[AllEEG,EEG,com] = pop_ShowIndMSMaps(%s, %i, %i, %s);', inputname(1), nclasses,DoEdit, inputname(4));
    end
    
    if DoEdit == true
        uiwait(fig_h);
        if ~isvalid(fig_h)
            return
        end
        ud = get(fig_h,'Userdata');
        for k = 1: ud.nClasses
             ud.Labels{ud.nClasses,k} = get(ud.TitleHandles{k,1},'String');
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

    res = inputgui( 'geometry', {[3 1]}, 'geomvert', 1,  'uilist', { ...
                 { 'Style', 'text', 'string', 'Index of original position (negative to flip polarity)', 'fontweight', 'bold'  } ...
                 { 'style', 'edit', 'string', sprintf('%i ',1:UserData.nClasses) } },'title','Reorder microstates');

    if isempty(res)
        return
    end

    NewOrder = sscanf(res{1},'%i');
    NewOrderSign = sign(NewOrder);
    NewOrder = abs(NewOrder);
    
    if numel(NewOrder) ~= UserData.nClasses
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        return
    end

    if numel(unique(NewOrder)) ~= UserData.nClasses
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        return
    end
    if any(unique(NewOrder) ~= unique(1:UserData.nClasses)')
        errordlg2('Invalid order given','Manually rearrange microstate class sequence');
        return
    end
            
    UserData.AllMaps(UserData.nClasses).Maps = UserData.AllMaps(UserData.nClasses).Maps(NewOrder,:).*repmat(NewOrderSign,1,size(UserData.AllMaps(UserData.nClasses).Maps,2));
    size(UserData.AllMaps(UserData.nClasses).Maps)
    UserData.AllMaps(UserData.nClasses).SortedMode = 'manual';
    UserData.AllMaps(UserData.nClasses).SortedBy = 'user';
    UserData.wasSorted = true;
    set(fh,'UserData',UserData);
    PlotMSMaps(obj,event,fh);
end



function ShowDynamics(obj, event,fh, TheEEG)
% ---------------------------------------
    UserData = get(fh,'UserData');
    TheEEG.msinfo.FitPar.nClasses = UserData.nClasses;
    pop_ShowIndMSDyn(0,TheEEG,0);
end

function MapInfo(obj, event, fh)
% ------------------------------

    UserData = get(fh,'UserData');    

    AlgorithmTxt = {'k-means','AAHC'};
    PolarityText = {'considererd','ignored'};
    GFPText      = {'all data', 'GFP peaks only'};
    NormText     = {'not ', ''};
    if isinf(UserData.msinfo.ClustPar.MaxMaps)
            MaxMapsText = 'all';
    else    MaxMapsText = num2str(UserData.msinfo.ClustPar.MaxMaps,'%i');
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
            sprintf('Explained variance: %4.2f%%',UserData.AllMaps(UserData.nClasses).ExpVar * 100) ...
%            sprintf('Sorting was based  on %s ',UserData.AllMaps(UserData.nClasses).SortedBy)...
            };
    if isempty(UserData.AllMaps(UserData.nClasses).SortedBy)
        txt = [txt, 'Maps are unsorted'];
    else
        txt = [txt sprintf('Sort mode was %s ',UserData.AllMaps(UserData.nClasses).SortMode)];
        txt = [txt sprintf('Sorting was based  on %s ',UserData.AllMaps(UserData.nClasses).SortedBy)];
    end
            
    if ~isempty(UserData.Children)
        txt = [txt 'Children: ' UserData.Children];
    end
    
    msgbox(txt,'Info');

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

function PlotMSMaps(~, ~,fh)
% --------------------------

    UserData = get(fh,'UserData');  

    sp_x = ceil(sqrt(UserData.nClasses));
    sp_y = ceil(UserData.nClasses / sp_x);
    
    % fix structure of for loop to put subplots on one row
    for m = 1:sp_x*sp_y
        h = subplot(sp_y,sp_x,m);
        cla(h);
        set(h, 'Visible','off');
    end
    
    for m = 1:UserData.nClasses
        subplot(sp_y,sp_x,m);
        Background = UserData.AllMaps(UserData.nClasses).ColorMap(m,:);
        X = cell2mat({UserData.chanlocs.X});
        Y = cell2mat({UserData.chanlocs.Y});
        Z = cell2mat({UserData.chanlocs.Z});
        dspCMap(double(UserData.AllMaps(UserData.nClasses).Maps(m,:)),[X; Y;Z],'NoScale','Resolution',3,'Background',Background,'ShowNose',20);
        
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
    set(fh,'UserData',UserData);  

end

