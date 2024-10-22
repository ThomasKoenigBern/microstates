% GUI helper function to display an error message in response to certain 
% input cases during argument validation in pop functions.
%
% Inputs:
%   - msg: warning message to be displayed
%   - title: title of the dialog box
%   - listItems: optional, cell array to show as items of a scrollable list
%   box below the warning message
%
% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."

function errorDialog(msg, title, listItems)

    errorDlg = figure("Name", title, "MenuBar", "none", "ToolBar", "none", ...
        "NumberTitle", "off", "WindowStyle", "modal", "Color", [.66 .76 1]);
    if nargin > 2
        errorDlg.Position(3:4) = [550 450];
    else
        errorDlg.Position(3:4) = [550 200];
    end
    movegui(errorDlg, 'center');

    if nargin > 2
        uicontrol("Style", "text", "Units", "normalized", ...
            "Position", [0.05 0.7 0.9 0.22], "String", msg, "FontSize", 12, "Parent", errorDlg, ...
            "BackgroundColor", [.66 .76 1]);
        uicontrol("Style", "listbox", "Units", "normalized", ...
            "Position", [.2 .22 .6 .45], "String", listItems, "Min", 0, "Max", 2, ...
            "Value", [], "Enable", "inactive", "FontSize", 12, "Parent", errorDlg);
        uicontrol("Style", "pushbutton", "String", "OK", "Units", "normalized", ...
            "Position", [.4 .05 .2 .1], "FontSize", 12, "Parent", errorDlg, "Callback", @figClose);
    else
        uicontrol("Style", "text", "Units", "normalized", ...
            "Position", [.05 .25 .9 .65], "String", msg, "FontSize", 12, "Parent", errorDlg, ...
            "BackgroundColor", [.66 .76 1]);
        uicontrol("Style", "pushbutton", "String", "OK", "Units", "normalized", ...
            "Position", [.4 .05 .2 .15], "FontSize", 12, "Parent", errorDlg, "Callback", @figClose);
    end

    if exist('beep') == 5
	    beep;
    end

    function figClose(src, ~)
        close(src.Parent);
    end
    
end