function varargout = Ragu_ImportIndFeatFromExcel(varargin)
% RAGU_IMPORTINDFEATFROMEXCEL MATLAB code for Ragu_ImportIndFeatFromExcel.fig
%      RAGU_IMPORTINDFEATFROMEXCEL, by itself, creates a new RAGU_IMPORTINDFEATFROMEXCEL or raises the existing
%      singleton*.
%
%      H = RAGU_IMPORTINDFEATFROMEXCEL returns the handle to a new RAGU_IMPORTINDFEATFROMEXCEL or the handle to
%      the existing singleton*.
%
%      RAGU_IMPORTINDFEATFROMEXCEL('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RAGU_IMPORTINDFEATFROMEXCEL.M with the given input arguments.
%
%      RAGU_IMPORTINDFEATFROMEXCEL('Property','Value',...) creates a new RAGU_IMPORTINDFEATFROMEXCEL or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Ragu_ImportIndFeatFromExcel_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Ragu_ImportIndFeatFromExcel_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Ragu_ImportIndFeatFromExcel

% Last Modified by GUIDE v2.5 12-Apr-2018 14:49:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Ragu_ImportIndFeatFromExcel_OpeningFcn, ...
                   'gui_OutputFcn',  @Ragu_ImportIndFeatFromExcel_OutputFcn, ...
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


% --- Executes just before Ragu_ImportIndFeatFromExcel is made visible.
function Ragu_ImportIndFeatFromExcel_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Ragu_ImportIndFeatFromExcel (see VARARGIN)

% Choose default command line output for Ragu_ImportIndFeatFromExcel
handles.output = hObject;
if ~isfield(varargin{4},'ExcelPredictorFile')
    varargin{4}.ExcelPredictorFile.Path = '*.xls';
    varargin{4}.ExcelPredictorFile.Sheet = 1;
    varargin{4}.ExcelPredictorFile.SID   = 1;
    varargin{4}.ExcelPredictorFile.VID   = 1;
    varargin{4}.ExcelPredictorFile.nSID  = 8;

end
   
if ~isfield(varargin{4}.ExcelPredictorFile,'Path')
    varargin{4}.ExcelPredictorFile.Path = '*.xls';
end

if ~isfield(varargin{4}.ExcelPredictorFile,'Sheet')
    varargin{4}.ExcelPredictorFile.Sheet = 1;
end

if ~isfield(varargin{4}.ExcelPredictorFile,'SID')
    varargin{4}.ExcelPredictorFile.SID = 1;
end

if ~isfield(varargin{4}.ExcelPredictorFile,'VID')
    varargin{4}.ExcelPredictorFile.VID = 1;
end

if ~isfield(varargin{4}.ExcelPredictorFile,'nSID')
    varargin{4}.ExcelPredictorFile.VID = 8;
end

if ~isfield(varargin{4}.ExcelPredictorFile,'IsCategorical')
    varargin{4}.ExcelPredictorFile.IsCategorical = 1;
end


global xlsraw

if ~exist(varargin{4}.ExcelPredictorFile.Path,'file')
    varargin{4}.ExcelPredictorFile.Path = '*.xls*';
else

    [~,~,xlsraw] = xlsread(varargin{4}.ExcelPredictorFile.Path,varargin{4}.ExcelPredictorFile.Sheet);
    set(handles.PopupSID,'String',xlsraw(1,:));
    set(handles.PopupSID,'Value',varargin{4}.ExcelPredictorFile.SID);
    set(handles.PopupVID,'String',xlsraw(1,:));    
    set(handles.PopupVID,'Value',varargin{4}.ExcelPredictorFile.VID); 
end

set(handles.EditExcelFile,'String',varargin{4}.ExcelPredictorFile.Path);
set(handles.SheetNumber  ,'String',varargin{4}.ExcelPredictorFile.Sheet);
set(handles.nSID         ,'String',varargin{4}.ExcelPredictorFile.nSID);
set(handles.IsCategorical,'Value',varargin{4}.ExcelPredictorFile.IsCategorical);

set(handles.output,'UserData',varargin{4});

CheckIfWeAreReady(handles);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Ragu_ImportIndFeatFromExcel wait for user response (see UIRESUME)
uiwait(handles.Ragu_ImportIndFeatFromExcel);


% --- Outputs from this function are returned to the command line.
function varargout = Ragu_ImportIndFeatFromExcel_OutputFcn(hObject, eventdata, handles) 
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



function EditExcelFile_Callback(hObject, eventdata, handles)


% --- Executes during object creation, after setting all properties.
function EditExcelFile_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ButtonXLSFile.
function ButtonXLSFile_Callback(hObject, eventdata, handles)

rd = get(handles.output,'UserData');

[fnx,pnx] = uigetfile(rd.ExcelPredictorFile.Path,'Name of the Excel data file');

if fnx == 0
    return
end


set(handles.EditExcelFile,'String',fullfile(pnx,fnx));

%Sheet = str2double(get(handles.SheetNumber,'String'));

SheetCell = inputdlg('Enter sheet name (or cancel to select the first sheet)');

if isempty(SheetCell)
    Sheet = 1;
else
    Sheet = SheetCell{1};
end

rd.ExcelPredictorFile.Path  = fullfile(pnx,fnx);
rd.ExcelPredictorFile.Sheet = Sheet;

global xlsraw

[~,~,xlsraw] = xlsread(fullfile(pnx,fnx),Sheet);

rd.ExcelPredictorFile.SID = 1;
rd.ExcelPredictorFile.VID = 1;

set(handles.PopupSID,'String',xlsraw(1,:),'Value',rd.ExcelPredictorFile.SID);
set(handles.PopupVID,'String',xlsraw(1,:),'Value',rd.ExcelPredictorFile.VID);

set(handles.output,'UserData',rd);

CheckIfWeAreReady(handles);



% --- Executes on selection change in PopupSID.
function PopupSID_Callback(hObject, eventdata, handles)
% hObject    handle to PopupSID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns PopupSID contents as cell array
%        contents{get(hObject,'Value')} returns selected item from PopupSID

rd = get(handles.output,'UserData');
rd.ExcelPredictorFile.SID = get(hObject,'Value');
set(handles.output,'UserData',rd);

CheckIfWeAreReady(handles);



% --- Executes during object creation, after setting all properties.
function PopupSID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PopupSID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in PopupVID.
function PopupVID_Callback(hObject, eventdata, handles)
% hObject    handle to PopupVID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns PopupVID contents as cell array
%        contents{get(hObject,'Value')} returns selected item from PopupVID


rd = get(handles.output,'UserData');
rd.ExcelPredictorFile.VID = get(hObject,'Value');
set(handles.output,'UserData',rd);
CheckIfWeAreReady(handles);

function CheckIfWeAreReady(handles)

RaguData = get(handles.output,'UserData');
global xlsraw

WeAreReady = ~isempty(RaguData) & ~isempty(xlsraw);

if WeAreReady
    set(handles.ButtonSave,'Enable','On');
else
    set(handles.ButtonSave,'Enable','Off');
end




% --- Executes during object creation, after setting all properties.
function PopupVID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to PopupVID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ButtonSave.
function ButtonSave_Callback(hObject, eventdata, handles)
% hObject    handle to ButtonSave (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

rd = get(handles.output,'UserData');
global xlsraw

ExcludedCases = isnan(rd.IndFeature);
rd.IndFeature = nan(size(rd.IndFeature));

nWarning = 0;
Warning{1} = 'Excluded cases:';

xlsCode = xlsraw(2:end,rd.ExcelPredictorFile.SID);

for i = 1:numel(xlsCode)
    if isnumeric(xlsCode{i,1})
        xlsCode(i,1) = {sprintf('%i',xlsCode{i,1},0)};
    end
end

for s = 1:size(rd.Names,1)

    idx = find(strncmpi(rd.Names(s,1),xlsCode,rd.ExcelPredictorFile.nSID));
    switch numel(idx)
        case 1
            if ~isnumeric(xlsraw{idx+1,rd.ExcelPredictorFile.VID})
                nWarning = nWarning + 1;
                Warning{nWarning+1} = rd.Names{s,1};
            else
                rd.IndFeature(s) = xlsraw{idx+1,rd.ExcelPredictorFile.VID};
            end
        case 0
            nWarning = nWarning + 1;
            Warning{nWarning+1} = rd.Names{s,1};
        otherwise
            errordlg(['Doublicate data found for ERP ' rd.Names{s,1} ', (and maybe others...)'],'Import from Excel');
            break;
            
    end
end

rd.IndFeature(ExcludedCases) = nan;
rd.IndName = xlsraw{1,rd.ExcelPredictorFile.VID};


if nWarning > 0
    uiwait(msgbox(Warning,'Done','modal'));
else
    uiwait(msgbox('Done','modal'));
end

switch(get(handles.IsCategorical,'Value'))
    case 1
        rd.ContBetween = true;
    case 2
        rd.ContBetween = false;
        minlevel = min(rd.IndFeature(~isnan(rd.IndFeature)));
        dlt = 1 - minlevel;
        rd.IndFeature = rd.IndFeature + dlt;
end

set(handles.output,'UserData',rd);

uiresume(handles.Ragu_ImportIndFeatFromExcel);


function nSID_Callback(hObject, eventdata, handles)
% hObject    handle to nSID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nSID as text
%        str2double(get(hObject,'String')) returns contents of nSID as a double

rd = get(handles.output,'UserData');
rd.ExcelPredictorFile.nSID = str2double(get(hObject,'String'));
set(handles.output,'UserData',rd);
CheckIfWeAreReady(handles);

% --- Executes during object creation, after setting all properties.
function nSID_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function SheetNumber_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function SheetNumber_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in IsCategorical.
function IsCategorical_Callback(hObject, eventdata, handles)
% hObject    handle to IsCategorical (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns IsCategorical contents as cell array
%        contents{get(hObject,'Value')} returns selected item from IsCategorical


% --- Executes during object creation, after setting all properties.
function IsCategorical_CreateFcn(hObject, eventdata, handles)
% hObject    handle to IsCategorical (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
