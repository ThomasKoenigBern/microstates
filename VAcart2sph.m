function [Theta,Phi,Radius] = VAcart2sph(x,y,z)


    sgnX = ones(size(x));
    sgnX(x < 0) = -1;
    sgnY = ones(size(y));
    sgnY(y < 0) = -1;
    
    Radius = sqrt(x.*x + y.*y + z.*z);
    Theta = acos(z./Radius) / pi *180;
    Theta = abs(Theta) .* sgnX;
    
    l = sqrt(x.*x + y.*y);
    Phi = asin(y./l)/pi*180;

    
    Phi = abs(Phi) .* sgnX .* sgnY;
    
    
    NonCephalic = Radius == 0;
    Theta(NonCephalic)  = 0;
    Radius(NonCephalic) = 0;
    Phi(NonCephalic)    = 0;

end

