function [MeanMap,SortedMaps,OldMapFit] = PermutedMeanMaps(in,RespectPolarity, Montage, Reruns, UseEMD)

    AutoReruns = false;

    if nargin < 5
        UseEMD = false;
    end
    
    if nargin < 4
        Reruns = [];
    end
    
    if isempty(Reruns)
        Reruns = 20;
        AutoReruns = true;
    end
    
    OrgReruns = Reruns;
    
    debug = false;
    
    [nSubjects,nMaps,nChannels] = size(in);

    progStrArray = '/-\|';
    fprintf(1,'Permuting %i maps of %i subjects ',nMaps,nSubjects);

    GoBack = 1;
    BestMeanMapFit = -inf;
    BestIndex = nan;
    in = NormDim(in,3);
    if nargin < 2;  RespectPolarity = false;    end
    Run = 0;
    while Run < Reruns
        Run = Run + 1;
        MeanMap = zeros(1,nMaps,nChannels);
        for k = 1:nMaps
            dm1= randperm(nSubjects);
            dm2 = randperm(nMaps);
            MeanMap(1,k,:) = squeeze(in(dm1(1),dm2(1),:));
        end
        SortedMaps = in;
        OldSortedMaps = SortedMaps;
        OldMapFit = -inf;
        WorkToBeDone = true;
        cnt = 0;
        NewOrder = repmat(1:nMaps,nSubjects,1);
        SetOrder = nan(size(NewOrder));
        OldOrder = NewOrder;
        OldOldOrder = OldOrder;
            
        while WorkToBeDone
            MeanMap = NormDim(MeanMap,3);
            cnt = cnt + 1;
            fprintf(1,'\b%s',progStrArray(mod(cnt-1, 4)+1));
            % See how the prototype fits
            if UseEMD == false
                MapFit = GetMapSeriesOverallFit(SortedMaps,MeanMap,RespectPolarity);
            else
                MapFit = GetMapSeriesOverallFit(SortedMaps,MeanMap,RespectPolarity,Montage);
            end
            if debug == true
                figure(1000);
                spidx = 1;
                X = cell2mat({Montage.X});
                Y = cell2mat({Montage.Y});
                Z = cell2mat({Montage.Z});
                for s = 1:nSubjects
                    for c = 1:nMaps
                        subplot(nSubjects+1,nMaps,spidx);
                        dspQMap(squeeze(SortedMaps(s,c,:)),[X;Y;Z],'Resolution',5);
                        spidx = spidx+1;
                    end
                end
                for c = 1:nMaps
                    subplot(nSubjects+1,nMaps,spidx);
                    dspQMap(squeeze(MeanMap(1,c,:)),[X;Y;Z],'Resolution',5);
                    spidx = spidx+1;
                end
            end
        
            MeanMapFit = mean(MapFit);
            
            % Find the order of misfit
            [~,Idx] = sort(MapFit(:),'ascend');
            WorkToBeDone = false;
            UseOptimToolbox = true;
            if isempty(which('intlinprog')) || license('test','optimization_toolbox') == false
                UseOptimToolbox = false;
            end
                
            for i = 1:numel(Idx)
                if (nMaps < 7) || UseOptimToolbox == false % Full permutations for small n or absent optimzation toolbox
                    if UseEMD == false
                        [SwappedMaps,Order] = SwapMaps(SortedMaps(Idx(i),:,:),MeanMap,RespectPolarity);
                    else
                        [SwappedMaps,Order] = SwapMaps(SortedMaps(Idx(i),:,:),MeanMap,RespectPolarity,Montage);
                    end
                else        % linear prgramming for larger problems
                    if UseEMD == false
                        [SwappedMaps,Order] = SwapMaps2(SortedMaps(Idx(i),:,:),MeanMap,RespectPolarity);
                    else
                        [SwappedMaps,Order] = SwapMaps2(SortedMaps(Idx(i),:,:),MeanMap,RespectPolarity);
                    end
                end
                SetOrder(Idx(i),:) = Order;
            
                if ~isempty(SwappedMaps)
                    if debug == true
                        Idx(i)
                    end
                    NewOrder(Idx(i),:) = Order;
                
                    WorkToBeDone = true;
                    SortedMaps(Idx(i),:,:) = SwappedMaps;
                
                    for k = 1:nMaps
                         data = squeeze(SortedMaps(:,k,:));
                         [pc1,~] = eigs(data'*data,1);
                         MeanMap(1,k,:) = NormDimL2(pc1',2);
                    end
%                    break;
                else
                    if debug == true
                        fprintf(1,'No change in case %i\n',Idx(i));
                    end
                end
            end
       
            % Catch the rate cases where the linintprog swaps back and forth
            if all(OldOldOrder(:) == NewOrder(:))
%                disp('flip back found');
                SortedMaps = OldSortedMaps;
                for k = 1:nMaps
                     data = squeeze(SortedMaps(:,k,:));
                     [pc1,~] = eigs(data'*data,1);
                     MeanMap(1,k,:) = NormDimL2(pc1',2);
                end
                break;
            end
    
            OldOldOrder = OldOrder;
            OldOrder = NewOrder;
        
            OldSortedMaps = SortedMaps;
            OldMapFit     = MeanMapFit;
        end
    
        if debug == true
            disp('Done');
            pause
        end
        for s = 1:size(SortedMaps,1)
            SubMaps = squeeze(SortedMaps(s,:,:));
            for k = 1:size(SortedMaps,2)
                if  SubMaps(k,:) *  squeeze(MeanMap(1,k,:)) < 0
                    SortedMaps(s,k,:) = -SortedMaps(s,k,:);
                end
            end
        end
        MeanMap = squeeze(MeanMap); 
        covm = MeanMap'*MeanMap;
        [v,d] = eigs(covm,1);
        sgn = sign(MeanMap * v);
        MeanMap = MeanMap .* repmat(sgn,1,size(MeanMap,2));
               
        if mean(MapFit(:)) > BestMeanMapFit
            BestMeanMapFit = mean(MapFit(:));
            BestMeanMap = MeanMap;
            BestSortedMaps = SortedMaps;
            BestOldMapFit = OldMapFit;
            BestIndex = Run;
            if AutoReruns == true
                Reruns = max(Run + 20,OrgReruns);
            end
        end
        
        for i = 1:GoBack
            fprintf(1,'\b');
        end
        GoBack = fprintf(1,' run %2i/%2i: %5.5f (%2i) ',Run,Reruns,BestMeanMapFit,BestIndex);

    end
    MeanMap = BestMeanMap;
    SortedMaps = BestSortedMaps;
    OldMapFit = BestOldMapFit;
    
    fprintf(1,'\n');
    if debug == true
        figure(3000);
        subplot(211);
        imagesc(NewOrder',[1,nMaps]);
        subplot(212);
        imagesc(SetOrder',[1,nMaps]);
        drawnow;
    end
end


