% GUI helper function to display a warning in response to certain input
% cases during argument validation in pop functions. Notifies the user of
% the potential error and allows them to stop or continue, with the option
% to avoid showing the message again.
%
% Inputs:
%   - msg: warning message to be displayed
%   - title: title of the dialog box
%   - listItems: optional, cell array to show as items of a scrollable list
%   box below the warning message
%
% Outputs:
%   - yesPressed: 1 if the user pressed yes, 0 if not
%   - noPressed: 1 if the user pressed no, 0 if not
%   - boxChecked: 1 if the user checked the box to avoid showing the
%   warning message again, 0 if they did not
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

function [yesPressed, noPressed, boxChecked] = warningDialog(msg, title, listItems)

    yesPressed = false;
    noPressed = false;
    boxChecked = false;

    warnDlg = figure("Name", title, "MenuBar", "none", "ToolBar", "none", ...
        "NumberTitle", "off", "WindowStyle", "modal", "Color", [.66 .76 1]);
    if nargin > 2
        warnDlg.Position(3:4) = [500 400];
    else
        warnDlg.Position(3:4) = [500 300];
    end
    movegui(warnDlg, 'center');
    warnDlg.UserData.yesPressed = yesPressed;
    warnDlg.UserData.noPressed = noPressed;
    warnDlg.CloseRequestFcn = 'uiresume()';

    if nargin > 2
        uicontrol("Style", "text", "Units", "normalized", ...
            "Position", [0.05 0.75 0.9 0.15], "String", msg, "FontSize", 12, "Parent", warnDlg, ...
            "BackgroundColor", [.66 .76 1]);
        uicontrol("Style", "listbox", "Units", "normalized", ...
            "Position", [.2 .32 .6 .41], "String", listItems, "Min", 0, "Max", 2, ...
            "Value", [], "Enable", "inactive", "FontSize", 12, "Parent", warnDlg);
        uicontrol("Style", "pushbutton", "String", "Yes", ...
            "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
            "Position", [0.25 0.18 0.2 0.1], "FontSize", 12, "Parent", warnDlg);
        uicontrol("Style", "pushbutton", "String", "No", ...
            "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
            "Position", [0.55 0.18 0.2 0.1], "FontSize", 12, "Parent", warnDlg);
        showMessageBox = uicontrol("Style", "checkbox", "String", "Do not show this message again", ...
            "Units", "normalized", "Position", [0.25 0.05 0.5 0.12], "FontSize", 12, "Value", 0, ...
            "Parent", warnDlg, "BackgroundColor", [.66 .76 1]);
    else
        uicontrol("Style", "text", "Units", "normalized", ...
            "Position", [0.05 0.4 0.9 0.5], "String", msg, "FontSize", 12, "Parent", warnDlg, ...
            "BackgroundColor", [.66 .76 1]);
        uicontrol("Style", "pushbutton", "String", "Yes", ...
            "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
            "Position", [0.25 0.2 0.2 0.12], "FontSize", 12, "Parent", warnDlg);
        uicontrol("Style", "pushbutton", "String", "No", ...
            "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
            "Position", [0.55 0.2 0.2 0.12], "FontSize", 12, "Parent", warnDlg);
        showMessageBox = uicontrol("Style", "checkbox", "String", "Do not show this message again", ...
            "Units", "normalized", "Position", [0.25 0.05 0.5 0.12], "FontSize", 12, "Value", 0, ...
            "Parent", warnDlg, "BackgroundColor", [.66 .76 1]);
    end

    if exist('beep') == 5
	    beep;
    end

    uiwait(warnDlg);

    yesPressed = warnDlg.UserData.yesPressed;
    noPressed = warnDlg.UserData.noPressed;
    boxChecked = showMessageBox.Value;

    delete(warnDlg);
    
    function btnPressed(src, ~, fig)
        if strcmp(src.String, 'Yes')
            fig.UserData.yesPressed = true;
        elseif strcmp(src.String, 'No')
            fig.UserData.noPressed = true;
        end
        uiresume(fig);
    end
end