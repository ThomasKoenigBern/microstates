% GUI helper function to display a warning in response to certain input
% cases during argument validation in pop functions. Notifies the user of
% the potential error and allows them to stop or continue, with the option
% to avoid showing the message again.
%
% Inputs:
%   - msg: warning message to be displayed
%   - title: title of the dialog box
%
% Outputs:
%   - yesPressed: 1 if the user pressed yes, 0 if they pressed no or closed
%   the dialog box
%   - boxChecked: 1 if the user checked the box to avoid showing the
%   warning message again, 0 if they did not
%

function [yesPressed, noPressed, boxChecked] = warningDialog(msg, title)

    yesPressed = false;
    noPressed = false;
    boxChecked = false;

    warnDlg = figure("Name", title, "MenuBar", "none", "ToolBar", "none", ...
        "NumberTitle", "off", "WindowStyle", "modal", "Color", [.66 .76 1]);
    warnDlg.Position(3:4) = [500 300];
    warnDlg.UserData.yesPressed = yesPressed;
    warnDlg.UserData.noPressed = noPressed;
    warnDlg.CloseRequestFcn = 'uiresume()';

    warningLabel = uicontrol("Style", "text", "Units", "normalized", ...
        "Position", [0.05 0.4 0.9 0.5], "String", msg, "FontSize", 12, "Parent", warnDlg, ...
        "BackgroundColor", [.66 .76 1]);
    yesBtn = uicontrol("Style", "pushbutton", "String", "Yes", ...
        "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
        "Position", [0.25 0.2 0.2 0.12], "FontSize", 12, "Parent", warnDlg);
    noBtn = uicontrol("Style", "pushbutton", "String", "No", ...
        "Callback", {@btnPressed, warnDlg}, "Units", "normalized", ...
        "Position", [0.55 0.2 0.2 0.12], "FontSize", 12, "Parent", warnDlg);
    showMessageBox = uicontrol("Style", "checkbox", "String", "Do not show this message again", ...
        "Units", "normalized", "Position", [0.25 0.05 0.5 0.12], "FontSize", 12, "Value", 0, ...
        "Parent", warnDlg, "BackgroundColor", [.66 .76 1]);

    if exist('beep') == 5
	    beep;
    end

    uiwait(warnDlg);

    yesPressed = warnDlg.UserData.yesPressed;
    noPressed = warnDlg.UserData.noPressed;
    boxChecked = showMessageBox.Value;

    delete(warnDlg);
    
    function btnPressed(src, event, fig)
        if strcmp(src.String, 'Yes')
            fig.UserData.yesPressed = true;
        elseif strcmp(src.String, 'No')
            fig.UserData.noPressed = true;
        end
        uiresume(fig);
    end
end