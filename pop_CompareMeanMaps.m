% pop_CompareMeanMaps() Find spatial correlations between mean maps by
% sorting the first selected maps according to the second selection.
%
% Usage: >> [AllEEG,com] = pop_CompareMeanMaps(AllEEG, SelectedSets, NClasses, IgnorePolarity, FileName)
%
%  Input:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "SelectedSets" 
%   -> Indices of the two mean sets to compare. If not exactly 2 sets are
%   chosen, the user will be notified with an error message.
%
%   "NClasses"
%   -> optional argument specifying the cluster solution to sort (used when
%   calling pop_SortMSTemplates from QuantifyMSDynamics to find spatial
%   correlations)
%
%   "IgnorePolarity"
%   -> Ignore the polarity of the maps to be sorted   
%
% Output:
%
%   "AllEEG" 
%   -> AllEEG structure with all the updated EEGs
%
%   "com"
%   -> Command necessary to replicate the computation
%
% added by Delara 8/23/22

function [AllEEG,EEGout,com] = pop_CompareMeanMaps(AllEEG, SelectedSets, NClasses, IgnorePolarity, FileName)
    
    com = '';

    if nargin < 2;   SelectedSets = [];          end
    if nargin < 3;   NClasses = [];              end
    if nargin < 4;   IgnorePolarity = true;      end
    if nargin < 5;   FileName = '';              end

    % identify valid datasets to compare (with children, containing msinfo)
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
    nonemptyMean = nonempty(HasChildren);

    % if selected sets are already passed in, confirm that they are valid
    % and there are exactly 2
    if ~isempty(SelectedSets)
        if sum(ismember(nonemptyMean, SelectedSets)) ~= 2
            errordlg2('Please select exactly 2 mean sets to compare.', ...
            'Compare mean maps');
            return;
        end

    % if the selected sets have not been passed in, prompt the user to
    % select them
    else
        AvailableMeans = {AllEEG(nonemptyMean).setname};
        
        res = inputgui('title','Compare mean maps',...
            'geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
                { 'Style', 'text', 'string', 'Choose 2 sets to compare'} ...
                { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
                }, 'title', 'Compare mean maps');

         if isempty(res); return; end

         SelectedSets = nonemptyMean(res{1});

         % check that the user has selected 2 sets
         if (numel(SelectedSets) ~= 2)
            errordlg2(['Please select exactly 2 mean sets to compare.'], ...
            'Compare mean maps');
            return;
         end         
    end
    
    % check if there is an overlap in class numbers between the 2 sets
    MinClasses = max(cellfun(@(x) GetClusterField(AllEEG(x),'MinClasses'),num2cell(SelectedSets)));
    MaxClasses = min(cellfun(@(x) GetClusterField(AllEEG(x),'MaxClasses'),num2cell(SelectedSets)));
    if (MinClasses > MaxClasses)
        errordlg2('The 2 selected mean sets do not contain a cluster solution with the same number of maps.' + ...
            ' Please select sets with compatible classes.', 'Compare mean maps');
    end
    
    % if NClasses has already been passed in, confirm these are valid as well
    if (~isempty(NClasses))
        if (NClasses < MinClasses) || (NClasses > MaxClasses)
            errordlg2(sprintf('One or both of the selected sets does not contain %d microstate maps.' + ...
                ' Please provide a class number in the range %d-%d.', NClasses, MinClasses, MaxClasses), ...
                'Compare mean maps');
        end
    % otherwise prompt the user to select a number of classes
    else
        classes = MinClasses:MaxClasses;
        classOptions = arrayfun(@(x) sprintf('%i Classes', x), classes, 'UniformOutput', false);
        res = inputgui('geometry', {[1 1] 1}, 'geomvert', [3 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Number of classes', 'fontweight', 'bold'} ...
            { 'Style', 'listbox', 'string', classOptions, 'Value', 1} ...
            { 'Style', 'checkbox', 'string', 'Ignore polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity } ...
            }, 'title', 'Compare mean maps');
        
        if isempty(res); return; end

        NClasses = classes(res{1});
        IgnorePolarity = res{2};
    end
    
    % sort the first mean set according to the second mean set if it has
    % not already been sorted
    if (~strcmp(AllEEG(SelectedSets(1)).msinfo.MSMaps(NClasses).SortedBy,AllEEG(SelectedSets(2)).setname))
        [AllEEG, ~, ~] = pop_SortMSTemplates(AllEEG, SelectedSets(1), 0, SelectedSets(2), "", IgnorePolarity, NClasses);
    end

    spCorr = AllEEG(SelectedSets(1)).msinfo.MSMaps(NClasses).Communality;
    
    if FileName == ""
        [FName,PName] = uiputfile({'*.csv','Comma separated file';'*.txt','Tab delimited file'; ...
            '*.mat','Matlab Table'; '*.xlsx','Excel file';'*.4R','Text file for R'}, ...
            'Save mean map comparison');
        FileName = fullfile(PName, FName);
    end

    if ~isempty(FileName)
        if contains(FileName, '.csv') || contains(FileName, '.txt') ...
                || contains(FileName, '.xlsx')
            writetable(table(spCorr), FileName);
        elseif contains(FileName, '.mat')
            save(FileName, 'spCorr');
        elseif contains(FileName, '.R')
            SaveStructToR(struct('SpCorr', spCorr));
        end
    end

    EEGout = AllEEG(SelectedSets(1));

    com = sprintf('[%s EEG com] = pop_CompareMeanMaps(%s, [%s], %i, %i, ''%s'');', inputname(1), inputname(1), sprintf('%d, %d', SelectedSets(1), SelectedSets(2)), ...
        NClasses, IgnorePolarity, FileName);
end

function Answer = DoesItHaveChildren(in)
    Answer = false;
    if ~isfield(in,'msinfo')
        return;
    end
    
    if ~isfield(in.msinfo,'children')
        return
    else
        Answer = true;
    end
end

function x = GetClusterField(in,fieldname)
    x = nan;
    if ~isfield(in,'msinfo')
        return
    end
    if ~isfield(in.msinfo,'ClustPar')
        return;
    end
    if isfield(in.msinfo.ClustPar,fieldname)
        x = in.msinfo.ClustPar.(fieldname);
    end
end