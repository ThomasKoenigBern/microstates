function varargout = Randomizer_IndFeatures(varargin)
% RANDOMIZER_INDFEATURES M-file for Randomizer_IndFeatures.fig
%      RANDOMIZER_INDFEATURES, by itself, creates a new RANDOMIZER_INDFEATURES or raises the existing
%      singleton*.
%
%      H = RANDOMIZER_INDFEATURES returns the handle to a new RANDOMIZER_INDFEATURES or the handle to
%      the existing singleton*.
%
%      RANDOMIZER_INDFEATURES('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RANDOMIZER_INDFEATURES.M with the given input arguments.
%
%      RANDOMIZER_INDFEATURES('Property','Value',...) creates a new RANDOMIZER_INDFEATURES or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Randomizer_IndFeatures_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Randomizer_IndFeatures_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

% Edit the above text to modify the response to help Randomizer_IndFeatures

% Last Modified by GUIDE v2.5 11-Apr-2018 12:08:40

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Randomizer_IndFeatures_OpeningFcn, ...
                   'gui_OutputFcn',  @Randomizer_IndFeatures_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Randomizer_IndFeatures is made visible.
function Randomizer_IndFeatures_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Randomizer_IndFeatures (see VARARGIN)

% Choose default command line output for Randomizer_IndFeatures
%get(handles.output,'UserData')
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);
out = varargin{4};

if (size(out.IndFeature,1) ~= size(out.Names,1))
    out.IndFeature = zeros(size(out.Names,1),1);
end

tmp = out.IndFeature;
tmp(isnan(tmp)) = [];

if sum(abs(tmp - round(tmp))) > 0
    uiwait(msgbox('Non-integer category indices found, switched to rank/interval scaled mode','Warning','modal'));
    out.ContBetween = 1;
end



set(handles.output,'UserData',out);
set(handles.VarName,'String',out.IndName);
set(handles.checkInterval,'Value',out.ContBetween);
set(handles.uiSubjects,'UserData',[]);
set(handles.uitableGroups,'UserData',[]);
if out.ContBetween == true
    set(handles.uitableGroups,'Enable','off');
else
    set(handles.uitableGroups,'Enable','on');
end
figure(hObject);
ShowData(out,1);
UpdateGroups(handles);
UpdateTable(handles);
uiwait(hObject);


% UIWAIT makes Randomizer_IndFeatures wait for user response (see UIRESUME)

% --- Outputs from this function are returned to the command line.
function varargout = Randomizer_IndFeatures_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Get default command line output from handles structure
if (isempty(handles))
    varargout{1} = [];
else
    varargout{1} = handles.output;
end


function Behav_Input_Callback(hObject, eventdata, handles)
% hObject    handle to Behav_Input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object creation, after setting all properties.
function Behav_Input_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Behav_Input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in Done.
function Done_Callback(hObject, eventdata, handles)
% hObject    handle to Done (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%out = get(handles.figure1,'UserData')

out = get(handles.output,'UserData');
set(handles.output,'UserData',out);
uiresume(handles.figure1);

% --- Executes on button press in ChangeGraph.
function ChangeGraph_Callback(hObject, eventdata, handles)
% hObject    handle to ChangeGraph (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
out = get(handles.output,'UserData');
out.BarGraph = ~out.BarGraph;
set(gca,'XTickLabel',out.Names(:,1));
if (out.BarGraph)
    set(hObject,'String','LineGraph');
else
    set(hObject,'String','BarGraph');
end
ShowData(out,1);
set(handles.output,'UserData',out);

function ShowData(out,idx)
mx = max(out.IndFeature);
mn = min(out.IndFeature);
dlt = mx - mn;
mx = mx + 0.2 * dlt;
mn = mn - 0.2 * dlt;

if mx == mn
    mx = mx +1;
end
hold off
if (out.BarGraph)
    b = out.IndFeature;
    b(idx) = 0;
    h = bar(1:numel(out.IndFeature),b);
    set(h,'EdgeColor',[0 0 0],'FaceColor',[0 0 1]);
    hold on
    h = bar(idx,out.IndFeature(idx));
    set(h,'EdgeColor',[1 0 0 ],'FaceColor',[1 0 0]);
else
    plot(1:numel(out.IndFeature),out.IndFeature,'k-');
    hold on
    plot(idx,out.IndFeature(idx),'ro','MarkerSize',10,'MarkerFaceColor','r');
end
axis([0 (numel(out.IndFeature)+1) mn mx]);
hold off


function UpdateTable(handles,refresh)

if nargin < 2
    refresh = 1;
end

out = get(handles.output,'UserData');

if out.ContBetween == true
    set(handles.uiSubjects,'ColumnFormat',{'logical' 'char','numeric'});
    set(handles.uiSubjects,'ColumnName',{'Use' 'Subject','Value'});
else
    set(handles.uiSubjects,'ColumnFormat',{'logical' 'char',out.GroupLabels'});
    set(handles.uiSubjects,'ColumnName',{'Use' 'Subject','Group'});
end

data = cell(size(out.Names,1),3);

for i = 1:size(out.Names,1)
    data{i,1} = ~isnan(out.IndFeature(i));
    data{i,2} = char(out.Names{i});
    if out.ContBetween == true
        data{i,3} = out.IndFeature(i);
    else
        if (out.IndFeature(i) >= 1 && out.IndFeature(i) <= numel(out.GroupLabels))
                data{i,3} = char(out.GroupLabels{out.IndFeature(i),1});
        else
            data{i,3} = '';
        end
    end
end
if refresh == true
    set(handles.uiSubjects,'ColumnEditable',[true false true]);
    set(handles.uiSubjects,'Data',data);
end

% --- Executes on button press in checkInterval.
function checkInterval_Callback(hObject, eventdata, handles)
% hObject    handle to checkInterval (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkInterval

out = get(handles.output,'UserData');
if get(hObject,'Value') == 0
    out.ContBetween = false;
    set(handles.uitableGroups,'Visible','on');
    set(handles.uitableGroups,'Enable','on');
    
else
    out.ContBetween = true;
    set(handles.uitableGroups,'Visible','off');
end
set(handles.output,'UserData',out);

UpdateGroups(handles);
UpdateTable(handles);

function UpdateGroups(handles)

out = get(handles.output,'UserData');

lg = unique(out.IndFeature(~isnan(out.IndFeature)));
data = cell(25,1);
[data{1:25,1}] = deal('');

for i = 1:numel(lg)
    data{i,1} = sprintf('Group %i',lg(i));
end

if isfield(out,'GroupLabels')
    if size(out.GroupLabels,1) > numel(lg);
        out.GroupLabels((numel(lg)+1):end,:) = [];
    end
    
    for i = 1:numel(out.GroupLabels)
        if ~isempty(out.GroupLabels{i,1})
            data{i,1} = char(out.GroupLabels{i,1});
        end
    end
end

idx = zeros(size(data,1),1);
for i = 1:size(data,1)
    idx(i) = numel(data{i,1}) > 0;
end
idx = find(idx > 0);
out.GroupLabels = cell(numel(idx),1);

for i = 1:numel(idx)
    out.GroupLabels{i,1} = char(data{idx(i),1});
end

set(handles.uitableGroups,'Data',data);
set(handles.output,'UserData',out);



% --- Executes when entered data in editable cell(s) in uitableGroups.
function uitableGroups_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to uitableGroups (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
out.GroupLabels{eventdata.Indices(1),1} = eventdata.NewData;
set(handles.uitableGroups,'UserData',eventdata.Indices(1));
set(handles.output,'UserData',out);
UpdateTable(handles,1);



% --- Executes when entered data in editable cell(s) in uiSubjects.
function uiSubjects_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to uiSubjects (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
SelectedCells = eventdata.Indices(1);
if eventdata.Indices(2) == 3
    if  out.ContBetween == false;
        for i = 1:numel(out.GroupLabels)
            if(strcmp(out.GroupLabels{i,1},eventdata.NewData))
                out.IndFeature(eventdata.Indices(1)) = i;
            end
        end
    else
        out.IndFeature(eventdata.Indices(1)) = eventdata.NewData;
    end
end
if eventdata.Indices(2) == 1
    if eventdata.NewData == 1
        out.IndFeature(eventdata.Indices(1)) = 1;
    else
        out.IndFeature(eventdata.Indices(1)) = NaN;
    end
end


set(handles.uiSubjects,'UserData',SelectedCells);
set(handles.output,'UserData',out);
UpdateTable(handles,0);
ShowData(out,SelectedCells);
%ShowData(out,get(handles.VPList,'Value'));



% --- Executes when selected cell(s) is changed in uiSubjects.
function uiSubjects_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to uiSubjects (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
SelectedCells = eventdata.Indices(:,1);
set(handles.uiSubjects,'UserData',SelectedCells);
ShowData(out,SelectedCells);


% --- Executes when selected cell(s) is changed in uitableGroups.
function uitableGroups_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to uitableGroups (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)

SelectedGroups = eventdata.Indices(:,1);
if numel(SelectedGroups) > 1
    set(handles.SetSelected,'Enable','off');
else
    set(handles.SetSelected,'Enable','on');
end
set(handles.uitableGroups,'UserData',SelectedGroups);
UpdateTable(handles,1);


% --- Executes on button press in SetSelected.
function SetSelected_Callback(hObject, eventdata, handles)
% hObject    handle to SetSelected (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
SelectedGroups = get(handles.uitableGroups,'UserData');
SelectedSubjects = get(handles.uiSubjects,'UserData');
for i = 1:numel(SelectedSubjects)
    out.IndFeature(SelectedSubjects(i)) = SelectedGroups(1);
end
set(handles.output,'UserData',out);
UpdateTable(handles);
ShowData(out,SelectedSubjects);



% --- Executes on button press in ExcludeSelected.
function ExcludeSelected_Callback(hObject, eventdata, handles)
% hObject    handle to ExcludeSelected (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
SelectedSubjects = get(handles.uiSubjects,'UserData');
for i = 1:numel(SelectedSubjects)
    out.IndFeature(SelectedSubjects(i)) = NaN;
end
set(handles.output,'UserData',out);
UpdateTable(handles);
ShowData(out,SelectedSubjects);




function VarName_Callback(hObject, eventdata, handles)
% hObject    handle to VarName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of VarName as text
%        str2double(get(hObject,'String')) returns contents of VarName as a double

out = get(handles.output,'UserData');
out.IndName = get(hObject,'String');
set(handles.output,'UserData',out);


% --- Executes during object creation, after setting all properties.
function VarName_CreateFcn(hObject, eventdata, handles)
% hObject    handle to VarName (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
%if strcmp(questdlg('Discard changes?','Close request','Yes','No','Yes'),'Yes')
    delete(hObject);
%end



% --- Executes on button press in pushbuttonLoad.
function pushbuttonLoad_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonLoad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[inputfilename,inputpath] = uigetfile('*.txt','Enter text file with group indices / predictor values');

if inputfilename == 0
    return;
end

x = load(fullfile(inputpath,inputfilename));

out = get(handles.output,'UserData');

if numel(x) ~= size(out.Names,1)
    errordlg(['File ' inputfilename ' contains an invalid number of entries']);
    return;
end

out.IndFeature = x(:);

set(handles.output,'UserData',out);
UpdateTable(handles);
ShowData(out,1);




% --- Executes on button press in ButtonLoadFromExcel.
function ButtonLoadFromExcel_Callback(hObject, eventdata, handles)
% hObject    handle to ButtonLoadFromExcel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

h = Ragu_ImportIndFeatFromExcel(hObject,eventdata,handles,get(handles.output,'UserData'));
if (isempty(h))
    return
end

out = get(h,'UserData');

close(h);
set(handles.output,'UserData',out);
set(handles.VarName,'String',out.IndName);
set(handles.checkInterval,'Value',out.ContBetween);
set(handles.uiSubjects,'UserData',[]);
set(handles.uitableGroups,'UserData',[]);
if out.ContBetween == true
    set(handles.uitableGroups,'Enable','off');
else
    set(handles.uitableGroups,'Enable','on');
end
ShowData(out,1);
UpdateGroups(handles);
UpdateTable(handles);




% --- Executes on button press in Button_Reset.
function Button_Reset_Callback(hObject, eventdata, handles)
% hObject    handle to Button_Reset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
out = get(handles.output,'UserData');
out.IndName = 'None';
out.ContBetween = false;
out.IndFeature = ones(size(out.IndFeature));

set(handles.output,'UserData',out);
set(handles.VarName,'String',out.IndName);
set(handles.checkInterval,'Value',out.ContBetween);
set(handles.uiSubjects,'UserData',[]);
set(handles.uitableGroups,'UserData',[]);
set(handles.uitableGroups,'Enable','on');
ShowData(out,1);
UpdateGroups(handles);
UpdateTable(handles);


% --- Executes on button press in ButtonRegressThisOut.
function ButtonRegressThisOut_Callback(hObject, eventdata, handles)
% hObject    handle to ButtonRegressThisOut (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
out = get(handles.output,'UserData');

DataToUse = ~isnan(out.IndFeature);
DataToIgnore = isnan(out.IndFeature);
IndFeatureToUse = out.IndFeature(DataToUse);

if out.ContBetween == true
    IndFeatureToUse = IndFeatureToUse - mean(IndFeatureToUse);
    [~,nCon,nChan,nT] = size(out.V);
    for c = 1:nCon
        for i = 1:nChan
            for t = 1:nT
                data = squeeze(out.V(DataToUse,c,i,t));
                m = mean(data);
                b = regress(data-m,IndFeatureToUse);
                out.V(DataToUse,c,i,t) = data - IndFeatureToUse * b;
            end
        end
    end
else
    Groups = unique(IndFeatureToUse);
    OverallMean = mean(out.V(DataToUse,:,:,:),1);
    
    for g = 1:numel(Groups)
        GroupIndex = find(out.IndFeature == Groups(g));
        nSubjects = numel(GroupIndex);
        GroupMean = mean(out.V(GroupIndex,:,:,:),1);
        out.V(GroupIndex,:,:,:) = out.V(GroupIndex,:,:,:) - repmat(GroupMean,[nSubjects,1,1,1]) + repmat(OverallMean,[nSubjects,1,1,1]);
    end
end
uiwait(msgbox('Done!'));

out.V(DataToIgnore,:,:,:) = NaN;

set(handles.output,'UserData',out);
