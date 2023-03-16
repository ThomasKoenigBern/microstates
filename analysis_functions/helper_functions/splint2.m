function V2 = splint2(elc1, V1, elc2)

    N = size(elc1,1);   % number of known electrodes
    M = size(elc2,1);   % number of unknown electrodes
    T = size(V1,2);     % number of timepoints in the potential
    Z = V1;         % potential on known electrodes, can be matrix

    % scale all electrodes towards a unit sphere
    elc1 = elc1 ./ repmat(sqrt(sum(elc1.^2,2)), 1, 3);
    elc2 = elc2 ./ repmat(sqrt(sum(elc2.^2,2)), 1, 3);

    G = computeg(elc1(:,1)',elc1(:,2)',elc1(:,3)',elc1(:,1)',elc1(:,2)',elc1(:,3)');

    H = ones(N+1,N+1); H(1,1) = 0; H(2:end,2:end) = G;

    C = H \ [zeros(1,T); Z];               % solve by Gaussian elimination

    gx = computeg(elc2(:,1)',elc2(:,2)',elc2(:,3)',elc1(:,1)',elc1(:,2)',elc1(:,3)');

    V2 = [ones(M,1) gx] * C;

end


function g = computeg(x,y,z,xelec,yelec,zelec)

    unitmat = ones(length(x(:)),length(xelec));
    EI = unitmat - sqrt((repmat(x(:),1,length(xelec)) - repmat(xelec,length(x(:)),1)).^2 +... 
                    (repmat(y(:),1,length(xelec)) - repmat(yelec,length(x(:)),1)).^2 +...
                    (repmat(z(:),1,length(xelec)) - repmat(zelec,length(x(:)),1)).^2);

    g = zeros(length(x(:)),length(xelec));

    m = 4; % 3 is linear, 4 is best according to Perrin's curve
    for n = 1:7
        L = legendre(n,EI);
        g = g + ((2*n+1)/(n^m*(n+1)^m))*squeeze(L(1,:,:));
    end
    g = g/(4*pi);    
end

