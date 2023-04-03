function rd = MSMapsAndDesign4Ragu(EEGs,nMaps)

    
    [rd.GroupLabels,rd.IndFeature] = GetUniqueIdentifiers(EEGs,'group');
    [rd.conds      ,ConditionIdx ] = GetUniqueIdentifiers(EEGs,'condition');    
    [SubjectLabel  ,SubjectIdx]    = GetUniqueIdentifiers(EEGs,'subject');    
    
    nSubjects   = numel(SubjectLabel);
    nConditions = numel(rd.conds);
    rd.Names    = cell(nSubjects,nConditions);

    for s = 1:nSubjects
        for c = 1:nConditions
            idx = find(SubjectIdx == s && ConditionIdx == c);
            if isempty(idx)
                warning('Condition %s for subject %s is missing, this subject will be excluded',rd.conds{c},SubjectLabel{s});
            elseif numel(idx) > 1
                warning('Condition %s for subject %s was found more than once, this subject will be excluded',rd.conds{c},SubjectLabel{s});
            else
                rd.Names(s,c) = EEGs(idx).setname;
                SpatialResampler = MakeResampleMatrices(EEGs(idx).chanlocs,EEGs(1).chanlocs);
                rd.V(s,:,c,:) = double(EEGs(idx).msinfo.MSMaps(nMaps).Maps * SpatialResampler');
            end
        end
    end

    GapsInTheDataMatrix = cellfun(@(x) isempty(x),rd.Names);
    SubjectsToExclude   = any(GapsInTheDataMatrix,2);
    
    rd.Names(SubjectsToExclude,:) = [];
    rd.V(SubjectsToExclude,:,:,:) = [];

    for n = 1:nMaps
        rd.DLabels1(1,n).Level = n;
        if IsFieldWithInformation(EEGs(1).msinfo.MSMaps(nMaps),'Labels')
            rd.conds{n,1} = EEGs(1).msinfo.MSMaps(nMaps).Labels{n};
            rd.DLabels1(1,n).Label  = EEGs(1).msinfo.MSMaps(nMaps).Labels{n};
        else
            rd.conds{n,1} = sprintf('Class_%i',n);
            rd.DLabels1(1,n).Label= sprintf('Class_%i',n);
        end
    end

    rd.Design = [(1:nMaps)' ones(nMaps,1)];
    rd.strF1  = 'Class';
    rd.TwoFactors = 0;
    rd.DeltaX = 1;
    rd.txtX = 'MS';
    rd.TimeOnset = 1;
    rd.StartFrame = 1;
    rd.EndFrame = 1;
    rd.axislabel = 'Class';
    rd.FreqDomain = 0;
    rd.MeanInterval = true;



    X = cell2mat({EEGs(1).chanlocs.X});
    Y = cell2mat({EEGs(1).chanlocs.Y});
    Z = cell2mat({EEGs(1).chanlocs.Z});

    [Theta,Phi,Radius] = VAcart2sph(-Y,X,Z);

    for i = 1:numel(X)
        rd.Channel(i).Name   = EEGs(1).chanlocs(i).labels;
        rd.Channel(i).Radius = 1;
        rd.Channel(i).Theta  = Theta(i);
        rd.Channel(i).Phi    = Phi(i);
    end
end


function [lbl,Assignment] = GetUniqueIdentifiers(EEGs, Identifier)
    lbl = cellfun(@(x) EEGs(x).(Identifier),num2cell(1:numel(EEGs)), 'UniformOutput',false);
    
    for i = 1:numel(lbl)
        if isnumeric(lbl{i})
            lbl(i) = {num2str(lbl{i})};
        end
    end
            
    [lbl,~,Assignment] = unique(lbl);
    lbl = lbl(:);
end
