% eegplugin_microstatelab() - EEGLAB plugin for microstate analyses
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
%   <a href="matlab:helpwin pop_CheckData">pop_CheckData</a> (data quality evaluation)
%   <a href="matlab:helpwin pop_FindMSMaps">pop_FindMSMaps</a> (identify microstate maps)
%   <a href="matlab:helpwin pop_CombMSMaps">pop_CombMSMaps</a> (average microstate maps)
%   <a href="matlab:helpwin pop_SortMSMaps">pop_SortMSMaps</a> (sorts microstate maps)
%   <a href="matlab:helpwin pop_DetectOutliers">pop_DetectOutliers</a> (detect outlier maps)
%   <a href="matlab:helpwin pop_FitMSMaps">pop_FitMSMaps</a> (backfit maps to EEG)
%   <a href="matlab:helpwin pop_SaveMSParameters">pop_SaveMSParameters</a> (export temporal parameters)
%   <a href="matlab:helpwin pop_GetMSDynamics">pop_GetMSDynamics</a> (obtain microstate activation series)
%   <a href="matlab:helpwin pop_RaguMSMaps">pop_RaguMSMaps</a>  (test for topographic differences)
%
%   Visualisations:
%   <a href="matlab:helpwin pop_ShowIndMSMaps">pop_ShowIndMSMaps</a> (view microstate maps)
%   <a href="matlab:helpwin pop_ShowIndMSDyn">pop_ShowIndMSDyn</a> (view temporal dynamics)
%   <a href="matlab:helpwin pop_ShowMSParameters">pop_ShowMSParameters</a> (view temporal parameters)
%   <a href="matlab:helpwin pop_CompareMSMaps">pop_CompareMSMaps</a> (visually compare topographies)
%
% See "MicrostateAnalysisDemo.m" for a starter script for performing
% microstate analysis using the command line functions.
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
function [vers,nogui] = eegplugin_microstatelab (fig, try_strings, catch_strings)

    VersionNumber = '2.0';
    vers = ['MICROSTATELAB ' VersionNumber];

    nogui = isempty(findobj('Tag','EEGLAB'));

    if ismember('MSTEMPLATE',who('global')) % The function has been called before, we don't need to go into all the setup again
        if nargin < 1 % and no need to setup the GUI, so we're already done
            return
        end
    else  % We need to do the GUI independent setup
        global MSTEMPLATE;
    
        addpath(genpath(fileparts(which('eegplugin_microstatelab'))));
        if ~isempty(which('eegplugin_Microstates'))
            warning('Old version of the MICROSTATELAB toolbox found in the EEGLAB plugins folder. Please remove any old versions to avoid conflicts.');
        end
            
        pluginpath = fileparts(which('eegplugin_microstatelab.m'));                  % Get eeglab path
        templatepath = fullfile(pluginpath,'Templates');

        Templates = dir(fullfile(templatepath,'*.set'));
        MSTemplate = [];   
        for t = 1: numel(Templates)
            MSTemplate = eeg_store(MSTemplate,pop_loadset('filename',Templates(t).name,'filepath',templatepath));
        end
    
        MSTEMPLATE = MSTemplate;
    end
    
    if nargin > 0 % We setup the GUI if required
        if ~ispref('MICROSTATELAB', 'showSortWarning')
            setpref('MICROSTATELAB', 'showSortWarning', 1);
        end
        if ~ispref('MICROSTATELAB', 'showFitWarning')
            setpref('MICROSTATELAB', 'showFitWarning', 1);
        end
        if ~ispref('MICROSTATELAB', 'showTopoWarning1')
            setpref('MICROSTATELAB', 'showTopoWarning1', 1);
        end
        if ~ispref('MICROSTATELAB', 'showTopoWarning2')
            setpref('MICROSTATELAB', 'showTopoWarning2', 1);
        end

        % Tools menu
        comCheckData           = [try_strings.no_check '[~, LASTCOM]                          = pop_CheckData(ALLEEG);'             catch_strings.add_to_hist];
        comFindMSTemplates     = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_FindMSMaps(ALLEEG);'            catch_strings.store_and_hist];
        comCombineMSTemplates  = [try_strings.no_check '[EEG, LASTCOM]                        = pop_CombMSMaps(ALLEEG);'            catch_strings.new_and_hist];
        comSortMSTemplates     = [try_strings.no_check '[ALLEEG, EEG, CURRENTSET, LASTCOM]    = pop_SortMSMaps(ALLEEG);'            catch_strings.store_and_hist];
        comDetectOutliers      = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_DetectOutliers(ALLEEG);'        catch_strings.store_and_hist];
        comCompareTopos        = [try_strings.no_check '[EEG, CURRENTSET, ~, LASTCOM]         = pop_CompareTopos(ALLEEG);'          catch_strings.store_and_hist];
        comCompareMaps         = [try_strings.no_check '[~, LASTCOM]                          = pop_CompareMSMaps(ALLEEG);'         catch_strings.store_and_hist];
        comGetMSDynamics       = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_GetMSDynamics(ALLEEG);'         catch_strings.new_and_hist];
        comFitMSTemplates      = [try_strings.no_check '[EEG, CURRENTSET, LASTCOM]            = pop_FitMSMaps(ALLEEG);'             catch_strings.store_and_hist];
        comSaveMSParam         = [try_strings.no_check '[~, LASTCOM]                          = pop_SaveMSParameters(ALLEEG);'      catch_strings.add_to_hist];
        comRaguMSTemplates     = [try_strings.no_check 'LASTCOM                               = pop_RaguMSMaps(ALLEEG);'            catch_strings.add_to_hist];

        % Plot menu
        comShowIndMSMaps       = [try_strings.no_check '[~, LASTCOM]                          = pop_ShowIndMSMaps(ALLEEG);'         catch_strings.add_to_hist];
        comShowIndMSDyn        = [try_strings.no_check 'LASTCOM                               = pop_ShowIndMSDyn(ALLEEG);'          catch_strings.store_and_hist];
        comShowMSParam         = [try_strings.no_check '[~, LASTCOM]                          = pop_ShowMSParameters(ALLEEG);'      catch_strings.add_to_hist];    
        
        toolsmenu = findobj(fig, 'tag', 'tools');
        toolssubmenu = uimenu( toolsmenu, 'label', 'MICROSTATELAB','userdata','study:on','Separator','on');
        uimenu( toolssubmenu, 'Label', 'Data quality check',                                              'CallBack', comCheckData,          'userdata', 'study:on');
        uimenu( toolssubmenu, 'Label', 'Identify microstate maps per dataset',                            'CallBack', comFindMSTemplates,    'userdata', 'study:on');
        uimenu( toolssubmenu, 'Label', 'Identify mean microstate maps',                                   'CallBack', comCombineMSTemplates, 'userdata', 'study:on');
        uimenu( toolssubmenu, 'Label', 'Edit & sort microstate maps',                                     'CallBack', comSortMSTemplates,    'userdata', 'study:on');
        uimenu( toolssubmenu, 'Label', 'Outlier detection',                                               'Callback', comDetectOutliers,     'userdata', 'study:on');
        uimenu( toolssubmenu, 'Label', 'Compare topographic similarities',                                'Callback', comCompareTopos,       'userdata', 'study:on');
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
end
