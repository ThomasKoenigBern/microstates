function [ResidualEstimator,ResTime,ResMap] = VA_MakeSplineResidualMatrix(VAChannels, EEG)

if isfield(VAChannels,'Theta') || isfield(VAChannels,'CoordsTheta')
    [x,y,z] = VAsph2cart(VAChannels);
            
elseif isfield(VAChannels,'X')
    y =  cell2mat({VAChannels.X});
    x = -cell2mat({VAChannels.Y});
    z =  cell2mat({VAChannels.Z});
elseif isfield(VAChannels,'x')
    x = -cell2mat({VAChannels.x});
    y =  cell2mat({VAChannels.y});
    z =  cell2mat({VAChannels.z});
else
    error('Unknown montage format');
end


elec = [x; y; z]';

nc = size(elec,1);

ResidualEstimator = -eye(nc);
FlatMap = eye(nc-1);

for Target = 1:nc
    ChannelBase = 1:nc;
    ChannelBase(Target) = [];

    IntMat = splint2(elec(ChannelBase,:),FlatMap,elec(Target,:));
    ResidualEstimator(Target,ChannelBase) = IntMat;
end

if nargin > 1
    [~,nChannels] = size(EEG);
    if nChannels ~= nc
        error('Channel number mismatch');
    end
    EEGVar = EEG.^2;

    Residual = (EEG * ResidualEstimator).^2;
    ResTime = mean(Residual,2)./mean(EEGVar,2); 
    ResMap  = mean(Residual,1)./mean(EEGVar,1);
end

if nargout < 1
    figure();
    subplot(121);
    plot(ResTime);
    subplot(122);
    dspCMap2(ResMap',VAChannels,'Step',0.1,'ShowPosition',{VAChannels.Name});
end

