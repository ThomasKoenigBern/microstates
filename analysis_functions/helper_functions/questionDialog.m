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
%   they closed the dialog box
%

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
% 
%     selectDlg = uifigure('Name', title);
%     selectDlg.Position(3:4) = [750 150];
%     selectDlg.UserData.selection = selection;
%     selectDlg.CloseRequestFcn = 'uiresume()';
%     grid1 = uigridlayout(selectDlg, [2 1]);
%     grid1.BackgroundColor = [.66 .76 1];        % match EEGLAB background color
%     grid1.Padding = [30 10 30 10];
%     
%     questLabel = uilabel(grid1, 'Text', question, 'WordWrap', 'on');
%     questLabel.FontSize = 14;
%     
%     grid2 = uigridlayout(grid1, [1 3]);
%     grid2.BackgroundColor = [.66 .76 1];        % match EEGLAB background color
%     
%     uibutton(grid2, 'Text', options{1}, 'ButtonPushedFcn', {@btnPressed, selectDlg});
%     uibutton(grid2, 'Text', options{2}, 'ButtonPushedFcn', {@btnPressed, selectDlg});
%     uibutton(grid2, 'Text', 'Cancel', 'ButtonPushedFcn', {@btnPressed, selectDlg});

    uiwait(selectDlg);

    selection = selectDlg.UserData.selection;

    delete(selectDlg);
    
    function btnPressed(src, event, fig)
        fig.UserData.selection = src.String;
        uiresume(fig);
    end
end