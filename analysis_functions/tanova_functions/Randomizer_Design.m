
function varargout = Randomizer_Design(varargin)
% RANDOMIZER_DESIGN M-file for Randomizer_Design.fig
%      RANDOMIZER_DESIGN, by itself, creates a new RANDOMIZER_DESIGN or raises the existing
%      singleton*.
%
%      H = RANDOMIZER_DESIGN returns the handle to a new RANDOMIZER_DESIGN or the handle to
%      the existing singleton*.
%
%      RANDOMIZER_DESIGN('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RANDOMIZER_DESIGN.M with the given input arguments.
%
%      RANDOMIZER_DESIGN('Property','Value',...) creates a new RANDOMIZER_DESIGN or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Randomizer_Design_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Randomizer_Design_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Randomizer_Design

% Last Modified by GUIDE v2.5 21-Jun-2010 16:46:51

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Randomizer_Design_OpeningFcn, ...
                   'gui_OutputFcn',  @Randomizer_Design_OutputFcn, ...
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

% --- Executes just before Randomizer_Design is made visible.
function Randomizer_Design_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Randomizer_Design (see VARARGIN)

% Choose default command line output for Randomizer_Design
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

out = varargin{4};
set(handles.TwoFactors,'Value',0);

if size(out.Design,1) ~= size(out.conds,1)
    out.Design = ones(size(out.conds,1),2);
end
out.SelFactor = 1;
set(handles.output,'UserData',out);
set(handles.Conditions,'String',out.conds);
set(handles.TwoFactors,'Value',out.TwoFactors);

if out.TwoFactors == true
    set(handles.Cont_F1,'Value',0);
    set(handles.Cont_F1,'Enable','off');
    out.ContF1 = false;
end


if isfield(out,'strF1')
    set(handles.strF1,'String',out.strF1);
else
    set(handles.strF1,'String','Factor 1');
end
if isfield(out,'strF2')
    set(handles.strF2,'String',out.strF2);
else
    set(handles.strF2,'String','Factor 2');
end

if isfield(out,'ContF1')
    set(handles.Cont_F1,'Value',out.ContF1);
    
else
    set(handles.Cont_F1,'Value',0);
end

colors = lines(2);
ShowData(out,handles);
set(handles.F1,'BackgroundColor',colors(1,:));
% UIWAIT makes Randomizer_Design wait for user response (see UIRESUME)
uiwait(handles.output);


% --- Outputs from this function are returned to the command line.
function varargout = Randomizer_Design_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
if isempty(handles)
    varargout{1} = [];
else
    varargout{1} = handles.output;
end

% --- Executes on selection change in Conditions.
function Conditions_Callback(hObject, eventdata, handles)
% hObject    handle to Conditions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns Conditions contents as cell array
%        contents{get(hObject,'Value')} returns selected item from Conditions


% --- Executes during object creation, after setting all properties.
function Conditions_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Conditions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Plus.
function Plus_Callback(hObject, eventdata, handles)
% hObject    handle to Plus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sel = get(handles.Conditions,'Value');
out = get(handles.output,'UserData');

for i = 1:numel(sel)
    if isnan(out.Design(sel(i),out.SelFactor))
        out.Design(sel(i),1:2) = 1;
    else
        out.Design(sel(i),out.SelFactor) = out.Design(sel(i),out.SelFactor)+1;
    end
end
set(handles.output,'UserData',out);
ShowData(out,handles);


% --- Executes on button press in Minus.
function Minus_Callback(hObject, eventdata, handles)
% hObject    handle to Minus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sel = get(handles.Conditions,'Value');
out = get(handles.output,'UserData');
for i = 1:numel(sel)
    out.Design(sel(i),out.SelFactor) = out.Design(sel(i),out.SelFactor)-1;
end
set(handles.output,'UserData',out);
ShowData(out,handles);


% --- Executes on button press in F1.
function F1_Callback(hObject, eventdata, handles)
% hObject    handle to F1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

colors = lines(2);
out = get(handles.output,'UserData');
out.SelFactor = 1;
set(handles.output,'UserData',out);
set(hObject,'BackgroundColor',colors(1,:));
if (get(handles.TwoFactors,'Value'))
    set(handles.F2,'BackgroundColor',[0.8 0.8 0.8]);
else
    set(handles.F2,'BackgroundColor',[0.2 0.2 0.2]);
end


% --- Executes on button press in F2.
function F2_Callback(hObject, eventdata, handles)
% hObject    handle to F2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if (~get(handles.TwoFactors,'Value'))
    return
end
colors = lines(2);

out = get(handles.output,'UserData');
out.SelFactor = 2;
set(handles.output,'UserData',out);
set(hObject,'BackgroundColor',colors(2,:));
set(handles.F1,'BackgroundColor',[0.8 0.8 0.8]);


% --- Executes on button press in TwoFactors.
function TwoFactors_Callback(hObject, eventdata, handles)
% hObject    handle to TwoFactors (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
out.SelFactor = 1;
out.TwoFactors = get(handles.TwoFactors,'Value');

if (out.TwoFactors)
    set(handles.F2,'Enable','on');
    set(handles.strF2,'Enable','on');
    set(handles.F2,'BackgroundColor',[0.8 0.8 0.8]);
    set(handles.tblLevel2,'Enable','on');
    set(handles.Cont_F1,'Value',0);
    set(handles.Cont_F1,'Enable','off');
else
    set(handles.F2,'Enable','off');
    set(handles.strF2,'Enable','off');
    set(handles.F2,'BackgroundColor',[0.2 0.2 0.2]);
    set(handles.tblLevel2,'Enable','off');
    set(handles.Cont_F1,'Enable','on');
end
set(handles.output,'UserData',out);

ShowData(out,handles);

% --- Function to show the design and more.
function ShowData(out,handles)
mx = max(out.Design(:));
mn = min(out.Design(:));

dlt = mx-mn;
mx = mx + 0.2 * dlt;
mn = mn - 0.2 * dlt;
if mx == mn
    mx = mx +0.2;
end

%handles
axes(handles.axes1);

if (out.TwoFactors)
    bar(out.Design);
else
    bar(out.Design(:,1));
end
colormap([0 1 0; 1 0 0]);
set(gca,'XTick',1:numel(out.conds),'XTickLabel',out.conds);
rotateticklabel(gca,90,~isnan(out.Design(:,1))); 

if out.TwoFactors == 1
    c = corrcoef(out.Design(~isnan(out.Design(:,1)),1),out.Design(~isnan(out.Design(:,1)),2));
   
    if numel(c) > 1
        if c(1,2) ~= 0
            set(handles.Done,'Enable','off','String','Make design orthogonal before completing','BackgroundColor',[1 0 0]);
        else
            set(handles.Done,'Enable','on','String','Save new design (clears previous results)','BackgroundColor',[0 1 0]);
        end
    else
        set(handles.Done,'Enable','on','String','Save new design (clears previous results)','BackgroundColor',[0 1 0]);
    end
else
%     s = out.Design(:,1);
%     s = s(~isnan(s));
%     i = unique(s);
%     if (numel(s) > 1) && (numel(i) == 1)
%         set(handles.Done,'Enable','off','String','Define design before completing','BackgroundColor',[1 0 0]);
%     else
        set(handles.Done,'Enable','on','String','Done','BackgroundColor',[0 1 0]);
%    end
end
UpdateTablesFromDesign(handles);

% --- Executes on button press in Done.
function Done_Callback(hObject, eventdata, handles)
% hObject    handle to Done (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
out = get(handles.output,'UserData');
set(handles.output,'UserData',out);
uiresume(handles.output);


function strF1_Callback(hObject, eventdata, handles)
% hObject    handle to strF1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of strF1 as text
%        str2double(get(hObject,'String')) returns contents of strF1 as a double

out = get(handles.output,'UserData');
out.strF1 = get(hObject,'String');
set(handles.output,'UserData',out);

% --- Executes during object creation, after setting all properties.
function strF1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to strF1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function strF2_Callback(hObject, eventdata, handles)
% hObject    handle to strF2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of strF2 as text
%        str2double(get(hObject,'String')) returns contents of strF2 as a double
out = get(handles.output,'UserData');
out.strF2 = get(hObject,'String');
set(handles.output,'UserData',out);

% --- Executes during object creation, after setting all properties.
function strF2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to strF2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Button_NaN.
function Button_NaN_Callback(hObject, eventdata, handles)
% hObject    handle to Button_NaN (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

sel = get(handles.Conditions,'Value');
out = get(handles.output,'UserData');
for i = 1:numel(sel)
    out.Design(sel(i),1:2) = NaN;
end
set(handles.output,'UserData',out);
ShowData(out,handles);

% --- Updates the tables when design has changes.
function UpdateTablesFromDesign(handles)

out = get(handles.output,'UserData');

l1 = unique(out.Design(~isnan(out.Design(:,1)),1));
l2 = unique(out.Design(~isnan(out.Design(:,2)),2));

if(all(isnan(l2)))
    if(isfield(out,'DLabels2'))
        out = rmfield(out,'DLabels2');
        out.TwoFactors = false;
    end
end


% Fill in the defaults
for i = 1:numel(l1)
    DLabels1(i).Level = l1(i);
    DLabels1(i).Label = sprintf('F1_%i',l1(i));
end

% And overwrite where data exists
if(isfield(out,'DLabels1'))
    row = {};
    [row{1:numel(out.DLabels1),1}] = deal(out.DLabels1.Level);

    data = {};
    [data{1:numel(out.DLabels1),1}] = deal(out.DLabels1.Label);
  
    for i = 1:numel(l1)
        DLabels1(i).Level = l1(i);
        DLabels1(i).Label = sprintf('F1_%i',l1(i));
        for j = 1:numel(row)
            if l1(i) == row{j}
                DLabels1(i).Label = char(data{j});
            end
        end
    end
end
   

for i = 1:numel(l2)
    DLabels2(i).Level = l2(i);
    DLabels2(i).Label = sprintf('F2_%i',l2(i));
end




if(isfield(out,'DLabels2'))
    row = {};
    [row{1:numel(out.DLabels2),1}] = deal(out.DLabels2.Level);

    data = {};
    [data{1:numel(out.DLabels2),1}] = deal(out.DLabels2.Label);

    for i = 1:numel(l2)
        DLabels2(i).Level = l2(i);
        DLabels2(i).Label = sprintf('F2_%i',l2(i));
        for j = 1:numel(row)
            if l2(i) == row{j}
                DLabels2(i).Label = char(data{j});
            end
        end
    end
end

data = {};
[data{1:numel(DLabels1),1}] = deal(DLabels1.Label);
rows = {};
[rows{1:numel(DLabels1),1}] = deal(DLabels1.Level);

set(handles.tblLevel1,'RowName',rows,'Data',data);
out.DLabels1 = DLabels1;

data = {};
if(isfield(out,'DLabels2'))
    [data{1:numel(DLabels2),1}] = deal(DLabels2.Label);
    rows = {};
    [rows{1:numel(DLabels2),1}] = deal(DLabels2.Level);

    set(handles.tblLevel2,'RowName',rows,'Data',data);
    out.DLabels2 = DLabels2;
end
set(handles.output,'UserData',out);


% --- Executes when entered data in editable cell(s) in tblLevel1.
function tblLevel1_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tblLevel1 (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
out.DLabels1(eventdata.Indices(1)).Label = eventdata.NewData;
set(handles.output,'UserData',out);


% --- Executes when entered data in editable cell(s) in tblLevel2.
function tblLevel2_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to tblLevel2 (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

out = get(handles.output,'UserData');
out.DLabels2(eventdata.Indices(1)).Label = eventdata.NewData;
set(handles.output,'UserData',out);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)


% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
%if strcmp(questdlg('Discard changes?','Close request','Yes','No','Yes'),'Yes')
    delete(hObject);




% --- Executes on button press in Cont_F1.
function Cont_F1_Callback(hObject, eventdata, handles)
% hObject    handle to Cont_F1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of Cont_F1
out = get(handles.output,'UserData');
out.ContF1 = get(handles.Cont_F1,'Value');
set(handles.output,'UserData',out);



