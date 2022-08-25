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
%   <a href="matlab:helpwin pop_FindMSTemplates">pop_FindMSTemplates</a>  (identify microstate cluster maps)
%   <a href="matlab:helpwin pop_CombMSTemplates">pop_CombMSTemplates</a>  (average microstate cluster maps)
%   <a href="matlab:helpwin pop_SortMSTemplates">pop_SortMSTemplates</a>  (sorts microstate cluster maps based on a mean)
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

    VersionNumber = '1.3';
    vers = ['Microstates' VersionNumber];
    
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
       
    for t = 1: numel(Templates)
        MSTemplate(t) = pop_loadset('filename',Templates(t).name,'filepath',templatepath);
    end
    
    MSTEMPLATE = MSTemplate;
    
    comFindMSTemplates     = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_FindMSTemplates(ALLEEG, EEG, CURRENTSET);'           catch_strings.store_and_hist]; % ok
    comCombineMSTemplates  = [try_strings.no_check '[       EEG LASTCOM] = pop_CombMSTemplates(ALLEEG,CURRENTSET,false);'           catch_strings.new_and_hist];
    comCombineMSMeans      = [try_strings.no_check '[       EEG LASTCOM] = pop_CombMSTemplates(ALLEEG,CURRENTSET,true );'           catch_strings.new_and_hist];
    comSortMSTemplates     = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_SortMSTemplates(ALLEEG,[],false);'                   catch_strings.store_and_hist];
    comSortMSMeans         = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_SortMSTemplates(ALLEEG,[],true) ;'                   catch_strings.store_and_hist];
    comSortMSTemplatesT    = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_SortMSTemplates(ALLEEG,[],false,-1);'                catch_strings.store_and_hist];
    comSortMSMeansT        = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_SortMSTemplates(ALLEEG,[],true, -1) ;'               catch_strings.store_and_hist];
    
    comGetIndMSDynamics    = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_GetMSDynamics(ALLEEG,EEG,false);'                    catch_strings.new_and_hist];
    comGetMeanMSDynamics   = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_GetMSDynamics(ALLEEG,EEG,true);'                     catch_strings.new_and_hist];
    comGetTMplMSDynamics   = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_GetMSDynamics(ALLEEG,EEG,true,[],-1);'               catch_strings.new_and_hist];
    comQuantMSTemplatesS   = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_QuantMSTemplates(ALLEEG,CURRENTSET,0);'              catch_strings.store_and_hist];
    comQuantMSTemplatesM   = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_QuantMSTemplates(ALLEEG,CURRENTSET,1);'              catch_strings.store_and_hist];
    comQuantMSTemplatesT   = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_QuantMSTemplates(ALLEEG,CURRENTSET,2);'              catch_strings.store_and_hist];
    comQuantMSDataVis      = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_QuantMSTemplates(ALLEEG,CURRENTSET,0, [], [], 1);'   catch_strings.store_and_hist];
    
    comCompareMeanMaps     = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_CompareMeanMaps(ALLEEG);'                            catch_strings.store_and_hist];

    comRaguMSTemplates     = [try_strings.no_check '[           LASTCOM] = pop_RaguMSTemplates(ALLEEG,CURRENTSET       );'          catch_strings.add_to_hist];
    %    comBootStrapMSNumber   = [try_strings.no_check '[           LASTCOM] = pop_BootstrapMSNumber(ALLEEG,CURRENTSET);'       catch_strings.add_to_hist];
    comSilhouetteMSNumber  = [try_strings.no_check '[           LASTCOM] = pop_MS_Silhouette(ALLEEG,CURRENTSET);'                   catch_strings.add_to_hist];
    
    comShowIndMSMaps       = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_ShowIndMSMaps(EEG,[],true ,ALLEEG);'                 catch_strings.add_to_hist];
%     comEditIndMSMaps       = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_ShowIndMSMaps(EEG,[],true  ,ALLEEG);'        catch_strings.store_and_hist];

    comShowIndMSDyn        = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_ShowIndMSDyn(ALLEEG,EEG,false);'                     catch_strings.store_and_hist];
    comShowIndMSDynM       = [try_strings.no_check '[ALLEEG EEG LASTCOM] = pop_ShowIndMSDyn(ALLEEG,EEG,true);'                      catch_strings.store_and_hist];
        
    comClustNumSelectionS = [try_strings.no_check '[        LASTCOM] = pop_ClustNumSelection(ALLEEG,EEG,CURRENTSET,0);'             catch_strings.add_to_hist];    
    comClustNumSelectionM = [try_strings.no_check '[        LASTCOM] = pop_ClustNumSelection(ALLEEG,EEG,CURRENTSET,1);'             catch_strings.add_to_hist];    



    toolsmenu = findobj(fig, 'tag', 'tools');
    toolssubmenu = uimenu( toolsmenu, 'label', 'Microstates 1.3 Beta','userdata','study:on','Separator','on');

    plotmenu = findobj(fig, 'tag', 'plot');
    uimenu( plotmenu, 'label', 'Plot microstate maps'                       ,'CallBack',comShowIndMSMaps,'Separator','on');
%     uimenu( plotmenu, 'label', 'Edit microstate maps'                     ,'CallBack',comEditIndMSMaps,'Separator','off');
    uimenu( plotmenu, 'label', 'Plot microstate dynamics (Own template)'    ,'CallBack',comShowIndMSDyn,'Separator','on');
    uimenu( plotmenu, 'label', 'Plot microstate dynamics (Mean template)'   ,'CallBack',comShowIndMSDynM);

    % create menus if necessary
    % -------------------------
    uimenu( toolssubmenu, 'Label', 'Identify  microstate  maps'                           , 'CallBack', comFindMSTemplates,    'position', 1);

    uimenu( toolssubmenu, 'Label', 'Compute mean microstate maps across individuals'       , 'CallBack', comCombineMSTemplates, 'position', 2, 'userdata', 'study:on','Separator','on');
    uimenu( toolssubmenu, 'Label', 'Compute grand mean microstate maps across means'       , 'CallBack', comCombineMSMeans    , 'position', 3, 'userdata', 'study:on');

    uimenu( toolssubmenu, 'Label', 'Sort individual microstate maps according to mean'     , 'CallBack', comSortMSTemplates, 'position', 5, 'userdata', 'study:on','Separator','on');
    uimenu(toolssubmenu, 'label',  'Sort individual microstate maps according to published template' , 'CallBack', comSortMSTemplatesT,'position', 6, 'userdata', 'study:on');

    uimenu( toolssubmenu, 'Label', 'Sort mean microstate maps according to a grand mean'    , 'CallBack', comSortMSMeans    , 'position', 7, 'userdata', 'study:on','Separator','on');    
    uimenu(toolssubmenu, 'label',  'Sort mean microstate maps according to published template'       , 'CallBack', comSortMSMeansT,    'position',8, 'userdata', 'study:on');

    uimenu( toolssubmenu, 'Label', 'Obtain microstate dynamics (own template maps)'  , 'CallBack'       , comGetIndMSDynamics    ,   'position',  9, 'Separator','on');
    uimenu( toolssubmenu, 'Label', 'Obtain microstate dynamics (mean template maps)' , 'CallBack'       , comGetMeanMSDynamics   ,   'position',  10);
    uimenu( toolssubmenu, 'Label', 'Obtain microstate dynamics (published template maps)' , 'CallBack'  , comGetTMplMSDynamics   ,   'position',  11);
    
    uimenu( toolssubmenu, 'Label', 'Quantify microstates in dataset (own template maps)'  , 'CallBack', comQuantMSTemplatesS,   'position', 12, 'Separator','on');
    uimenu( toolssubmenu, 'Label', 'Quantify microstates in dataset (mean template maps)' , 'CallBack', comQuantMSTemplatesM,   'position', 13);
    uimenu( toolssubmenu, 'Label', 'Quantify microstates in dataset (published template maps)', 'CallBack', comQuantMSTemplatesT,   'position', 14);

    uimenu( toolssubmenu, 'Label', 'Compare spatial correlations between mean maps', 'Callback', comCompareMeanMaps, 'position', 15, 'Separator', 'on');

    uimenu( toolssubmenu, 'Label', 'Display microstate data visualizations (own template maps)'  , 'CallBack', comQuantMSDataVis,   'position', 16, 'Separator','on');

    uimenu( toolssubmenu, 'Label', 'Data driven selection of number of microstates (own template maps)', 'CallBack', comClustNumSelectionS, 'position', 17, 'Separator', 'on');
    uimenu( toolssubmenu, 'Label', 'Data driven selection of number of microstates (mean template maps)', 'CallBack', comClustNumSelectionM, 'position', 18);

    if numel(which('Ragu')) > 0
        uimenu( toolssubmenu, 'Label', 'Test for topographic effects in microstate topographies (Ragu)' , 'CallBack', comRaguMSTemplates,   'position', 19,'Separator','on');
    end
end
end
>>>>>>> develop

