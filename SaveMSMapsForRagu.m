function rd = SaveMSMapsForRagu(EEGs,nMaps,Grouping)

if nargin < 3
    Grouping = [];
end

for i = 1:numel(EEGs)
    
    SpatialResampler = MakeResampleMatrices(EEGs(i).chanlocs,EEGs(1).chanlocs);
    rd.V(i,:,:,1) = double(EEGs(i).msinfo.MSMaps(nMaps).Maps * SpatialResampler');
    for n = 1:nMaps
        rd.Names{i,n} = sprintf('%s (%i)',EEGs(i).setname,n);
    end
end

for n = 1:nMaps
    rd.conds{n,1} = sprintf('Class_%i',n);
    rd.DLabels1(1,n).Level = n;
    rd.DLabels1(1,n).Label= sprintf('Class_%i',n);
end
if isempty(Grouping) % We go for the EEG lab groups
    IndividualGroupLabels = cellfun(@(x) EEGs(x).group,num2cell(1:numel(EEGs)), 'UniformOutput',false);
    
    for i = 1:numel(IndividualGroupLabels)
        if isnumeric(IndividualGroupLabels{i})
            IndividualGroupLabels(i) = {num2str(IndividualGroupLabels{i})};
        end
    end
            
    [rd.GroupLabels,~,rd.IndFeature] = unique(IndividualGroupLabels);
    rd.GroupLabels = rd.GroupLabels(:);
else
    rd.GroupLabels = cellfun(@(x) sprintf('Group %i',x),num2cell(unique(Grouping)), 'UniformOutput',false);
    rd.IndFeature = Grouping;
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


