% GUI helper function to display a question with 2 options as 2 different
% buttons, used in certain pop functions. Currently allows only 2 options.
%
% Inputs:
%   - question: question to be displayed
%   - title: title of the dialog box
%   - options: cell array of character vectors containing different answers
%   to the question, which will each be displayed in a button
%
% Outputs:
%   - selection: character vector of the option the user selected, empty if
%   the dialog box was closed
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

function selection = questionDialog(question, title, options)   
    selection = [];

    selectDlg = figure("Name", title, "MenuBar", "none", "ToolBar", "none", ...
        "NumberTitle", "off", "WindowStyle", "modal", "Color", [.66 .76 1]);
    selectDlg.Position(3:4) = [750 100];
    selectDlg.UserData.selection = selection;
    selectDlg.CloseRequestFcn = 'uiresume()';

    uicontrol("Style", "text", "String", question, "Units", "normalized", ...
        "FontSize", 12, "Position", [0.05 0.7 0.9 0.2], "Parent", selectDlg, ...
        "BackgroundColor", [.66 .76 1]);
    uicontrol("Style", "pushbutton", "String", options{1}, "Callback", {@btnPressed, selectDlg}, ...
        "Units", "normalized", "Position", [0.05 0.1 0.28 0.3], "Parent", selectDlg);
    uicontrol("Style", "pushbutton", "String", options{2}, "Callback", {@btnPressed, selectDlg}, ...
        "Units", "normalized", "Position", [0.36 0.1 0.28 0.3], "Parent", selectDlg);
    uicontrol("Style", "pushbutton", "String", "Cancel", "Callback", {@btnPressed, selectDlg}, ...
        "Units", "normalized", "Position", [0.67 0.1 0.28 0.3], "Parent", selectDlg);

    uiwait(selectDlg);

    selection = selectDlg.UserData.selection;

    delete(selectDlg);
    
    function btnPressed(src, event, fig)
        fig.UserData.selection = src.String;
        uiresume(fig);
    end
end