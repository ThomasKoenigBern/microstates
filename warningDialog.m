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

function [yesPressed, boxChecked] = warningDialog(msg, title)

    yesPressed = false;
    boxChecked = false;

    warnDlg = uifigure('Name', title);
    warnDlg.Position(3:4) = [420 200];
    warnDlg.UserData.yesPressed = yesPressed;
    warnDlg.CloseRequestFcn = 'uiresume()';
    grid1 = uigridlayout(warnDlg, [3 1]);
    grid1.BackgroundColor = [.66 .76 1];        % match EEGLAB background color
    grid1.Padding = [30 10 30 10];
    
    warningLabel = uilabel(grid1, 'Text', msg, 'WordWrap', 'on');
    warningLabel.FontSize = 14;
    
    grid2 = uigridlayout(grid1, [1 2]);
    grid2.BackgroundColor = [.66 .76 1];        % match EEGLAB background color
    grid2.ColumnSpacing = 50;
    grid2.Padding = [50 10 50 10];
   
    uibutton(grid2, 'Text', 'Yes', 'ButtonPushedFcn', {@btnPressed, warnDlg});
    uibutton(grid2, 'Text', 'No','ButtonPushedFcn', {@btnPressed, warnDlg});
    showMessageBox = uicheckbox(grid1, 'Text', 'Do not show this message again');
    showMessageBox.FontSize = 14;

    if exist('beep') == 5
	    beep;
    end

    uiwait();

    yesPressed = warnDlg.UserData.yesPressed;
    boxChecked = showMessageBox.Value;

    delete(warnDlg);
    
    function btnPressed(src, event, fig)
        if strcmp(src.Text, 'Yes')
            fig.UserData.yesPressed = true;
        end
        uiresume();
    end
end