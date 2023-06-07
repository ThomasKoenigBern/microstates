% eegplugin_Microstates() - EEGLAB plugin for microstate analyses
%
% Usage:
%   >> eegplugin_Microstates(fig, trystrs, catchstrs);
%
% Inputs:
%   fig        - [integer]  EEGLAB figure
%   trystrs    - [struct] "try" strings for menu callbacks.
%   catchstrs  - [struct] "catch" strings for menu callbacks.
%
%   Integrates the following subfunctions:
%   --------------------------------------
%   Computational tools:
%   <a href="matlab:helpwin pop_FindMSMaps">pop_FindMSMaps</a>  (identify microstate cluster maps)
%   <a href="matlab:helpwin pop_CombMSMaps">pop_CombMSMaps</a>  (average microstate cluster maps)
%   <a href="matlab:helpwin pop_SortMSMaps">pop_SortMSMaps</a>  (sorts microstate cluster maps based on a mean)
%   <a href="matlab:helpwin pop_QuantMSTemplates">pop_QuantMSTemplates</a> (quantifies the presence of microstates in EEG data)
%
%   Visualisations:
%   <a href="matlab:helpwin pop_ShowIndMSMaps">pop_ShowIndMSMaps</a>   (view and edit microstate cluster maps)
%   <a href="matlab:helpwin pop_ShowIndMSDyn">pop_ShowIndMSDyn</a>     (view microstate dynamics)
%
% A typical basic workflow looks like this:
% - Identify  microstate maps in each EEG (Tools menu)
% - Average microstate maps across the datasets (Tools menu)
% - Edit the mean microstate maps for the desired sequence (Plot menu)
% - Either
%     - Sort the individual microstate maps based on the edited average
%       (Tools menu)
%     - Quantify the microstate presence based on the sorted individual
%       microstate maps (Tools menu)
% - Or   
%     - Quantify the microstate presence based on the averaged
%       microstate maps (Tools menu)
%
% For a more in depth explanation, see <a href="matlab:helpwin help_HowToDoMicrostateAnalyses">here</a>.
%
% In addition, the script TestMSAnalyses.m is supposed to give you a good
% start for a script that does the entire analyses for you. 
%
% Author: Thomas Koenig, University of Bern, Switzerland
%
% Copyright (C) 2018 Thomas Koenig, University of Bern, Switzerland
% thomas.koenig@upd.unibe.ch
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
function vers = eegplugin_Microstates (fig, try_strings, catch_strings)

    global MSTEMPLATE;
    global guiOpts;
    guiOpts.showCombWarning = true;
    guiOpts.showSortWarning = true;
    guiOpts.showGetWarning = true;
    guiOpts.showQuantWarning1 = true;
    guiOpts.showQuantWarning2 = true;
    guiOpts.showQuantWarning3 = true;
    guiOpts.showQuantWarning4 = true;
    guiOpts.showQuantWarning5 = true;
    guiOpts.showDynWarning = true;
    guiOpts.showCompWarning1 = true;
    guiOpts.showCompWarning2 = true;
    guiOpts.showCompWarning3 = true;
    guiOpts.showTopoWarning1 = true;

    addpath(genpath(fileparts(which('eegplugin_Microstates'))));

    VersionNumber = '1.2';
    vers = ['Microstates ' VersionNumber];
    
    if isempty(MSTEMPLATE)
        try
            WebVersionInfo = xml2struct('http://www.thomaskoenig.ch/Download/EEGLAB_Microstates/MSPluginVersionInfo.xml');
            WebVersion = WebVersionInfo.MSPluginVersionInfo.Attributes.Version;
        
            if str2double(WebVersion) > str2double(VersionNumber)
                InfoString{1} = ['Version: ' WebVersion];
            
                for i = 1:numel(WebVersionInfo.MSPluginVersionInfo.VersionInfo.VersionInfo)
                    name = fieldnames(WebVersionInfo.MSPluginVersionInfo.VersionInfo.VersionInfo{i}.Attributes);
                    InfoString{i + 1} = [name{1} ': ' WebVersionInfo.MSPluginVersionInfo.VersionInfo.VersionInfo{i}.Attributes.(name{1})];
                    if strcmp(name{1},'MSPluginZIP')
                        urlZIPName = WebVersionInfo.MSPluginVersionInfo.VersionInfo.VersionInfo{i}.Attributes.(name{1});
                    end
                end
            
                InfoString{i + 2} = '';
                InfoString{i + 3} = 'Update now?';
                InfoString{i + 4} = '(Requires an EEGLAB restart)';
            
                ButtonName = questdlg(InfoString,'New microstates plugin version available', 'Yes', 'No', 'Yes');
            
                switch ButtonName
                case 'Yes'
                    disp('Downloading');
                    pluginpath = fileparts(which('eegplugin_Microstates'));
                    tempZipName = tempname;
                    urlwrite(['http://www.thomaskoenig.ch/Download/EEGLAB_Microstates/' urlZIPName],[tempZipName '.zip']);
                    mkdir(tempZipName);
                    unzip([tempZipName '.zip'], tempZipName);
                    [~,NewDirName] = fileparts(urlZIPName);
                    NewPluginPath = fullfile(fileparts(which('eeglab')),'plugins',NewDirName);
                    mkdir(NewPluginPath);
                    AllFiles = dir(tempZipName);
                    for i = 3:numel(AllFiles)
                        movefile(fullfile(tempZipName,AllFiles(i).name), NewPluginPath, 'f');
                        disp(['Copied: ' AllFiles(i).name]);
                    end
                
                    OpenDir = fullfile(fileparts(which('eeglab')),'plugins');
                
                    if ispc
                        winopen(OpenDir);
                    elseif ismac
                        system(['open ' OpenDir ' &']);
                    else
                        error('Unrecognized operating system.');
                    end
    
                    uiwait(msgbox({'When EEGLAB has finished loading:' '- Close EEGLAB' '- type clear global' '- remove/relocate the old Microstates plugin folder from the EEGLAB plugin folder' '- and restart EEGLAB'},'Success'));
                case 'No'
                    disp('Working with outdated Microstates plugin.');
                end % switch
            end
        catch
            disp('EEG Microstates plugin update information unavailable');
        end
    end
    
    pluginpath = fileparts(which('eegplugin_Microstates.m'));                  % Get eeglab path
    templatepath = fullfile(pluginpath,'Templates');

    Templates = dir(fullfile(templatepath,'*.set'));
    MSTemplate = [];   
    for t = 1: numel(Templates)
        MSTemplate = eeg_store(MSTemplate,pop_loadset('filename',Templates(t).name,'filepath',templatepath));
    end
    
    MSTEMPLATE = MSTemplate;
    
    % Tools menu
    comCheckData           = [try_strings.no_check '[~, LASTCOM]                          = pop_CheckData(ALLEEG);'             catch_strings.add_to_hist];
    comFindMSTemplates     = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_FindMSMaps(ALLEEG);'            catch_strings.store_and_hist];
    comCombineMSTemplates  = [try_strings.no_check '[EEG, LASTCOM]                        = pop_CombMSMaps(ALLEEG);'            catch_strings.new_and_hist];
    comSortMSTemplates     = [try_strings.no_check '[ALLEEG, EEG, CURRENTSET, LASTCOM]    = pop_SortMSMaps(ALLEEG);'            catch_strings.store_and_hist];
    comDetectOutliers      = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_DetectOutliers(ALLEEG);'        catch_strings.store_and_hist];
%     comCompareTopos        = [try_strings.no_check '[EEG, CURRENTSET, ~, LASTCOM]         = pop_CompareTopos(ALLEEG);'          catch_strings.store_and_hist];
    comCompareMaps         = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_CompareMSMaps(ALLEEG);'         catch_strings.store_and_hist];
    comGetMSDynamics       = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_GetMSDynamics(ALLEEG);'         catch_strings.new_and_hist];
    comFitMSTemplates      = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_FitMSMaps(ALLEEG);'             catch_strings.store_and_hist];
    comSaveMSParam         = [try_strings.no_check '[~, LASTCOM]                          = pop_SaveMSParameters(ALLEEG);'      catch_strings.add_to_hist];
    comRaguMSTemplates     = [try_strings.no_check 'LASTCOM                               = pop_RaguMSMaps(ALLEEG);'            catch_strings.add_to_hist];

    % Plot menu
    comShowIndMSMaps       = [try_strings.no_check '[~, LASTCOM]                          = pop_ShowIndMSMaps(ALLEEG);'         catch_strings.add_to_hist];
    comShowIndMSDyn        = [try_strings.no_check 'LASTCOM                               = pop_ShowIndMSDyn(ALLEEG);'          catch_strings.store_and_hist];
    comShowMSParam         = [try_strings.no_check '[~, LASTCOM]                          = pop_ShowMSParameters(ALLEEG);'      catch_strings.add_to_hist];    
    
    toolsmenu = findobj(fig, 'tag', 'tools');
    toolssubmenu = uimenu( toolsmenu, 'label', 'Microstates','userdata','study:on','Separator','on');
    uimenu( toolssubmenu, 'Label', 'Data quality check',                                              'CallBack', comCheckData,          'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Identify microstate maps per dataset',                            'CallBack', comFindMSTemplates,    'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Identify mean microstate maps',                                   'CallBack', comCombineMSTemplates, 'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Edit & sort microstate maps',                                     'CallBack', comSortMSTemplates,    'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Outlier detection',                                               'Callback', comDetectOutliers,     'userdata', 'study:on');
%     uimenu( toolssubmenu, 'Label', 'Compare topographic similarities',                                'CallBack', comCompareTopos,       'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Backfit microstate maps to EEG',                                  'Callback', comFitMSTemplates,     'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Export temporal parameters',                                      'Callback', comSaveMSParam,        'userdata', 'study:on');
    uimenu( toolssubmenu, 'Label', 'Obtain microstate activation time series (optional)',             'CallBack', comGetMSDynamics,      'userdata', 'study:on', 'Separator', 'on');    
    uimenu( toolssubmenu, 'Label', 'Test for topographic effects in microstate topographies (Ragu)' , 'CallBack', comRaguMSTemplates,    'userdata', 'study:on', 'Separator', 'on');
    
    plotmenu = findobj(fig, 'tag', 'plot');
    uimenu( plotmenu,     'Label', 'Plot microstate maps',                                            'CallBack', comShowIndMSMaps,      'userdata', 'study:on', 'Separator','on');
    uimenu( plotmenu,     'Label', 'Plot temporal dynamics',                                          'CallBack', comShowIndMSDyn,       'userdata', 'study:on');    
    uimenu( plotmenu,     'Label', 'Plot temporal parameters',                                        'CallBack', comShowMSParam,        'userdata', 'study:on');
    uimenu( plotmenu,     'Label', 'Compare microstate maps',                                         'CallBack', comCompareMaps,        'userdata', 'study:on');  
end

