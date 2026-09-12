function xy = lambertUSA(lon, lat, centralMeridian, originLatitude)
% Unit-sphere Lambert conformal conic; standard parallels 33 and 45 degrees.
if nargin < 3, centralMeridian = -96; end
if nargin < 4, originLatitude = 39; end
p1 = 33*pi/180;
p2 = 45*pi/180;
t = @(p) tan(pi/4 + p/2);
n = log(cos(p1)/cos(p2)) / log(t(p2)/t(p1));
F = cos(p1)*t(p1)^n/n;
rho0 = F/t(originLatitude*pi/180)^n;
rho = F ./ t(lat(:)*pi/180).^n;
longitude = mod(lon(:)-centralMeridian+180, 360)-180;
theta = n*longitude*pi/180;
xy = [rho.*sin(theta), rho0-rho.*cos(theta)];
end
